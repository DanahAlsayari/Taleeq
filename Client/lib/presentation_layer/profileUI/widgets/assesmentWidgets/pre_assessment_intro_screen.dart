import 'package:flutter/material.dart';

import 'pre_assessment_questions_screen.dart';

class PreAssessmentIntroScreen extends StatelessWidget {
  const PreAssessmentIntroScreen({super.key, this.allowBack = true});

  final bool allowBack;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: allowBack,
      child: Scaffold(
        backgroundColor: const Color(0xFFFCFAF6),


      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 24.0),
        child :

                  // Start button
                  SizedBox(
                    width: double.infinity,
                    height: 56.0,
                    child: ElevatedButton(

                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const PreAssessmentQuestionsScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6FA7A3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18.0),
                     
                      
                      ),
                    ),
                    child: const Text(
                      "ابدأ التقييم المسبق",
                      style: TextStyle(fontSize: 16.0, color: Colors.white),
                    ),
                    ),
                  ),

      ),

        body: Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  
                    const SizedBox(height: 48.0),

                  const SizedBox(height: 60.0),

                  // Document icon
                  Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCFE4E1),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      size: 40.0,
                      color: Color.fromARGB(255, 81, 82, 82),
                    ),
                  ),

                  const SizedBox(height: 28.0),

                  // Step indicator
                  Container(
                    width: double.infinity,
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7EAD7),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        "الخطوة ١ من ٢ : التقييم المسبق",
                        style: TextStyle(
                          color: Color(0xFF6FA7A3),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 35.0),

                  // Title
                  const Text(
                    "دعنا نتعرف على تجربتك في الكلام",
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 24.0,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 1, 1, 1),
                    ),
                  ),

                  const Text(
                    "اجاباتك تساعد طليق على تخصيص التقييم و التدريب لك",
                    style: TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.normal,
                      color: Color.fromARGB(255, 138, 138, 138),
                    ),
                  ),

                  const SizedBox(height: 32.0),

                  // Information card
               
  
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20.0),
                    
                    child: 
                    
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoRow( text :"يستغرق حوالي ٣ دقائق" , icon: Icons.access_time_outlined),Divider(height: 32.0, thickness: 1, color: Color.fromARGB(255, 223, 223, 223)),
                        _InfoRow( text :"بضعة اسئلة قصيرة" , icon: Icons.question_answer_outlined), Divider(height: 32.0, thickness: 1, color: Color.fromARGB(255, 223, 223, 223)),
                        _InfoRow( text :"لا توجد اجابات صحيحة او خاطئة" , icon: Icons.waving_hand_outlined), Divider(height: 32.0, thickness: 1, color: Color.fromARGB(255, 223, 223, 223)),
                        _InfoRow( text :"سري تماما" , icon: Icons.lock_outlined),
                      ],
                    ),
                  ),

        


                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Reusable information row
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.text, required this.icon});

  final String text;

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 25.0,
          color: const Color.fromARGB(255, 114, 183, 168),
        ),
        const SizedBox(width: 12.0),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15.0,
            ),
          ),
        ),
      ],
    );
  }
}
