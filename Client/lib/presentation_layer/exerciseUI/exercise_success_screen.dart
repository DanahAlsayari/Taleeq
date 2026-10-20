import 'package:flutter/material.dart';
import 'package:client/features/training/presentation/training_screen.dart';

import 'package/../../widgets/main_navigation_screen.dart';


class ExerciseSuccessScreen extends StatelessWidget {
  final Map<String, dynamic> result;
  final Map<String, dynamic> exercise;

  const ExerciseSuccessScreen({
    super.key,
    required this.result,
    required this.exercise,
  });


  @override
  Widget build(BuildContext context) {


    final scores = Map<String, dynamic>.from(
      result['scores'] ?? {},
    );

    final feedback = Map<String, dynamic>.from(
      result['feedback'] ?? {},
    );

    final totalScore =
        (scores['total_score'] as num?)?.toDouble() ?? 0.0;

    final exerciseTitle =
        (exercise['title'] ?? 'التمرين').toString();

    final difficulty =
        (exercise['difficulty'] ?? '').toString().toLowerCase();

    final difficultyArabic = {
      'easy': 'سهل',
      'medium': 'متوسط',
      'hard': 'صعب',
    }[difficulty] ?? difficulty;

    final strengthText =
        (feedback['strength'] ?? '').toString();

    final improvementText =
        (feedback['improvement'] ?? '').toString();

    
    final metrics = Map<String, dynamic>.from(
      result['metrics'] ?? {},
    );

    final stuttering =
        (metrics['stuttering_percent'] as num?)?.toDouble() ?? 0.0;

    final repetition =
        (metrics['repetition_percent'] as num?)?.toDouble() ?? 0.0;

    final prolongation =
        (metrics['prolongation_percent'] as num?)?.toDouble() ?? 0.0;

    final blocks =
        (metrics['block_percent'] as num?)?.toDouble() ?? 0.0;

    
    final comparison = Map<String, dynamic>.from(
      result['comparison'] ?? {},
    );

    final previousScore =
        (comparison['previous_score'] as num?)?.toDouble();

    final scoreChange =
        (comparison['score_change'] as num?)?.toDouble();


        
    return Scaffold(
      backgroundColor: const Color(0xFFFCFAF6),
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 36),

                // Success icon
                Container(
                  width: 108,
                  height: 108,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD8EAE7),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: const BoxDecoration(
                        color: Color(0xFF287D78),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 46,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'أحسنت، أكملت التمرين',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF203E3A),
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  '$exerciseTitle · $difficultyArabic',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF7A8E8B),
                  ),
                ),

                const SizedBox(height: 20),


// Overall exercise result card
Container(
  width: double.infinity,
  padding: const EdgeInsets.all(24),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(
      color: const Color(0xFFE9E0D2),
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 12,
        offset: const Offset(0, 5),
      ),
    ],
  ),
  child: Column(
    children: [
      const Text(
        'درجتك الإجمالية',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Color(0xFF203E3A),
        ),
      ),

      const SizedBox(height: 16),

      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              ' 100 /',
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

      const SizedBox(height: 10),

      if (previousScore != null && scoreChange != null)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              scoreChange > 0
                  ? Icons.trending_up_rounded
                  : scoreChange < 0
                      ? Icons.trending_down_rounded
                      : Icons.trending_flat_rounded,
              color: scoreChange > 0
                  ? const Color(0xFF287D78)
                  : scoreChange < 0
                      ? const Color(0xFFC65A50)
                      : const Color(0xFF7A8E8B),
              size: 22,
            ),
            const SizedBox(width: 6),
            Text(
              '${scoreChange > 0 ? '+' : ''}${scoreChange.toStringAsFixed(1)}',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: scoreChange > 0
                    ? const Color(0xFF287D78)
                    : scoreChange < 0
                        ? const Color(0xFFC65A50)
                        : const Color(0xFF7A8E8B),
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'مقارنة بآخر محاولة مماثلة',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF7A8E8B),
              ),
            ),
          ],
        )
      else
        const Text(
          'أول محاولة لك في هذا النوع والمستوى',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF7A8E8B),
          ),
        ),

      const Divider(
        color: Color(0xFFE9E0D2),
      ),

      const SizedBox(height: 7),

      Align(
        alignment: Alignment.centerRight,
        child: Text(
          'نقطة قوة',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF203E3A),
          ),
        ),
      ),

      const SizedBox(height: 5),

      Align(
        alignment: Alignment.centerRight,
        child: Text(
          strengthText.isNotEmpty
              ? strengthText
              : 'استمري في التدريب لتحسين أدائك.',
          style: const TextStyle(
            fontSize: 12,
            height: 1.7,
            color: Color(0xFF526F6A),
          ),
        ),
      ),
      const SizedBox(height: 7),

      Align(
        alignment: Alignment.centerRight,
        child: Text(
          'نقطة للتحسين',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF203E3A),
          ),
        ),
      ),

      const SizedBox(height: 5),

      Align(
        alignment: Alignment.centerRight,
        child: Text(
          improvementText.isNotEmpty
              ? improvementText
              : 'استمري في التدريب لتحسين أدائك.',
          style: const TextStyle(
            fontSize: 12,
            height: 1.7,
            color: Color(0xFF526F6A),
          ),
        ),
      ),


    ],
  ),
),

const SizedBox(height: 24),

SizedBox(
  width: double.infinity,
  height: 56,
  child: ElevatedButton.icon(
    onPressed: () {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFFFCFAF6),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        
    builder: (context) {
      return FractionallySizedBox(
        heightFactor: 0.85,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD5DDDA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'تفاصيل الأداء',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF203E3A),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      


Container(
  width: double.infinity,
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(
      color: const Color(0xFFE9E0D2),
    ),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
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

      const SizedBox(height: 20),

      _performanceMetricRow(
        'الطلاقة',
        (scores['fluency_score'] as num?)?.toDouble() ?? 0,
        Icons.record_voice_over_rounded,
        const Color(0xFF006B63),
      ),

      _performanceMetricRow(
        'الإيقاع',
        (scores['rhythm_score'] as num?)?.toDouble() ?? 0,
        Icons.graphic_eq_rounded,
        const Color(0xFF5FAFA8),
      ),

      _performanceMetricRow(
        'التحكم بالسرعة',
        (scores['speed_control_score'] as num?)?.toDouble() ?? 0,
        Icons.speed_rounded,
        const Color(0xFF508B9B),
      ),

      _performanceMetricRow(
        'الالتزام بالمهمة',
        (scores['task_adherence_score'] as num?)?.toDouble() ?? 0,
        Icons.task_alt_rounded,
        const Color(0xFFB28B56),
      ),
    ],
  ),
),




const SizedBox(height: 10),

const Divider(color: Color(0xFFE9E0D2)),

const SizedBox(height: 10),



Container(
  width: double.infinity,
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: const Color(0xFFE9E0D2)),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
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
    ],
  ),
),
                    ],
                  ),
                ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
            ),
          );
        },
      );
    },
    icon: const Icon(Icons.bar_chart_rounded),
    label: const Text(
      'عرض تفاصيل الأداء',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    ),
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF287D78),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    ),
  ),
),

const SizedBox(height: 16),

SizedBox(
  width: double.infinity,
  height: 56,
  child: TextButton(
    
        onPressed: () {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const MainNavigationScreen(
            initialIndex: 1,
          ),
        ),
        (route) => false,
      );
    },
    
    child: const Text(
      'العودة للتمارين',
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
      ),
    ),
  ),
),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _performanceMetricRow(
     String title, double score, IconData icon, Color color, ) 
     {
      return Padding( 
        padding: const EdgeInsets.only(bottom: 24),
         child: Column(
           children: [
             Row( children: 
             [ Container(
               width: 46, 
               height: 46,
                decoration: BoxDecoration( color: color.withValues(alpha: 0.12),
                 borderRadius: BorderRadius.circular(14), ), 
                 child: Icon( icon, color: color, size: 25, ), ),
              const SizedBox(width: 12),
             Expanded( child: Text( title, style: const TextStyle( fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF203E3A), ), ), ), 
             Text( '${score.toStringAsFixed(0)}/100', style: TextStyle( fontSize: 16, fontWeight: FontWeight.w800, color: color, ), ), ], ), 
             
             const SizedBox(height: 14),
             
            ClipRRect( borderRadius: BorderRadius.circular(12), 
            child: LinearProgressIndicator( value: (score / 100).clamp(0.0, 1.0), minHeight: 10, backgroundColor: const Color(0xFFE8EEEB), valueColor: AlwaysStoppedAnimation<Color>(color),
             ), ), ], ), ); }

  

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
