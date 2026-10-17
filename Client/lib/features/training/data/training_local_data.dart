import 'models/training_models.dart';

/// TEMPORARY local data for the nine exercises.
/// Durations of the three games and their default levels are placeholders:
/// replace them with the real values from Notion / Supabase.
const List<TrainingCategory> kTrainingCategories = [
  TrainingCategory(
    id: 'speech_practice',
    kind: TrainingCategoryKind.speechPractice,
    titleAr: 'تمارين الكلام',
    titleEn: 'Speech Practice',
    descriptionAr: 'تمارين تساعدك على تحسين سلاسة الكلام وتطوير مهاراتك في التحدث.',
    exercises: [
      TrainingExercise(
        id: 'reading',
        type: ExerciseType.reading,
        titleAr: 'القراءة بصوت عالٍ',
        titleEn: 'Reading',
        descriptionAr: 'اقرأ نصوصًا متنوعة وتدرّب على سلاسة الكلام.',
        durationMinutes: 5,
        defaultDifficulty: Difficulty.easy,
      ),
      TrainingExercise(
        id: 'picture_description',
        type: ExerciseType.pictureDescription,
        titleAr: 'وصف الصور',
        titleEn: 'Picture Description',
        descriptionAr: 'صف ما تراه في الصورة باستخدام صوتك.',
        durationMinutes: 5,
        defaultDifficulty: Difficulty.medium,
      ),
      TrainingExercise(
        id: 'question_answer',
        type: ExerciseType.questionAnswer,
        titleAr: 'السؤال والإجابة',
        titleEn: 'Question & Answer',
        descriptionAr: 'أجب عن أسئلة متنوعة وتحدث بثقة.',
        durationMinutes: 5,
        defaultDifficulty: Difficulty.easy,
      ),
      TrainingExercise(
        id: 'storytelling',
        type: ExerciseType.storytelling,
        titleAr: 'سرد القصص',
        titleEn: 'Storytelling',
        descriptionAr: 'احكِ قصة من خلال صورة أو موضوع محدد.',
        durationMinutes: 6,
        defaultDifficulty: Difficulty.advanced,
      ),
      TrainingExercise(
        id: 'free_speech',
        type: ExerciseType.freeSpeech,
        titleAr: 'التحدث الحر',
        titleEn: 'Free Speech',
        descriptionAr: 'تحدث بحرية عن موضوع يهمك.',
        durationMinutes: 5,
        defaultDifficulty: Difficulty.medium,
      ),
    ],
  ),
  TrainingCategory(
    id: 'real_life_scenarios',
    kind: TrainingCategoryKind.realLifeScenarios,
    titleAr: 'مواقف الحياة',
    titleEn: 'Real-Life Scenarios',
    descriptionAr: 'تدرّب على مواقف من الحياة اليومية وتعلّم كيفية التحدث في مواقف واقعية.',
    exercises: [
      TrainingExercise(
        id: 'real_life_scenarios',
        type: ExerciseType.realLifeScenarios,
        titleAr: 'محاكاة المواقف الحياتية',
        titleEn: 'Real-Life Scenarios',
        descriptionAr: 'تدرّب على محادثات من الحياة اليومية مثل طلب قهوة أو مقابلة وظيفية.',
        durationMinutes: 8,
        defaultDifficulty: Difficulty.medium,
      ),
    ],
  ),
   TrainingCategory(
    id: 'speaking_games',
    kind: TrainingCategoryKind.speakingGames,
    titleAr: 'ألعاب الكلام',
    titleEn: 'Speaking Games',
    descriptionAr:
        'مارس الكلام بطريقة ممتعة من خلال ألعاب تفاعلية '
        'تساعدك على تطوير الطلاقة.',
    exercises: [
      TrainingExercise(
        id: 'counting_challenge',
        type: ExerciseType.countingChallenge,
        titleAr: 'تحدي التعداد',
        titleEn: 'Counting Challenge',
        descriptionAr:
            'اذكر أكبر عدد ممكن من الكلمات ضمن الفئة '
            'المحددة قبل انتهاء الوقت.',
        durationMinutes: 1,
        durationSeconds: 20,
        defaultDifficulty: Difficulty.easy,
      ),
      TrainingExercise(
        id: 'dont_say_it',
        type: ExerciseType.dontSayIt,
        titleAr: 'الكلمة الممنوعة',
        titleEn: "Don't Say It",
        descriptionAr:
            'صف الشيء المطلوب دون نطق الكلمات الممنوعة، '
            'وحاول إيصال المعنى بوضوح.',
        durationMinutes: 1,
        durationSeconds: 30,
        defaultDifficulty: Difficulty.medium,
      ),
    ],
  ),
];
