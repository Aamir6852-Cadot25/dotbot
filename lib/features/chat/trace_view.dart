import 'package:flutter/material.dart';

import '../agent/agent.dart';

/// Renders Think -> Tool -> Observe -> Answer steps so the agent's reasoning
/// is visible (and explainable in a demo).
class TraceView extends StatelessWidget {
  const TraceView(this.steps, {super.key, this.live = false});
  final List<AgentStep> steps;
  final bool live;

  static (IconData, String) _style(String kind) => switch (kind) {
        'think' => (Icons.psychology_outlined, 'Think'),
        'tool' => (Icons.build_outlined, 'Act'),
        'observe' => (Icons.visibility_outlined, 'Observe'),
        'answer' => (Icons.chat_bubble_outline, 'Answer'),
        _ => (Icons.warning_amber_outlined, 'Limit'),
      };

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final mono = th.textTheme.bodySmall?.copyWith(fontFamily: 'monospace');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (live)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('Agent is working…', style: th.textTheme.labelLarge),
        ),
      for (var i = 0; i < steps.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(_style(steps[i].kind).$1, size: 18, color: th.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(TextSpan(children: [
                TextSpan(
                    text: '${_style(steps[i].kind).$2}'
                        '${steps[i].tool == null ? '' : ' · ${steps[i].tool}'}  ',
                    style: th.textTheme.labelMedium),
                TextSpan(
                    text: steps[i].text,
                    style: steps[i].kind == 'tool' || steps[i].kind == 'observe'
                        ? mono
                        : th.textTheme.bodySmall),
              ])),
            ),
          ]),
        ),
    ]);
  }
}
