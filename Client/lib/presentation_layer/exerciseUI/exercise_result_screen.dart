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
    try {
      final data = await ExerciseApiService().getAllAttempts();

      final exerciseTypes = data
          .map((attempt) => attempt['exercise_type']?.toString())
          .whereType<String>()
          .toSet();

      debugPrint('EXERCISE TYPES: $exerciseTypes');
      if (data.isNotEmpty) {
  debugPrint('ATTEMPT COMPARISON: ${data.first['comparison']}');
}


      if (!mounted) return;

      setState(() {
        attempts = data;
      });
    } catch (e) {
      debugPrint('خطأ في جلب المحاولات: $e');
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
      color: const Color(0xFFE9E0D2),
    ),
  ),
  child: DropdownButtonHideUnderline(
    child: DropdownButton<String>(
      value: _selectedExerciseFilter,
      isExpanded: true,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: Color(0xFF578B80),
      ),
      style: const TextStyle(
        color: Color(0xFF203E3A),
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
        'محاكاة موقف',
      ].map((filter) {
        return DropdownMenuItem<String>(
          value: filter,
          child: Text(filter),
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
      color: const Color(0xFFE9E0D2),
    ),
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
                  : '${latestScore.toStringAsFixed(1)}/100',
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
                  : '${bestScore.toStringAsFixed(1)}/100',
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
        color: const Color(0xFFE9E0D2),
      ),
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
          ? '${score.toStringAsFixed(1)}/100'
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
    final repetition = (metrics['stuttering_percent'] as num).toDouble();
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
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 255, 255, 255),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFFE9E0D2)
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.04),
                          blurRadius: 5,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                 

                    child: Column(
                    children: [


                      Align(
                        alignment: Alignment.centerRight,
                      child:Column (
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [ 
                      
                      Text(
                        exerciseTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF203E3A),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
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
                            color: Color(0xFF806B49),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    ])),

                      const SizedBox(height: 24),
                      const Text(
                        'درجتك الإجمالية',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF203E3A),
                        ),
                      ),

                            const SizedBox(height: 12),

                      
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(bottom: 6),
                                child: Text(
                                  ' 100/',
                                  style: TextStyle(
                                    fontSize: 22,
                                    color: Color(0xFF7A8E8B),
                                  ),
                                ),
                              ),
                              Text(
                                totalScore.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 60,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                  color: Color(0xFF203E3A),
                                ),
                              ),
                              
                            ],
                          ),
                          

                      const SizedBox(height: 24,),

                      const Divider(
                        color: Color(0xFFE9E0D2),
                        thickness: 1,
                      ),

                      const SizedBox(height: 20,),

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
                        'مقاييس الأداء',
                        style: TextStyle(
                          fontSize: 19,
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
                              'الطلاقة: مدى سلاسة الكلام واستمراره.\n\n'
                              'الإيقاع: مدى انتظام توقيت الكلام والوقفات.\n\n'
                              'التحكم بالسرعة: مدى مناسبة سرعة الكلام.\n\n'
                              'الالتزام بالمهمة: مدى ارتباط الكلام بالمطلوب في التمرين.\n\n'
                              'كلما ارتفعت الدرجة، كان الأداء أفضل.',
                              textDirection: TextDirection.rtl,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('فهمت'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),

                    ,const SizedBox(height: 20,),
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
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 255, 255, 255),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFFE9E0D2)
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.04),
                          blurRadius: 5,
                          offset: const Offset(0, 6),
                        ),
                      ],
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
                          fontSize: 19,
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
                              'نسبة التأتأة الكلية: تقدير لمقدار الكلام المتأثر بالتأتأة.\n\n'
                              'التكرار: إعادة صوت أو مقطع أو كلمة.\n\n'
                              'الإطالة: مدّ الصوت أكثر من المعتاد.\n\n'
                              'التوقف: تعثّر في خروج الكلام.',
                              textDirection: TextDirection.rtl,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('فهمت'),
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
                        fontSize: 26,
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
                const Divider(color: Color(0xFFE9E0D2)),
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
              ],)

              ),


              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFE9E0D2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ملاحظات لتحسين أدائك',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF203E3A),
                      ),
                    ),

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
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: isStrength
          ? const Color(0xFFE8F1EF)
          : const Color(0xFFF7F1E7),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isStrength
              ? Icons.check_circle_outline
              : Icons.lightbulb_outline,
          color: isStrength
              ? const Color(0xFF578B80)
              : const Color(0xFFAD8B58),
          size: 24,
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF203E3A),
                ),
              ),

              const SizedBox(height: 8),

              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.7,
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
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: color,
                size: 25,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF203E3A),
                ),
              ),
            ),
            Text(
              '${score.toStringAsFixed(0)}/100',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            value: (score / 100).clamp(0.0, 1.0),
            minHeight: 10,
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
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: color,
                size: 25,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF203E3A),
                ),
              ),
            ),
            Text(
              '${value.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            value: (value / 100).clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: const Color(0xFFE8EEEB),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    ),
  );
}






}