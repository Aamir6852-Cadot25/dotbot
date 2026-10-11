import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _State();
}

class _State extends ConsumerState<OnboardingScreen> {
  final _name = TextEditingController();
  final _goals = TextEditingController(text: 'Java, DSA, placements');
  final _key = TextEditingController();
  TimeOfDay _morning = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _night = const TimeOfDay(hour: 22, minute: 0);
  String _provider = 'gemini';
  bool _busy = false;

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pick(bool morning) async {
    final t = await showTimePicker(
        context: context, initialTime: morning ? _morning : _night);
    if (t != null) setState(() => morning ? _morning = t : _night = t);
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final user = ref.read(userProvider);
    await user.saveProfile(
      name: _name.text.trim(),
      goals: _goals.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      morningTime: _fmt(_morning),
      nightTime: _fmt(_night),
    );
    await user.setKv('provider', _provider);
    if (_key.text.trim().isNotEmpty) {
      await ref.read(keyStoreProvider).write(_provider, _key.text.trim());
    }
    ref.read(llmEpochProvider.notifier).state++;
    ref.invalidate(onboardedProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text('Meet Dotbot',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                const Text(
                    'A mentor that stays quiet, speaks when it matters, and works to make you independent.'),
                const SizedBox(height: 24),
                TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Your name')),
                const SizedBox(height: 12),
                TextField(
                    controller: _goals,
                    decoration: const InputDecoration(
                        labelText: 'Goals (comma separated)')),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                      child: OutlinedButton(
                          onPressed: () => _pick(true),
                          child: Text('Morning ${_fmt(_morning)}'))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: OutlinedButton(
                          onPressed: () => _pick(false),
                          child: Text('Night ${_fmt(_night)}'))),
                ]),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'gemini', label: Text('Gemini')),
                    ButtonSegment(value: 'groq', label: Text('Groq')),
                  ],
                  selected: {_provider},
                  onSelectionChanged: (s) => setState(() => _provider = s.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _key,
                  obscureText: true,
                  decoration: InputDecoration(
                      labelText: 'Paste your free $_provider API key',
                      helperText:
                          'Stored only on this device. You can skip and add it later.'),
                ),
                const SizedBox(height: 24),
                FilledButton(
                    onPressed: _busy ? null : _save,
                    child: const Text('Start')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
