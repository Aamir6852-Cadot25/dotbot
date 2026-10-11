import 'package:flutter/material.dart';

import '../challenges/challenges_screen.dart';
import 'tutor_screen.dart';

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) => const DefaultTabController(
        length: 2,
        child: Column(children: [
          TabBar(tabs: [Tab(text: 'Socratic tutor'), Tab(text: 'Offline practice')]),
          Expanded(child: TabBarView(children: [TutorScreen(), ChallengesScreen()])),
        ]),
      );
}
