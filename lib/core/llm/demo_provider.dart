import 'dart:convert';

import 'llm_provider.dart';

/// Offline, deterministic "brain" for live demos and for users without a key.
/// It follows the same function-calling protocol as real models, so the agent
/// loop, tools and trace view behave exactly as with Gemini/Groq.
class DemoProvider implements LlmProvider {
  @override
  String get id => 'demo';

  int _n = 0;
  ToolCall _call(String name, Map<String, dynamic> args) =>
      ToolCall(id: 'demo_${_n++}', name: name, args: args);

  @override
  Future<LlmResponse> chat(List<ChatMsg> messages,
      {List<ToolSpec> tools = const []}) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final system = messages.first.role == Role.system ? messages.first.content : '';
    final last = messages.last;
    final lower = last.content.toLowerCase();

    // After tools ran: summarise what was observed.
    if (last.role == Role.tool) return LlmResponse(text: _afterTools(messages));

    final u = last.content;
    final canUseTools = tools.isNotEmpty;

    // ---- non-agent prompts (tutor, journal, reflection) ----
    if (system.contains('Socratic Java/DSA tutor')) return LlmResponse(text: _tutor(u));
    if (system.contains('Stoic mentor')) {
      final past = RegExp(r'(did|was|felt|skipped|went|today i)')
          .hasMatch(lower.replaceAll('today i will', ''));
      return LlmResponse(
          text: past
              ? 'If tomorrow repeated today exactly, what is the one thing you would change?'
              : 'What is most likely to pull you off track today, and what will you do in that moment?');
    }
    if (system.contains('reflecting privately')) {
      return const LlmResponse(
          text: 'I spoke less today and the nudges I did send mostly led to action. '
              'I should keep holding back hints on topics Aamir is getting good at.');
    }

    // ---- proactive briefs from the mentor ----
    if (u.startsWith('[system event]')) {
      if (lower.contains('overdue') && canUseTools) {
        return LlmResponse(
            text: 'Checking the plan first.', toolCalls: [_call('list_tasks', {})]);
      }
      if (lower.contains('low mood')) {
        return const LlmResponse(
            text: 'Hey, I noticed today feels heavy. That is okay. '
                'Maybe step away for a bit: call someone you love or take a short walk outside. '
                'Studying can wait an hour.');
      }
      if (lower.contains('morning')) {
        return const LlmResponse(
            text: 'Good morning! Before anything else: what is ONE thing that would make today a win? Write it in your own words.');
      }
      if (lower.contains('night')) {
        return const LlmResponse(
            text: 'Day is done. Take two minutes: what went well, and what will you do differently tomorrow?');
      }
      if (lower.contains('streak')) {
        return const LlmResponse(
            text: 'Streak broke. No drama: one 15-minute problem today restarts it.');
      }
      if (lower.contains('quiz')) {
        return LlmResponse(
            text: 'Let me find something to practise.',
            toolCalls: [_call('offline_challenge', {})]);
      }
      return const LlmResponse(text: 'Quick check-in: how is it going?');
    }

    if (!canUseTools) return const LlmResponse(text: 'Okay. What will you do next?');

    // ---- chat: pick tools like a real agent would ----
    if (RegExp(r'\b(lonely|sad|low|tired|stressed|alone)\b').hasMatch(lower)) {
      return LlmResponse(
          text: 'They sound low. I will log the mood, then respond gently.',
          toolCalls: [_call('memory_update', {'mood': 2, 'energy': 2})]);
    }
    final person = RegExp(r'my (mom|mother|dad|father|sister|brother|friend|best friend) (?:is )?(\w+)?')
        .firstMatch(lower);
    if (person != null || lower.contains('remember')) {
      final fact = u.replaceFirst(RegExp(r'^(please )?remember( that)?', caseSensitive: false), '').trim();
      return LlmResponse(
          text: 'This is worth remembering long-term.',
          toolCalls: [
            _call('memory_remember',
                {'category': person != null ? 'person' : 'fact', 'content': fact})
          ]);
    }
    if (lower.contains('plan')) {
      final now = DateTime.now();
      String at(int h) => DateTime(now.year, now.month, now.day, h).toIso8601String();
      return LlmResponse(
          text: 'I will check memory for weak topics, then build a small plan.',
          toolCalls: [
            _call('memory_get', {}),
            _call('create_task', {'title': 'Solve 2 array problems (no hints first)', 'topic': 'arrays', 'due': at(11)}),
            _call('create_task', {'title': 'Revise linked-list reversal', 'topic': 'linked-list', 'due': at(16)}),
            _call('create_task', {'title': 'Go outside for 30 min / call a friend', 'due': at(18)}),
          ]);
    }
    if (lower.contains('done') || lower.contains('finished') || lower.contains('completed')) {
      return LlmResponse(
          text: 'Let me see which task that was.', toolCalls: [_call('list_tasks', {})]);
    }
    if (lower.contains('quiz') || lower.contains('practice') || lower.contains('challenge')) {
      return LlmResponse(
          text: 'Picking a challenge from a weak topic.',
          toolCalls: [_call('offline_challenge', {})]);
    }
    if (lower.contains('summar')) {
      final path = RegExp(r'[A-Za-z]:\\[^\n]+|/[^\s]+\.(pdf|txt|md)').firstMatch(u)?.group(0);
      return LlmResponse(
          text: 'Reading the document first.',
          toolCalls: [_call('summarize_text', path != null ? {'path': path} : {'text': u})]);
    }
    if (lower.contains('what do you know') || lower.contains('about me')) {
      return LlmResponse(
          text: 'Reading my memory of you.', toolCalls: [_call('memory_get', {})]);
    }
    if (lower.contains('journal')) {
      return LlmResponse(text: 'Opening the journal.', toolCalls: [_call('journal_read', {'limit': 3})]);
    }
    return const LlmResponse(
        text: 'I am in offline demo mode. Try: "plan my day", "quiz me", "I feel lonely", '
            '"remember my friend Rahul loves cricket", or "what do you know about me".');
  }

  String _afterTools(List<ChatMsg> m) {
    final obs = <String, String>{};
    for (final x in m.reversed) {
      if (x.role != Role.tool) break;
      obs[x.name!] = x.content;
    }
    if (obs.containsKey('create_task')) {
      return 'Plan is set: 2 study blocks and 1 real-life break. Start with arrays, '
          'and try each problem for 10 minutes before asking me for a hint.';
    }
    if (obs.containsKey('memory_update')) {
      return 'I hear you. Feeling low happens, and it does not mean you are behind. '
          'Do me a favour: message a friend or call home today, even for 5 minutes. '
          'I will be here after, but people first.';
    }
    if (obs.containsKey('memory_remember')) {
      return 'Got it, saved to my memory. You can see or delete it anytime on the Memory page.';
    }
    if (obs.containsKey('offline_challenge')) {
      final c = _json(obs['offline_challenge']!);
      return 'Try this one (${c['topic']}): ${c['prompt']} Give it an honest attempt before asking for a hint.';
    }
    if (obs.containsKey('list_tasks')) {
      final list = (jsonDecode(obs['list_tasks']!) as List);
      if (list.isEmpty) return 'Your plan is empty. Want me to plan the day?';
      final t = list.first as Map;
      return 'Next up: "${t['title']}". 25 focused minutes, phone face down. Go.';
    }
    if (obs.containsKey('memory_get')) {
      final s = _json(obs['memory_get']!);
      final mem = (s['memories'] as List?)?.take(3).join('; ');
      return 'Here is what I know: goals ${s['goals']}, streak ${s['streak']} days, '
          'weak topics ${s['weakTopics']}${mem == null || mem.isEmpty ? '' : '. Memories: $mem'}.';
    }
    if (obs.containsKey('summarize_text')) {
      final s = _json(obs['summarize_text']!);
      final c = (s['content'] as String? ?? '').replaceAll(RegExp(r'\s+'), ' ');
      if (c.isEmpty) return 'I could not read that document.';
      final sentences = c.split(RegExp(r'(?<=[.!?])\s')).take(3).join(' ');
      return 'Summary (first key points): $sentences';
    }
    if (obs.containsKey('journal_read')) {
      return 'You have been writing consistently. What pattern do you notice in your last few entries?';
    }
    return 'Done.';
  }

  String _tutor(String prompt) {
    if (prompt.startsWith('Ask ONE')) {
      final topic = RegExp(r'"(.+?)"').firstMatch(prompt)?.group(1) ?? 'arrays';
      return switch (topic) {
        'linked-list' || 'linked list' => 'How would you detect a cycle in a singly linked list using O(1) extra space?',
        'trees' => 'How do you find the height of a binary tree, and what is its time complexity?',
        'dp' => 'How many ways can you climb n stairs taking 1 or 2 steps at a time?',
        _ => 'Given an int array, how would you find the second largest distinct value in ONE pass?',
      };
    }
    if (prompt.contains('Student answer:')) {
      final ans = prompt.split('Student answer:').last.toLowerCase();
      final good = ['max', 'pointer', 'slow', 'fast', 'recurs', 'dp[', 'one pass', 'o(n)']
          .any(ans.contains);
      return good
          ? 'CORRECT\nGood reasoning. Now try to write it without looking anything up.'
          : 'INCORRECT\nThink about what you need to remember while scanning only once.';
    }
    if (prompt.contains('ONE guiding question')) {
      return 'What information would you need to keep track of as you scan from left to right?';
    }
    if (prompt.contains('ONE small hint')) {
      return 'Hint: you only ever need two variables, not a sorted copy.';
    }
    if (prompt.contains('first step')) {
      return 'Skeleton: int first = MIN, second = MIN; for (int x : a) { if (x > first) { ___ } else if (___) { second = x; } }';
    }
    return 'Full solution: keep first and second. If x > first, second = first and first = x; '
        'else if x < first and x > second, second = x. O(n) time, O(1) space. Now explain it back to me.';
  }

  static Map<String, dynamic> _json(String s) {
    try {
      return Map<String, dynamic>.from(jsonDecode(s) as Map);
    } catch (_) {
      return const {};
    }
  }
}
