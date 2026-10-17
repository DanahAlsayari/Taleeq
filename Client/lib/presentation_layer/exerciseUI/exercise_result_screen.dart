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

  @override
  void initState() {
    super.initState();
    loadAttempts();
  }

  Future<void> loadAttempts() async {
    try {
      final data = await ExerciseApiService().getRecentAttempts();

      if (!mounted) return;

      setState(() {
        attempts = data;
      });
    } catch (e) {
      debugPrint('خطأ في جلب المحاولات: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
        if (attempts.isEmpty && widget.result == null) {
      return const Scaffold(
        body: Center(
          child: Text('ما عندك محاولات سابقة حتى الآن'),
        ),
      );
    }

    final result = attempts.isEmpty
        ? widget.result!
        : attempts[currentIndex];

    final exercise = widget.exercise ?? result;
    debugPrint('EXERCISE RESULT: $result');

    //prepare values
    final scores = Map<String , dynamic>.from(result['scores']);
    final totalScore = (scores['total_score']as num).toDouble();
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

    final performanceScores = <String, double>{
      'fluency': fluency,
      'rhythm': rhythm,
      'speed_control': speed,
      'task_adherence': adherence,
    };

    final strongest = performanceScores.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );

    final weakest = performanceScores.entries.reduce(
      (a, b) => a.value <= b.value ? a : b,
    );

    final strengthText = feedback[strongest.key]?.toString() ?? '';
    final improvementText = feedback[weakest.key]?.toString() ?? '';



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
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFE5EBE8),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: currentIndex > 0
                          ? () {
                              setState(() {
                                currentIndex--;
                              });
                            }
                          : null,
                    ),

                    Text(
                      attempts.isEmpty
                          ? 'نتيجة المحاولة الحالية'
                          : 'المحاولة ${currentIndex + 1} من اخر ${attempts.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF203E3A),
                      ),
                    ),

                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: currentIndex < attempts.length - 1
                          ? () {
                              setState(() {
                                currentIndex++;
                              });
                            }
                          : null,
                    ),
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
                      
                      const Text(
                        'نتيجة التمرين',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF7A8E8B),
                        ),
                      ),

                      const SizedBox(height: 10),

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
                        children: [
                          Text('100/',
                        style: TextStyle( color: Color.fromARGB(255, 100, 100, 100) , fontSize: 25),)
                        ,
                        Text(
                        '${totalScore.toStringAsFixed(1)}',
                        style: const TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF203E3A),
                          height: 1,
                        ),
                      ),

                      

                      
                      ],),

                      const SizedBox(height: 24,),

                      const Divider(
                        color: Color(0xFFE9E0D2),
                        thickness: 1,
                      ),

                      const SizedBox(height: 20,),

                      const Align(alignment: Alignment.centerRight,
                      child: Text('مقاييس الاداء' , style: TextStyle(fontSize: 19 , fontWeight: FontWeight.bold , color: Color(0xFF203E3A)),)

                      )

                    ,const SizedBox(height: 20,)
                    , _scoreBar('الطلاقة', fluency)
                    , _scoreBar('الإيقاع', rhythm)
                    , _scoreBar('التحكم بالسرعة', speed)
                    , _scoreBar('الالتزام بالمهمة', adherence)

                      
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

                       const Align(alignment: Alignment.centerRight,
                      child: Text('نسب التأتأة' , style: TextStyle(fontSize: 19 , fontWeight: FontWeight.bold , color: Color(0xFF203E3A)),)

                      ),

                      const SizedBox(height: 22,),

                      Row(
                        children: [
                        Expanded(child: _metricCard('التلعثم', stuttering, true)),

                        const SizedBox(width: 12,),
                        Expanded(child: _metricCard('التكرار', repetition, false)),
                      ],),

                      const SizedBox(height: 12,),

                      Row(children: [
                        Expanded(child: _metricCard('الإطالة', prolongation, false)),

                        const SizedBox(width: 12,),
                        Expanded(child: _metricCard('التوقفات الكلامية', blocks, true)),
                      ],)


                      
                    ])

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






}