import 'models/training_models.dart';
import 'training_local_data.dart';

/// Data source for the training page.
///
/// Later: add `SupabaseTrainingRepository implements TrainingRepository`
/// that reads categories/exercises from Supabase and maps them to
/// [TrainingCategory] / [TrainingExercise]. The UI does not need to change.
abstract interface class TrainingRepository {
  Future<List<TrainingCategory>> fetchCategories();
}

class LocalTrainingRepository implements TrainingRepository {
  const LocalTrainingRepository();

  @override
  Future<List<TrainingCategory>> fetchCategories() async => kTrainingCategories;
}
