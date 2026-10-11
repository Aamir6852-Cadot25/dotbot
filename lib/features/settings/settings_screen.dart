import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _State();
}

class _State extends ConsumerState<SettingsScreen> {
  final _key = TextEditingController();
  String _provider = 'gemini';
  String? _note;

  @override
  void initState() {
    super.initState();
    ref.read(userProvider).getKv('provider').then((v) {
      if (v != null && mounted) setState(() => _provider = v);
    });
  }

  Future<void> _saveKey() async {
    await ref.read(userProvider).setKv('provider', _provider);
    if (_key.text.trim().isNotEmpty) {
      await ref.read(keyStoreProvider).write(_provider, _key.text.trim());
      _key.clear();
    }
    ref.read(llmEpochProvider.notifier).state++;
    setState(() => _note = 'Saved.');
  }

  Future<void> _tickNow() async {
    final r = await ref.read(mentorProvider).tick();
    setState(() => _note = r.decision.speak
        ? 'Dotbot spoke (${r.decision.trigger?.name}).'
        : 'Staying quiet: ${r.decision.reason}');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('AI provider', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
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
            labelText: 'New $_provider API key (leave empty to keep current)'),
      ),
      const SizedBox(height: 12),
      FilledButton(onPressed: _saveKey, child: const Text('Save')),
      const Divider(height: 40),
      OutlinedButton(
          onPressed: _tickNow, child: const Text('Run mentor check now')),
      if (_note != null)
        Padding(padding: const EdgeInsets.only(top: 12), child: Text(_note!)),
    ]);
  }
}
