import 'package:client/theme/taleeq_theme.dart';
import 'package:flutter/material.dart';
import '../../services/exercise_api_service.dart';


class ExerciseResultScreen extends StatefulWidget {
    final Map<String, dynamic>? result;
    final Map<String, dynamic>? exercise;
    final bool embedded;

  const ExerciseResultScreen({
    super.key,
     this.result,
     this.exercise,
     this.embedded = false,
  });

  @override
  State<ExerciseResultScreen> createState() =>
      _ExerciseResultScreenState();
}

class _ExerciseResultScreenState extends State<ExerciseResultScreen> {
  List<Map<String, dynamic>> attempts = [];
  int currentIndex = 0;
  bool _isLoading = true;
  String? _loadError;
  String _selectedExerciseFilter = 'الكل';
  bool _showAllAttempts = false;

  

  @override
    void initState() {
    super.initState();

    if (widget.embedded || widget.result == null) {
      loadAttempts();
    }
  }

  Future<void> loadAttempts() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final data = await ExerciseApiService().getAllAttempts();

      if (!mounted) return;

      setState(() {
        attempts = data;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('خطأ في جلب المحاولات: $e');

      if (!mounted) return;

      setState(() {
        _loadError = 'تعذر تحميل محاولات التدريب، حاولي مرة ثانية.';
        _isLoading = false;
      });
    }
  }

Widget _buildProgressSummary() {
  if (attempts.isEmpty) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('ما عندك محاولات تدريب حتى الآن'),
      ),
    );
  }


final exerciseTypeMap = {
  'القراءة': 'Reading',
  'وصف الصورة': 'Picture Description',
  'سرد القصة': 'Storytelling',
};

final selectedType = exerciseTypeMap[_selectedExerciseFilter];

    final filteredAttempts = selectedType == null
        ? (_selectedExerciseFilter == 'الكل'
            ? attempts
            : <Map<String, dynamic>>[])
        : attempts.where((attempt) {
            return attempt['exercise_type'] == selectedType;
          }).toList();


    final scores = filteredAttempts.map((attempt) {
    final data = attempt['scores'];

    if (data is! Map) return null;

    final score = data['total_score'];

    return score is num ? score.toDouble() : null;
  }).whereType<double>().toList();

  final latestScore = scores.isNotEmpty ? scores.first : null;

  final bestScore = scores.isNotEmpty
      ? scores.reduce((a, b) => a > b ? a : b)
      : null;

  final visibleAttempts = _showAllAttempts
    ? filteredAttempts
    : filteredAttempts.take(5).toList();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'ملخص الأداء',
        style: TextStyle(
          fontSize: 23,
          fontWeight: FontWeight.bold,
          color: Color(0xFF203E3A),
        ),
      ),
      SizedBox(height: 8),
      Text(
        'تابع آخر درجة وأفضل درجة في تمارينك.',
        style: TextStyle(
          fontSize: 13,
          color: Color(0xFF7A8E8B),
        ),
      ),

const SizedBox(height: 20),



Container(
  width: double.infinity,
  padding: const EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 4,
  ),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(
      color: TaleeqTheme.borderSubtle,
      width: 1,
    ),
    boxShadow: TaleeqTheme.cardShadow
  ),
  child:
DropdownButtonHideUnderline(
  child: DropdownButton<String>(
    value: _selectedExerciseFilter,
    isExpanded: true,
    itemHeight: 48,
    menuMaxHeight: 300,
    dropdownColor: Colors.white,
    borderRadius: BorderRadius.circular(14),

    icon: const Icon(
      Icons.keyboard_arrow_down_rounded,
      color: Color(0xFF578B80),
      size: 20,
    ),

    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: const Color(0xFF203E3A),
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),

    items: [
      'الكل',
      'القراءة',
      'وصف الصورة',
      'سؤال وجواب',
      'سرد القصة',
      'الكلام الحر',
    ].map((filter) {
      return DropdownMenuItem<String>(
        value: filter,
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(filter),
        ),
      );
    }).toList(),

    onChanged: (value) {
      if (value == null) return;

      setState(() {
        _selectedExerciseFilter = value;
        _showAllAttempts = false;
      });
    },
  ),
),
),

const SizedBox(height: 16),

Container(
  width: double.infinity,
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
    color: TaleeqTheme.borderSubtle,
    width: 1,
  ),
    boxShadow: TaleeqTheme.cardShadow
  ),
  child: Row(
    children: [
      Expanded(
        child: Column(
          children: [
            const Text(
              'آخر درجة',
              style: TextStyle(color: Color(0xFF7A8E8B)),
            ),
            const SizedBox(height: 10),
            Text(
              latestScore == null
                  ? '—'
                  : '${latestScore.toStringAsFixed(1)}%',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF203E3A),
              ),
            ),
          ],
        ),
      ),
      Container(
        width: 1,
        height: 55,
        color: const Color(0xFFE9E0D2),
      ),
      Expanded(
        child: Column(
          children: [
            const Text(
              'أفضل درجة',
              style: TextStyle(color: Color(0xFF7A8E8B)),
            ),
            const SizedBox(height: 10),
            Text(
              bestScore == null
                  ? '—'
                  : '${bestScore.toStringAsFixed(1)}%',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF578B80),
              ),
            ),
          ],
        ),
      ),
    ],
  ),
),


const SizedBox(height: 28),

const Text(
  'سجل المحاولات',
  style: TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Color(0xFF203E3A),
  ),
),

const SizedBox(height: 14),

if (visibleAttempts.isEmpty)
  const Padding(
    padding: EdgeInsets.symmetric(vertical: 20),
    child: Center(
      child: Text(
        'ما فيه محاولات لهذا النوع حتى الآن',
        style: TextStyle(color: Color(0xFF7A8E8B)),
      ),
    ),
  ),

...visibleAttempts.map((attempt) {
  final scoreData = attempt['scores'];
  final score = scoreData is Map
      ? scoreData['total_score']
      : null;

  final attemptIndex = attempts.indexOf(attempt);

  final previousAttempts = attempts
      .skip(attemptIndex + 1)
      .where((item) =>
          item['exercise_type'] == attempt['exercise_type'] &&
          item['difficulty'] == attempt['difficulty'])
      .toList();

  final previousScores = previousAttempts.isNotEmpty
      ? previousAttempts.first['scores']
      : null;

  final previousScore = previousScores is Map
      ? previousScores['total_score']
      : null;

  final scoreChange = score is num && previousScore is num
      ? score.toDouble() - previousScore.toDouble()
      : null;
    final type = attempt['exercise_type']?.toString() ?? '';

    final typeLabel = switch (type) {
      'Reading' => 'القراءة',
      'Picture Description' => 'وصف الصورة',
      'Storytelling' => 'سرد القصة',
      _ => type,
    };


    final title = attempt['title']?.toString().trim() ?? '';

    final exerciseTitle = title.isNotEmpty
        ? title
        : 'تمرين $typeLabel';

    final difficulty = attempt['difficulty']?.toString() ?? '';

    final difficultyLabel = switch (difficulty) {
      'Easy' => 'سهل',
      'Medium' => 'متوسط',
      'Hard' => 'صعب',
      _ => difficulty,
    };


  final rawDate = attempt['created_at']?.toString();

  final attemptDate = rawDate == null
      ? null
      : DateTime.tryParse(rawDate)?.toLocal();

  final dateLabel = attemptDate == null
      ? ''
      : '${attemptDate.day}/${attemptDate.month}/${attemptDate.year}';

  return  InkWell(
  borderRadius: BorderRadius.circular(16),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExerciseResultScreen(
          result: attempt,
          exercise: attempt,
        ),
      ),
    );
  },
  child: Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: TaleeqTheme.borderSubtle,
        width: 1,
      ),
      boxShadow: TaleeqTheme.cardShadow
    ),
    child: Row(
      children: [
        const Icon(
          Icons.record_voice_over_rounded,
          color: Color(0xFF578B80),
          size: 26,
        ),
        const SizedBox(width: 12),
        
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                exerciseTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF203E3A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                difficultyLabel.isEmpty
                    ? typeLabel
                    : '$typeLabel • $difficultyLabel',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF7A8E8B),
                ),
              ),

              if (dateLabel.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  dateLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7A8E8B),
                  ),
                ),
              ],
            ],
          ),
        ),
        
Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.end,
  children: [
    Text(
      score is num
          ? '${score.toStringAsFixed(1)}%'
          : '—',
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Color(0xFF578B80),
      ),
    ),

    if (scoreChange != null) ...[
      const SizedBox(height: 6),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            scoreChange > 0
                ? Icons.trending_up_rounded
                : scoreChange < 0
                    ? Icons.trending_down_rounded
                    : Icons.trending_flat_rounded,
            size: 17,
            color: scoreChange > 0
                ? const Color(0xFF287D78)
                : scoreChange < 0
                    ? const Color(0xFFC65A50)
                    : const Color(0xFF7A8E8B),
          ),
          const SizedBox(width: 4),
          Text(
            '${scoreChange > 0 ? '+' : ''}${scoreChange.toStringAsFixed(1)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: scoreChange > 0
                  ? const Color(0xFF287D78)
                  : scoreChange < 0
                      ? const Color(0xFFC65A50)
                      : const Color(0xFF7A8E8B),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
      ],
    ),
    ),
  );
}),

if (filteredAttempts.length > 5)
  Center(
    child: TextButton(
      onPressed: () {
        setState(() {
          _showAllAttempts = !_showAllAttempts;
        });
      },
      child: Text(
        _showAllAttempts ? 'عرض أقل' : 'عرض المزيد',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF578B80),
        ),
      ),
    ),
  ),
    ],
  );
}

  @override
  Widget build(BuildContext context) {

    if (_isLoading && (widget.embedded || widget.result == null)) {
        return const SizedBox(
          height: 450,
          child: Center(
            child: CircularProgressIndicator(
              color: Color(0xFF006B63),
            ),
          ),
        );
      }

      if (_loadError != null && (widget.embedded || widget.result == null)) {
        return SizedBox(
          height: 450,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _loadError!,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: loadAttempts,
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        );
      }

      if (widget.embedded) {
        return _buildProgressSummary();
      }
          if (attempts.isEmpty && widget.result == null) {
        return const Scaffold(
          body: Center(
            child: Text('ما عندك محاولات سابقة حتى الآن'),
          ),
        );
      }



    
    final result = widget.result ??
        attempts[currentIndex];

    final speechEvents = result['speech_events'];
    debugPrint('SPEECH EVENTS: ${result['speech_events']}');
    final List<dynamic> events =
        speechEvents is List ? speechEvents : [];

    final exercise = widget.exercise ?? result;
    debugPrint('EXERCISE RESULT: $result');

    //prepare values
    final scores = Map<String , dynamic>.from(result['scores']);
    final totalScore = (scores['total_score']as num).toDouble();
    


    
    final currentAttemptIndex = attempts.indexWhere(
  (attempt) =>
      attempt['id'] != null &&
      attempt['id'] == result['id'],
);

final currentAttemptDate =
    DateTime.tryParse(result['created_at']?.toString() ?? '');

final olderAttempts = attempts.where((attempt) {
  final sameType =
      attempt['exercise_type'] == result['exercise_type'];

  final sameDifficulty =
      attempt['difficulty'] == result['difficulty'];

  final attemptDate =
      DateTime.tryParse(attempt['created_at']?.toString() ?? '');

  if (!sameType || !sameDifficulty) return false;

  if (currentAttemptDate != null && attemptDate != null) {
    return attemptDate.isBefore(currentAttemptDate);
  }

  // إذا ما توفرت التواريخ، نعتمد على ترتيب السجل من الأحدث للأقدم.
  final index = attempts.indexOf(attempt);
  return currentAttemptIndex >= 0 && index > currentAttemptIndex;
}).toList();

olderAttempts.sort((a, b) {
  final dateA = DateTime.tryParse(a['created_at']?.toString() ?? '');
  final dateB = DateTime.tryParse(b['created_at']?.toString() ?? '');

  if (dateA == null || dateB == null) {
    return attempts.indexOf(a).compareTo(attempts.indexOf(b));
  }

  return dateB.compareTo(dateA);
});

final previousScoreData =
    olderAttempts.isNotEmpty ? olderAttempts.first['scores'] : null;

final previousScore = previousScoreData is Map
    ? (previousScoreData['total_score'] as num?)?.toDouble()
    : null;

final scoreChange =
    previousScore == null ? null : totalScore - previousScore;
    final exerciseTitle = (exercise['title'] ?? '').toString().trim().isNotEmpty
        ? exercise['title'].toString()
        : (result['exercise_type'] == 'Reading'
            ? 'تمرين القراءة'
            : result['exercise_type'] == 'Speaking'
                ? 'تمرين التحدث'
                : 'تمرين سابق');
    final difficulty = exercise['difficulty'] ?? '' ;

    final fluency = (scores['fluency_score'] as num).toDouble();
    final rhythm = (scores['rhythm_score'] as num).toDouble();
    final speed = (scores['speed_control_score'] as num).toDouble();
    final adherence = (scores['task_adherence_score'] as num).toDouble();

    final metrics = Map<String , dynamic>.from(result['metrics']);

    final stuttering = (metrics['stuttering_percent'] as num).toDouble();
    final repetition = (metrics['repetition_percent'] as num).toDouble();
    final prolongation = (metrics['prolongation_percent'] as num).toDouble();
    final blocks = (metrics['block_percent'] as num).toDouble();

    final feedback = Map<String, dynamic>.from(result['feedback']);

    final strengthText = feedback['strength']?.toString() ?? '';
    final improvementText = feedback['improvement']?.toString() ?? '';

    final report = Directionality(

        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: widget.embedded
                ? const NeverScrollableScrollPhysics()
                : null,
            child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [


              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
              
                
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Color(0xFF203E3A),
                        size: 20,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),

                    const Expanded(
                      child: Text(
                        'نتيجة التمرين',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF203E3A),
                        ),
                      ),
                    ),

                    const SizedBox(width: 48),
                  ],
                ),
              ),

              const SizedBox(height: 8),



              //first box
                            
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(
                    color: TaleeqTheme.borderSubtle,
                  ),
                  boxShadow: TaleeqTheme.cardShadow,
                ),
               
                              

                    child: Column(
                            children: [
                              Row(
                                textDirection: TextDirection.rtl,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // يمين: اسم التمرين والصعوبة
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          exerciseTitle,
                                          textAlign: TextAlign.right,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF203E3A),
                                          ),
                                        ),

                                        const SizedBox(height: 9),

                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 13,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF3EEE4),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            difficulty == 'Medium'
                                                ? 'متوسط'
                                                : difficulty == 'Easy'
                                                    ? 'سهل'
                                                    : difficulty == 'Hard'
                                                        ? 'صعب'
                                                        : difficulty,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF806B49),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  Container(
                                    width: 1,
                                    height: 54,
                                    color: TaleeqTheme.borderSubtle,
                                  ),

                                  const SizedBox(width: 12),

                                  // يسار: النسبة
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${totalScore.toStringAsFixed(1)}%',
                                        textDirection: TextDirection.ltr,
                                        style: const TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w800,
                                          height: 1.2,
                                          color: Color(0xFF006B63),
                                        ),
                                      ),

                                      const SizedBox(height: 5),

                                      const Text(
                                        'درجتك الإجمالية',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF647773),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                                

                      const SizedBox(height: 5),

                      const Divider(
                        color: Color.fromARGB(255, 218, 227, 232),
                        thickness: 1,
                      ),

                      const SizedBox(height: 5,),

                      Row(
                  children: [
                    const Icon(
                      Icons.bar_chart_rounded,
                      color: Color(0xFF006B63),
                      size: 25,
                    ),
                    const SizedBox(width: 9),
                    const Expanded(
                      child: Text(
                        'مقاييس الاداء',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF006B63),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'ما معنى مقاييس الأداء؟',
                      icon: const Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFF578B80),
                        size: 21,
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            backgroundColor: const Color(0xFFFCFAF6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                            title: const Text(
                              'ما معنى مقاييس الأداء؟',
                              textDirection: TextDirection.rtl,
                            ),
                            content: const Text(
                              'الطلاقة: مدى سلاسة الكلام واستمراره بدون تأتأه.\n\n'
                              'الإيقاع: مدى انتظام توقيت الكلام والوقفات.\n\n'
                              'التحكم بالسرعة: مدى مناسبة سرعة الكلام.\n\n'
                              'الالتزام بالمهمة: مدى ارتباط الكلام بالمطلوب في التمرين.\n\n'
                              'كلما ارتفعت الدرجة، كان الأداء أفضل.',
                              textDirection: TextDirection.rtl,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('حسنًا'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),

                    const SizedBox(height: 20,),
                   _performanceMetricRow(
                    'الطلاقة',
                    fluency,
                    Icons.record_voice_over_rounded,
                    const Color(0xFF006B63),
                  ),
                  _performanceMetricRow(
                    'الإيقاع',
                    rhythm,
                    Icons.graphic_eq_rounded,
                    const Color(0xFF5FAFA8),
                  ),
                  _performanceMetricRow(
                    'التحكم بالسرعة',
                    speed,
                    Icons.speed_rounded,
                    const Color(0xFF508B9B),
                  ),
                  _performanceMetricRow(
                    'الالتزام بالمهمة',
                    adherence,
                    Icons.task_alt_rounded,
                    const Color(0xFFB28B56),
                  ),
                      
                    ],
                  ),),
                  //end of first box

              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(
                    color: TaleeqTheme.borderSubtle,
                  ),
                  boxShadow: TaleeqTheme.cardShadow,
                ),

                    child: Column(
                    children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_graph_rounded,
                      color: Color(0xFF006B63),
                      size: 25,
                    ),
                    const SizedBox(width: 9),
                    const Expanded(
                      child: Text(
                        'نسب التأتأة',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF006B63),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'ما معنى نسب التأتأة؟',
                      icon: const Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFF578B80),
                        size: 21,
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            backgroundColor: const Color(0xFFFCFAF6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                            title: const Text(
                              'ما معنى نسب التأتأة؟',
                              textDirection: TextDirection.rtl,
                            ),
                            content: const Text(
                              'نسبة التأتأة الكلية: مجموع نسبة مقدار الكلام المتأثر بالتأتأة.\n\n'
                              'التكرار:  لا إرادي للأصوات أو المقاطع اللفظية الأولى للكلمات (مثل: قـ-قـ-قال).\n\n'
                              'الاطالة: مد الصوت الصامت أو الصائت بشكل غير مقصود أثناء نطق الكلمة (مثل: سسسـارة)\n\n'
                              'التوقف: انحباس مؤقت لتدفق الهواء والصوت مما يعيق خروج الكلمة لحظياً.',
                              textDirection: TextDirection.rtl,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('حسنًا'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'نسبة التأتأة الكلية',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF203E3A),
                      ),
                    ),
                    Text(
                      '${stuttering.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF006B63),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LinearProgressIndicator(
                    value: (stuttering / 100).clamp(0.0, 1.0),
                    minHeight: 11,
                    backgroundColor: const Color(0xFFE8EEEB),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF5FAFA8),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'النسبة المقدّرة للكلام المتأثر بالتأتأة.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A9694),
                  ),
                ),

                const SizedBox(height: 20),
                const Divider(color: Color.fromARGB(255, 218, 227, 232)),
                const SizedBox(height: 20),

                _metricRow(
                  'التكرار',
                  repetition,
                  Icons.repeat_rounded,
                  const Color(0xFF006B63),
                ),
                _metricRow(
                  'الإطالة',
                  prolongation,
                  Icons.graphic_eq_rounded,
                  const Color(0xFF5FAFA8),
                ),
                _metricRow(
                  'التوقف',
                  blocks,
                  Icons.pause_circle_outline_rounded,
                  const Color(0xFFFF765B),
                ),
              ],
              )

              ),


              _buildSpeechEvents(events),


              
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(
                    color: TaleeqTheme.borderSubtle,
                  ),
                  boxShadow: TaleeqTheme.cardShadow,
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(
                      Icons.note_alt_outlined,
                      color: Color(0xFF006B63),
                      size: 25,
                    ),
                    const SizedBox(width: 9),
                    const Expanded(
                      child:Text( 'ملاحظات لتحسين اداءك',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF006B63),
                      ),
                    ),
                    ),
                    
                    ],),
        

                    const SizedBox(height: 20),

                    _feedbackCard(
                      'نقطة قوة',
                      strengthText,
                      true,
                    ),

                    const SizedBox(height: 12),

                    _feedbackCard(
                      'نقطة للتحسين',
                      improvementText,
                      false,
                    ),
                  ],
                ),
              ),


            ],
          ),
        ),
      ),
    
    );

      return widget.embedded
      ? report
      : Scaffold(
          backgroundColor: const Color(0xFFFCFAF6),
          body: report,
        );

  }







  Widget _scoreBar(String title , double score){
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title , style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600 , color: Color(0xFF203E3A)),),
              
              Text('${score.toStringAsFixed(0)}/100' , style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold , color: Color(0xFF537F77)),),
            ],),

            const SizedBox(height: 10,),

            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: (score/100).clamp(0.0 , 1.0),
                minHeight: 9,
                backgroundColor: const Color(0xFFEAEFEA),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF578B80)),
              ),
            ),

        ],
      ),

    
    );
  }



Widget _feedbackCard(
  String title,
  String description,
  bool isStrength,
) {
  final Color accentColor = isStrength
      ? const Color(0xFF087F73)
      : const Color(0xFFB38B57);

  final Color backgroundColor = isStrength
      ? const Color(0xFFF3F8F6)
      : const Color(0xFFFAF7F0);

  final Color borderColor = isStrength
      ? const Color(0xFFE1E9E5)
      : const Color(0xFFECE4D6);

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            isStrength
                ? Icons.check_circle_outline_rounded
                : Icons.lightbulb_outline_rounded,
            color: accentColor,
            size: 21,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF203E3A),
                ),
              ),

              const SizedBox(height: 6),

              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: Color(0xFF526F6A),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  Widget _metricCard(String title , double value , bool highlighted){
    return Container(
      height: 115,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: highlighted
        ? const Color(0xFFE8F1EF)
        : const Color(0xFFF7F5F1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

          Text(
            '${value.toStringAsFixed(0)}%', style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Color(0xFF203E3A),
            ),
          ),
          const SizedBox(height: 10,),
          Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Color(0xFF526F6A)),)

          
        ],
      ),

    
    );
  }


  

Widget _performanceMetricRow(
  String title,
  double score,
  IconData icon,
  Color color,
) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                icon,
                color: color,
                size: 21,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF203E3A),
                ),
              ),
            ),

            Text(
              '${score.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (score / 100).clamp(0.0, 1.0),
            minHeight: 7,
            backgroundColor: const Color(0xFFE8EEEB),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    ),
  );
}


  


Widget _metricRow(
  String title,
  double value,
  IconData icon,
  Color color,
) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                icon,
                color: color,
                size: 21,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF203E3A),
                ),
              ),
            ),

            Text(
              '${value.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (value / 100).clamp(0.0, 1.0),
            minHeight: 7,
            backgroundColor: const Color(0xFFE8EEEB),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    ),
  );
}

Widget _buildSpeechEvents(List<dynamic> events) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
    ),
    padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 20,
    ),
    decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
        color: TaleeqTheme.borderSubtle,
        ),
    boxShadow: TaleeqTheme.cardShadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Icon(
              Icons.record_voice_over_rounded,
              color: Color(0xFF006B63),
              size: 21,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'مواضع التأتأة',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF006B63),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        if (events.isEmpty)
          const Text(
            'لم يتم رصد مواضع تأتأة في هذه المحاولة.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF667A75),
            ),
          )
        else
          ...events.map((event) {
            if (event is! Map) {
              return const SizedBox.shrink();
            }

            final data = Map<String, dynamic>.from(event);
            final type =
                (data['event_type'] ?? '').toString().toLowerCase();
            final word =
                (data['word_or_sound'] ?? '').toString();

            String label;
            IconData eventIcon;

            if (type == 'repetition') {
              label = 'التكرار';
              eventIcon = Icons.repeat_rounded;
            } else if (type == 'prolongation') {
              label = 'الإطالة';
              eventIcon = Icons.graphic_eq_rounded;
            } else if (type == 'block') {
              label = 'التوقف';
              eventIcon = Icons.pause_circle_outline_rounded;
            } else {
              label = 'موضع تأتأة';
              eventIcon = Icons.record_voice_over_rounded;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F8F6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE1E9E5),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8EAE5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      eventIcon,
                      color: const Color(0xFF006B63),
                      size: 22,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF006B63),
                          ),
                        ),
                        if (word.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            word,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF203E3A),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    ),
  );
}





}