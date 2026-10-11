import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get topic => text().nullable()();
  DateTimeColumn get dueAt => dateTime().nullable()();
  DateTimeColumn get doneAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

class JournalEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// morning | night | free
  TextColumn get kind => text()();
  TextColumn get body => text()();
  TextColumn get agentQuestion => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

class MoodLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get mood => integer()(); // 1..5
  IntColumn get energy => integer()(); // 1..5
  DateTimeColumn get at => dateTime()();
}

class TopicMasteryRows extends Table {
  TextColumn get topic => text()();
  RealColumn get mastery => real().withDefault(const Constant(0.0))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {topic};
}

class QuizResults extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get topic => text()();
  BoolColumn get correct => boolean()();
  IntColumn get hintLevel => integer().withDefault(const Constant(0))();
  DateTimeColumn get at => dateTime()();
}

class ChatMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get role => text()(); // user | assistant
  TextColumn get content => text()();

  /// JSON list of agent steps (thought/tool/observation) for the trace view.
  TextColumn get trace => text().nullable()();
  DateTimeColumn get at => dateTime()();
}

class MentorEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get trigger => text()();
  BoolColumn get spoke => boolean()();
  TextColumn get reason => text().withDefault(const Constant(''))();
  TextColumn get tone => text().nullable()();
  TextColumn get message => text().nullable()();

  /// Set by reflection: did the user act within 2h after this nudge?
  BoolColumn get effective => boolean().nullable()();
  DateTimeColumn get at => dateTime()();
}

class Checkins extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get reason => text()();
  DateTimeColumn get at => dateTime()();
  BoolColumn get fired => boolean().withDefault(const Constant(false))();
}

/// Long-term memory the user can inspect and delete.
class Facts extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// goal | preference | person | fact | strategy
  TextColumn get category => text()();
  TextColumn get content => text()();

  /// user | agent | reflection
  TextColumn get source => text().withDefault(const Constant('agent'))();
  DateTimeColumn get createdAt => dateTime()();
}

/// Nightly self-reflection by the agent on its own behaviour.
class Reflections extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get day => text()();
  TextColumn get summary => text()();
  TextColumn get strategy => text()();
  TextColumn get stats => text()(); // JSON
  DateTimeColumn get createdAt => dateTime()();
}

class Kv extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [
  Tasks,
  JournalEntries,
  MoodLogs,
  TopicMasteryRows,
  QuizResults,
  ChatMessages,
  MentorEvents,
  Checkins,
  Facts,
  Reflections,
  Kv,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  AppDatabase.open() : super(driftDatabase(name: 'dotbot'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(chatMessages, chatMessages.trace);
            await m.addColumn(mentorEvents, mentorEvents.reason);
            await m.addColumn(mentorEvents, mentorEvents.tone);
            await m.addColumn(mentorEvents, mentorEvents.message);
            await m.addColumn(mentorEvents, mentorEvents.effective);
            await m.createTable(facts);
            await m.createTable(reflections);
          }
        },
      );
}
