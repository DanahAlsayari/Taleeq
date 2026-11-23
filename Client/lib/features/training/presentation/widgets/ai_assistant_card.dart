import 'package:flutter/material.dart';

import '../theme/training_theme.dart';

class AiAssistantCard extends StatelessWidget {
  const AiAssistantCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: TrainingColors.mint,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF20B7A6), Color(0xFF078D80)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  'مساعد طليق ✨',
                  style: TrainingText.categoryTitle.copyWith(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'تواجه صعوبة في اختيار التمرين المناسب؟',
                style: TrainingText.exerciseTitle.copyWith(
                  color: TrainingColors.primaryDark,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 8),

              Padding(
                padding: const EdgeInsets.only(right: 95),
                child: Text(
                  'تحدث مع مساعد طليق وأخبره بما ترغب في تحسينه، ليقترح لك تمرينًا يناسب احتياجاتك.',
                  style: TrainingText.body,
                  softWrap: true,
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TrainingColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('ابدأ المحادثة', style: TrainingText.startButton),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),

          Positioned(
            right: -10,
            bottom: 35,
            child: IgnorePointer(child: _buildChatIllustration()),
          ),
        ],
      ),
    );
  }

  Widget _buildChatIllustration() {
    return Image.asset(
      'assets/images/ai_chat_bubbles.png',
      width: 110,
      height: 95,
      fit: BoxFit.contain,
    );
  }
}
