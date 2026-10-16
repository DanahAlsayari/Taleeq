import 'package:flutter/material.dart';
import 'package:client/theme/taleeq_theme.dart';
import 'package:client/presentation_layer/trainingUI/exercise_prep_screen_prepared.dart';

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: TaleeqTheme.lightTheme,
    home: ExercisePrepScreen(
      previewExercise: previewExercise,
      onStart: (technique) {
        debugPrint('Exercise ID: ${previewExercise.id}, Selected Technique ID: ${technique.id}');
      },
    ),
  ));
}
