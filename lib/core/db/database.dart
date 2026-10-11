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
  DateTimeColumn get at => dateTime()();
}

class MentorEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get trigger => text()();
  BoolColumn get spoke => boolean()();
  DateTimeColumn get at => dateTime()();
}

class Checkins extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get reason => text()();
  DateTimeColumn get at => dateTime()();
  BoolColumn get fired => boolean().withDefault(const Constant(false))();
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
  Kv,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  AppDatabase.open() : super(driftDatabase(name: 'dotbot'));

  @override
  int get schemaVersion => 1;
}
