
import 'dart:convert';

import 'package:client/features/training/presentation/theme/training_theme.dart';
import 'package:client/presentation_layer/trainingUI/exercise_prep_screen_prepared.dart';
import 'package:flutter/material.dart';
import 'package:client/models/scenario_model.dart';
import 'package:client/presentation_layer/trainingUI/scenario_screen.dart';
class ScenarioInstructionsScreen extends StatelessWidget {
  const ScenarioInstructionsScreen({
    super.key,
    required this.attemptId,
    required this.scenario,
  });

  final String attemptId;
  final ScenarioModel scenario;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
    child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: TaleeqColors.background,
          appBar: AppBar(
            backgroundColor: TaleeqColors.background,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            title: const Text(
              'الاستعداد للتمرين',
              style: TextStyle(
                color: TaleeqColors.primary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            leading: IconButton(
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(
                Icons.arrow_back,
                size: 24,
                color: Color(0xFF555555),
              ),
            ),
          ),


    
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

        
        children: [
          CardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: TaleeqColors.soft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  switch (scenario.name) {
                    'طلب قهوة' => Icons.local_cafe_rounded,
                    'مقابلة عمل' => Icons.work_outline_rounded,
                    'مكالمة جوال' => Icons.phone_in_talk_rounded,
                    _ => Icons.menu_book_rounded,
                  },
                  color: TaleeqColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "تمرين على موقف واقعي",
                      style: const TextStyle(
                        color: TaleeqColors.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'عنوان الموقف',
            style: TextStyle(
              fontSize: 13,
              color: TaleeqColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          // Scenario title from the database
          Text(
            '\t ${scenario.name}',
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: TaleeqColors.primary,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            scenario.description,
            style: const TextStyle(
              fontSize: 15,
              height: 1.7,
              color: TaleeqColors.text,
            ),
          ),

          if (scenario.instructions.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: TaleeqColors.border),
            const SizedBox(height: 10),
            for (final instruction
                in (jsonDecode(scenario.instructions) as List<dynamic>).cast<String>())              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: TaleeqColors.medium,
                      size: 19,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        instruction,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: TaleeqColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    ),
    SizedBox(height: 20),
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TaleeqColors.medium.withValues(alpha: 0.19),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: TaleeqColors.medium.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: TaleeqColors.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child:Row(
                  children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: TaleeqColors.soft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.lightbulb_outline_rounded,
                  color: TaleeqColors.medium,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "طبّق ماتعلمته",
                      style: const TextStyle(
                        color: TaleeqColors.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                      
                    ),

                     Text("حاول دمج جميع التقنيات التي تعلمتها وتطبيقها معًا أثناء المحادثة، لتساعدك على التحدث بسلاسة وراحة أكبر.",
                      style: const TextStyle(
                        color: TaleeqColors.primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                     ),


                  ],
                ),
              ),
            ],
          ),
     
    )

        ]

        
      ),
      
        ),
      ),
      bottomNavigationBar: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: const BoxDecoration(
              color: TaleeqColors.background,
              border: Border(top: BorderSide(color: TaleeqColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 58,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ScenarioScreen(
                          attemptId: attemptId,
                          scenario: scenario,
                        ),
                      ),
                    );
                  },
                  label: const Text('ابدأ التمرين' , style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),),
                
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TrainingColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                
                ),
              ),
            ),
          ),
        ),
    ),
    ); 
    
  }
}


