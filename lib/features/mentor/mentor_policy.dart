import 'dart:math';

enum Cause { lowMood, missedTasks, streakBroken, lowQuiz, morning, night, checkin }

enum Tone { gentle, firm, warm }

/// Everything the policy needs; built from the DB by MentorService.
class MentorState {
  const MentorState({
    required this.now,
    this.overdueTasks = 0,
    this.streakBroken = false,
    this.recentQuizScore,
    this.quizAttempts = 0,
    this.recentMood,
    this.morningTime = const Duration(hours: 7),
    this.nightTime = const Duration(hours: 22),
    this.morningDone = false,
    this.nightDone = false,
    this.dueCheckin = false,
    this.spokeToday = 0,
    this.lastSpokeAt,
    this.lastWasDeliberateSkip = false,
    this.spokenToday = const {},
  });

  final DateTime now;
  final int overdueTasks;
  final bool streakBroken;
  final double? recentQuizScore;
  final int quizAttempts;
  final double? recentMood; // 1..5
  final Duration morningTime; // time-of-day
  final Duration nightTime;
  final bool morningDone;
  final bool nightDone;
  final bool dueCheckin;
  final int spokeToday;
  final DateTime? lastSpokeAt;
  final bool lastWasDeliberateSkip;

  /// Causes already spoken about today (one-shot nudges don't repeat).
  final Set<Cause> spokenToday;
}

class Decision {
  const Decision.speak(this.trigger, this.tone, this.reason)
      : speak = true,
        deliberate = false;
  const Decision.silent(this.reason, {this.trigger, this.deliberate = false})
      : speak = false,
        tone = Tone.warm;

  final bool speak;
  final Cause? trigger;
  final Tone tone;
  final String reason;

  /// True when the policy chose not to intervene although a trigger fired.
  final bool deliberate;
}

/// Rule-based, zero-LLM-cost decision about whether the mentor speaks now.
class MentorPolicy {
  const MentorPolicy({
    this.dailyBudget = 3,
    this.minGap = const Duration(minutes: 90),
    this.skipChance = 0.25,
    this.checkinWindow = const Duration(minutes: 45),
    this.lowMood = 2.2,
    this.lowQuiz = 0.4,
  });

  MentorPolicy withBudget(int budget) => MentorPolicy(
        dailyBudget: budget,
        minGap: minGap,
        skipChance: skipChance,
        checkinWindow: checkinWindow,
        lowMood: lowMood,
        lowQuiz: lowQuiz,
      );

  /// Max proactive messages per day (the "silence budget").
  final int dailyBudget;
  final Duration minGap;

  /// Chance to deliberately stay quiet on a non-urgent trigger, so the user
  /// learns to self-correct.
  final double skipChance;
  final Duration checkinWindow;
  final double lowMood;
  final double lowQuiz;

  Tone toneFor(MentorState s, Cause t) {
    final mood = s.recentMood;
    if (t == Cause.lowMood || (mood != null && mood <= lowMood)) {
      return Tone.gentle;
    }
    if (t == Cause.missedTasks || t == Cause.streakBroken) {
      return Tone.firm;
    }
    return Tone.warm;
  }

  Decision decide(MentorState s, Random rng) {
    // User-requested check-ins always go through.
    if (s.dueCheckin) {
      return Decision.speak(Cause.checkin, toneFor(s, Cause.checkin),
          'scheduled check-in is due');
    }
    final trigger = _firstTrigger(s);
    if (trigger == null) return const Decision.silent('nothing to say');

    // Care comes first: low mood ignores the gap and the budget.
    final care = trigger == Cause.lowMood;
    final last = s.lastSpokeAt;
    if (!care && last != null && s.now.difference(last) < minGap) {
      return const Decision.silent('spoke recently');
    }

    // Rituals happen at times the user chose, so they don't spend the budget.
    final ritual = trigger == Cause.morning || trigger == Cause.night;
    if (!care && !ritual && s.spokeToday >= dailyBudget) {
      return const Decision.silent('silence budget spent');
    }

    // Care and rituals are never skipped; nudges sometimes are.
    final urgent = trigger == Cause.lowMood || ritual;
    if (!urgent && !s.lastWasDeliberateSkip && rng.nextDouble() < skipChance) {
      return Decision.silent('deliberate non-intervention',
          trigger: trigger, deliberate: true);
    }
    return Decision.speak(trigger, toneFor(s, trigger), 'trigger ${trigger.name}');
  }

  Cause? _firstTrigger(MentorState s) {
    final mood = s.recentMood;
    if (mood != null && mood <= lowMood) return Cause.lowMood;
    if (_inWindow(s.now, s.morningTime) && !s.morningDone) return Cause.morning;
    if (_inWindow(s.now, s.nightTime) && !s.nightDone) return Cause.night;
    if (s.overdueTasks >= 2) return Cause.missedTasks;
    if (s.streakBroken && !s.spokenToday.contains(Cause.streakBroken)) {
      return Cause.streakBroken;
    }
    final q = s.recentQuizScore;
    if (q != null &&
        s.quizAttempts >= 3 &&
        q < lowQuiz &&
        !s.spokenToday.contains(Cause.lowQuiz)) {
      return Cause.lowQuiz;
    }
    return null;
  }

  bool _inWindow(DateTime now, Duration timeOfDay) {
    final mid = DateTime(now.year, now.month, now.day).add(timeOfDay);
    final d = now.difference(mid);
    return d >= Duration.zero && d <= checkinWindow;
  }
}

/// Prompt style per tone, injected into the system prompt.
String toneInstruction(Tone t) => switch (t) {
      Tone.gentle =>
        'Be gentle and kind. Acknowledge how they feel. Lower the bar for today. No guilt.',
      Tone.firm =>
        'Be firm and direct, like a coach. No excuses, name the slip, set one concrete next action.',
      Tone.warm => 'Be warm, concise and encouraging.',
    };
