import 'dart:math';

import 'package:drift/drift.dart';

import '../../challenges/challenges.dart';
import '../../tutor/hint_ladder.dart';
import '../../../core/db/database.dart';
import '../../../core/llm/llm_provider.dart';
import 'tool.dart';

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

Map<String, Object?> taskJson(Task t) => {
      'id': t.id,
      'title': t.title,
      'topic': t.topic,
      'due': t.dueAt?.toIso8601String(),
      'done': t.doneAt != null,
    };

class CreateTaskTool extends AgentTool {
  @override
  final spec = ToolSpec(
      'create_task',
      'Add a task to the day plan.',
      objectSchema({
        'title': str,
        'topic': str,
        'due': {'type': 'string', 'description': 'ISO-8601 datetime'},
      }, required: ['title']));

  @override
  Future<Object?> run(Map<String, dynamic> a, ToolContext c) async {
    final id = await c.db.into(c.db.tasks).insert(TasksCompanion.insert(
        title: a['title'] as String,
        topic: Value(a['topic'] as String?),
        dueAt: Value(_date(a['due'])),
        createdAt: c.now()));
    return {'id': id};
  }
}

class UpdateTaskTool extends AgentTool {
  @override
  final spec = ToolSpec(
      'update_task',
      'Edit a task title or due time.',
      objectSchema({'id': integer, 'title': str, 'due': str},
          required: ['id']));

  @override
  Future<Object?> run(Map<String, dynamic> a, ToolContext c) async {
    final n = await (c.db.update(c.db.tasks)
          ..where((t) => t.id.equals((a['id'] as num).toInt())))
        .write(TasksCompanion(
      title: a['title'] == null ? const Value.absent() : Value(a['title'] as String),
      dueAt: a['due'] == null ? const Value.absent() : Value(_date(a['due'])),
    ));
    return {'updated': n};
  }
}

class CompleteTaskTool extends AgentTool {
  @override
  final spec = ToolSpec('complete_task', 'Mark a task done.',
      objectSchema({'id': integer}, required: ['id']));

  @override
  Future<Object?> run(Map<String, dynamic> a, ToolContext c) async {
    final n = await (c.db.update(c.db.tasks)
          ..where((t) => t.id.equals((a['id'] as num).toInt())))
        .write(TasksCompanion(doneAt: Value(c.now())));
    if (n > 0) await c.user.markStudied();
    return {'completed': n};
  }
}

class ListTasksTool extends AgentTool {
  @override
  final spec = ToolSpec('list_tasks', 'List open tasks (and recent done ones).',
      objectSchema({'include_done': {'type': 'boolean'}}));

  @override
  Future<Object?> run(Map<String, dynamic> a, ToolContext c) async {
    final q = c.db.select(c.db.tasks);
    if (a['include_done'] != true) q.where((t) => t.doneAt.isNull());
    q.orderBy([(t) => OrderingTerm.asc(t.id)]);
    return (await q.get()).map(taskJson).toList();
  }
}

class ScheduleCheckinTool extends AgentTool {
  @override
  final spec = ToolSpec(
      'schedule_checkin',
      'Schedule a future check-in notification.',
      objectSchema({'at': {'type': 'string', 'description': 'ISO-8601'}, 'reason': str},
          required: ['at', 'reason']));

  @override
  Future<Object?> run(Map<String, dynamic> a, ToolContext c) async {
    final at = _date(a['at']);
    if (at == null) return {'error': 'invalid time'};
    final id = await c.db.into(c.db.checkins).insert(CheckinsCompanion.insert(
        reason: a['reason'] as String, at: at));
    return {'id': id};
  }
}

/// Records a tutor quiz outcome and tells the model how to hint next time.
class TutorQuizTool extends AgentTool {
  @override
  final spec = ToolSpec(
      'tutor_quiz',
      'Record a quiz/tutoring result for a topic, or query the allowed hint level (omit "correct").',
      objectSchema({
        'topic': str,
        'correct': {'type': 'boolean'},
        'hint_level': {'type': 'integer', 'description': '0=question..3=answer'},
      }, required: ['topic']));

  @override
  Future<Object?> run(Map<String, dynamic> a, ToolContext c) async {
    final topic = a['topic'] as String;
    var m = await c.user.mastery(topic);
    if (a['correct'] is bool) {
      m = await c.user.recordQuiz(
          topic: topic,
          correct: a['correct'] as bool,
          hintLevel: ((a['hint_level'] as num?) ?? 0).toInt());
    }
    return {
      'topic': topic,
      'mastery': m,
      'start_level': HintLadder.start(m).name,
      'max_level': HintLadder.cap(m).name,
    };
  }
}

/// Returns text in chunks for the model to summarize. Accepts raw text or a
/// file path (PDF handled by the injected extractor).
class SummarizeTool extends AgentTool {
  SummarizeTool(this.extract);
  final Future<String> Function(String path) extract;

  @override
  final spec = ToolSpec(
      'summarize_text',
      'Fetch text (pasted or from a PDF/text file path) to summarize. Returns truncated content.',
      objectSchema({'text': str, 'path': str}));

  @override
  Future<Object?> run(Map<String, dynamic> a, ToolContext c) async {
    var text = (a['text'] as String?) ?? '';
    if (text.isEmpty && a['path'] is String) {
      try {
        text = await extract(a['path'] as String);
      } catch (e) {
        return {'error': 'could not read file: $e'};
      }
    }
    const limit = 12000;
    return {
      'chars': text.length,
      'truncated': text.length > limit,
      'content': text.substring(0, min(limit, text.length)),
    };
  }
}

class JournalWriteTool extends AgentTool {
  @override
  final spec = ToolSpec(
      'journal_write',
      'Save a journal entry the USER wrote (kind: morning|night|free), optionally with the agent question.',
      objectSchema({'kind': str, 'body': str, 'agent_question': str},
          required: ['kind', 'body']));

  @override
  Future<Object?> run(Map<String, dynamic> a, ToolContext c) async {
    final id = await c.db.into(c.db.journalEntries).insert(
        JournalEntriesCompanion.insert(
            kind: a['kind'] as String,
            body: a['body'] as String,
            agentQuestion: Value(a['agent_question'] as String?),
            createdAt: c.now()));
    return {'id': id};
  }
}

class JournalReadTool extends AgentTool {
  @override
  final spec = ToolSpec('journal_read', 'Read recent journal entries.',
      objectSchema({'limit': integer, 'kind': str}));

  @override
  Future<Object?> run(Map<String, dynamic> a, ToolContext c) async {
    final q = c.db.select(c.db.journalEntries);
    if (a['kind'] is String) q.where((t) => t.kind.equals(a['kind'] as String));
    q
      ..orderBy([(t) => OrderingTerm.desc(t.id)])
      ..limit(((a['limit'] as num?) ?? 5).toInt().clamp(1, 20));
    return [
      for (final e in await q.get())
        {
          'kind': e.kind,
          'at': e.createdAt.toIso8601String(),
          'body': e.body,
          'agent_question': e.agentQuestion
        }
    ];
  }
}

class MemoryGetTool extends AgentTool {
  @override
  final spec = ToolSpec('memory_get',
      'Read the user model: goals, mastery, weak topics, streak, mood.', objectSchema({}));

  @override
  Future<Object?> run(Map<String, dynamic> a, ToolContext c) => c.user.snapshot();
}

class MemoryUpdateTool extends AgentTool {
  @override
  final spec = ToolSpec(
      'memory_update',
      'Update the user model: log mood/energy (1-5) or add a goal.',
      objectSchema({'mood': integer, 'energy': integer, 'add_goal': str}));

  @override
  Future<Object?> run(Map<String, dynamic> a, ToolContext c) async {
    if (a['mood'] != null) {
      await c.user.logMood(
          (a['mood'] as num).toInt(), ((a['energy'] as num?) ?? 3).toInt());
    }
    if (a['add_goal'] is String) {
      final g = await c.user.goals;
      await c.user.saveProfile(
          name: await c.user.name, goals: [...g, a['add_goal'] as String]);
    }
    return {'ok': true};
  }
}

class OfflineChallengeTool extends AgentTool {
  OfflineChallengeTool({this.rng});
  final Random? rng;

  @override
  final spec = ToolSpec('offline_challenge',
      'Pick a practice challenge, favouring weak topics.', objectSchema({}));

  @override
  Future<Object?> run(Map<String, dynamic> a, ToolContext c) async {
    final ch = pickChallenge(weakTopics: await c.user.weakTopics(), rng: rng);
    return {'topic': ch.topic, 'prompt': ch.prompt};
  }
}

List<AgentTool> defaultTools(
        {Future<String> Function(String path)? extract}) =>
    [
      CreateTaskTool(),
      UpdateTaskTool(),
      CompleteTaskTool(),
      ListTasksTool(),
      ScheduleCheckinTool(),
      TutorQuizTool(),
      SummarizeTool(extract ?? (p) async => throw UnsupportedError('no extractor')),
      JournalWriteTool(),
      JournalReadTool(),
      MemoryGetTool(),
      MemoryUpdateTool(),
      OfflineChallengeTool(),
    ];
