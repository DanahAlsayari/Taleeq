
import 'package:flutter/material.dart';

class SharedGameRecordingLayout extends StatelessWidget {
  const SharedGameRecordingLayout({
    super.key,
    required this.intro,
    required this.gameCard,
    required this.remainingSeconds,
    required this.durationSeconds,
    required this.isRecording,
    required this.isAnalyzing,
    required this.onStart,
    required this.onStop,
    required this.onNewChallenge,
    this.errorWidget,
    this.analyzingMessage = 'جاري تحليل التسجيل...',
  });

  final Widget intro;
  final Widget gameCard;
  final int remainingSeconds;
  final int durationSeconds;
  final bool isRecording;
  final bool isAnalyzing;

  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onNewChallenge;

  final Widget? errorWidget;
  final String analyzingMessage;

  static const Color teal = Color(0xFF1F5F5A);
  static const Color mint = Color(0xFF6FA7A3);
  static const Color coral = Color(0xFFD97757);

  @override
  Widget build(BuildContext context) {
    final safeDuration = durationSeconds > 0 ? durationSeconds : 1;

    final progress = (remainingSeconds / safeDuration)
        .clamp(0.0, 1.0)
        .toDouble();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          intro,
          const SizedBox(height: 24),

          // كارد اللعبة؛ يختلف حسب اللعبة.
          gameCard,

          // العداد المشترك.
          if (isRecording || isAnalyzing) ...[
            const SizedBox(height: 20),
            _buildTimerCard(progress),
          ],

          if (errorWidget != null) ...[
            const SizedBox(height: 16),
            errorWidget!,
          ],

          const SizedBox(height: 20),

          // أزرار التسجيل المشتركة.
          if (isAnalyzing)
            _buildAnalyzingState()
          else if (isRecording)
            _buildStopButton()
          else
            _buildIdleButtons(),
        ],
      ),
    );
  }

  Widget _buildTimerCard(double progress) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 124,
            height: 124,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 9,
                    backgroundColor: const Color(0xFFE8EEEC),
                    color: remainingSeconds <= 5 ? coral : mint,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$remainingSeconds',
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        color: teal,
                      ),
                    ),
                    const Text(
                      'ثانية',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isRecording
                    ? Icons.mic_rounded
                    : Icons.check_rounded,
                color: isRecording ? coral : mint,
              ),
              const SizedBox(width: 8),
              Text(
                isRecording
                    ? 'جاري التسجيل...'
                    : 'تم إسال التسجيل'
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzingState() {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
        
         
          Text(
            analyzingMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'قد يستغرق التحليل بعض الوقت.',
            textAlign: TextAlign.center,
          ),  const SizedBox(height: 14), const CircularProgressIndicator(color: teal),
        ],
      ),
    );
  }

  Widget _buildStopButton() {
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onStop,
        icon: const Icon(Icons.stop_circle_outlined),
        label: const Text('إنهاء التسجيل'),
        style: ElevatedButton.styleFrom(
          backgroundColor: teal,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  Widget _buildIdleButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [

Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    GestureDetector(
      onTap: onStart,
      child: Container(
        width: 140,
        height: 140,
        decoration: const BoxDecoration(
          color: Color(0xFFEAF4F2),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              color: Color(0xFF6FA7A3),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mic,
              color: Colors.white,
              size: 38,
            ),
          ),
        ),
      ),
    ),
    const SizedBox(height: 12),
    const Text(
      'اضغط لبدء التحدي',
      style: TextStyle(
        color: teal,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    ),
  ],
)
,
        const SizedBox(height: 50),
       

Center(
  child: SizedBox(
    width: 220,
    height: 48,
    child: OutlinedButton(
      onPressed: onNewChallenge,
      style: OutlinedButton.styleFrom(
        foregroundColor: teal,
        backgroundColor: Colors.transparent,
        side: const BorderSide(
          color: Color(0xFF6FA7A3),
          width: 1.2,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        textDirection: TextDirection.ltr,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            size: 21,
          ),
          const SizedBox(width: 8),
          const Text(
            'تحدٍ جديد',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  ),
)



      ],
    );
  }
}
