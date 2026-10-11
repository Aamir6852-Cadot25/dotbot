import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/llm/demo_provider.dart';
import '../chat/trace_view.dart';
import 'day_simulator.dart';

/// Live timeline of a simulated student's day (for presentations).
class DemoScreen extends ConsumerStatefulWidget {
  const DemoScreen({super.key});
  @override
  ConsumerState<DemoScreen> createState() => _State();
}

class _State extends ConsumerState<DemoScreen> {
  final _events = <SimEvent>[];
  final _scroll = ScrollController();
  bool _running = false;
  bool _offline = true;

  Future<void> _run() async {
    setState(() {
      _events.clear();
      _running = true;
    });
    final llm = _offline ? DemoProvider() : await ref.read(llmProvider.future) ?? DemoProvider();
    try {
      await DaySimulator(
        db: ref.read(dbProvider),
        llm: llm,
        notifier: ref.read(notifierProvider),
      ).run((e) {
        if (!mounted) return;
        setState(() => _events.add(e));
        Future<void>.delayed(const Duration(milliseconds: 80), () {
          if (_scroll.hasClients) {
            _scroll.animateTo(_scroll.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
          }
        });
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Simulation stopped: $e')));
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text("A student's day")),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
                'Replays one full day in about a minute with a simulated clock. '
                'It drives the real mentor policy, agent, tools, tutor and reflection, '
                'and writes the results into the app (Today, Chat, Memory, Insights).'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Offline demo brain'),
              subtitle: const Text('Turn off to use your real Gemini/Groq key'),
              value: _offline,
              onChanged: _running ? null : (v) => setState(() => _offline = v),
            ),
            FilledButton.icon(
              onPressed: _running ? null : _run,
              icon: const Icon(Icons.play_arrow),
              label: Text(_running ? 'Running…' : 'Start the day'),
            ),
          ]),
        ),
        const Divider(height: 24),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: _events.length,
            itemBuilder: (_, i) => _EventTile(_events[i], th),
          ),
        ),
      ]),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile(this.e, this.th);
  final SimEvent e;
  final ThemeData th;

  @override
  Widget build(BuildContext context) {
    final cs = th.colorScheme;
    final (icon, color) = switch (e.actor) {
      'user' => (Icons.person_outline, cs.secondary),
      'agent' => (Icons.smart_toy_outlined, cs.primary),
      'silent' => (Icons.volume_off_outlined, cs.outline),
      _ => (Icons.schedule, cs.tertiary),
    };
    final time =
        '${e.time.hour.toString().padLeft(2, '0')}:${e.time.minute.toString().padLeft(2, '0')}';
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
          width: 48,
          child: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(time, style: th.textTheme.labelMedium),
          )),
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: CircleAvatar(
            radius: 14, backgroundColor: color, child: Icon(icon, size: 16, color: cs.surface)),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          color: e.actor == 'agent' ? cs.primaryContainer.withValues(alpha: .5) : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.title, style: th.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(e.detail),
              if (e.trace.length > 1)
                Theme(
                  data: th.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    dense: true,
                    title: Text('Reasoning trace (${e.trace.length} steps)',
                        style: th.textTheme.labelMedium),
                    children: [TraceView(e.trace)],
                  ),
                ),
            ]),
          ),
        ),
      ),
    ]);
  }
}
