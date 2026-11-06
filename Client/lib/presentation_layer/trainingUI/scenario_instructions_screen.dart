
import 'package:flutter/material.dart';
import 'package:client/models/scenario_model.dart';
import 'package:client/presentation_layer/trainingUI/scenario_screen.dart';
class ScenarioInstructionsScreen extends StatelessWidget {
  const ScenarioInstructionsScreen({
    super.key,
    required this.attemptId,
    required this.scenario,
  });

  final String attemptId;
  final ScenarioModel scenario;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ScenarioScreen(
                    attemptId: attemptId,
                    scenario: scenario,
                  ),
                ),
              );
            },
            child: const Text('ابدأ السيناريو'),
          ),
        ),
      ),
    );
  }
}
