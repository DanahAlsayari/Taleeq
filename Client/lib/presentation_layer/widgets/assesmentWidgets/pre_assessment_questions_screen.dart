import 'package:client/main.dart';
import 'package:client/theme/taleeq_theme.dart';
import 'package:flutter/material.dart';

import '../../../services/pre_assessment_service.dart';
import 'pre_assesment_success_screen.dart';
import '../../widgets/journey_stepper.dart';

class PreAssessmentQuestionsScreen extends StatefulWidget {
  const PreAssessmentQuestionsScreen({super.key});

  @override
  State<PreAssessmentQuestionsScreen> createState() =>
      _PreAssessmentQuestionsScreenState();
}

class _PreAssessmentQuestionsScreenState
    extends State<PreAssessmentQuestionsScreen> {
  int currentQuestionIndex = 0;

  final Map<int, Set<String>> answers = {};

  final PreAssessmentService _preAssessmentService = PreAssessmentService();

  List<Map<String, dynamic>> questions = [];

  bool isLoading = true;
  bool isSubmitting = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final loadedQuestions = await _preAssessmentService.getQuestions();

      if (!mounted) return;

      setState(() {
        questions = loadedQuestions;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'تعذر تحميل أسئلة التقييم';
        isLoading = false;
      });
    }
  }

  Future<void> _submitAnswers() async {
    setState(() {
      isSubmitting = true;
    });

    final submissionAnswers = List.generate(questions.length, (index) {
      return {
        'question_id': questions[index]['id'],
        'selected_options': answers[index]!.toList(),
      };
    });

    try {
      await _preAssessmentService.submitAnswers(submissionAnswers);

      if (!mounted) return;

      setState(() {
        isSubmitting = false;
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const PreAssessmentSuccessScreen(),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر إرسال التقييم، حاول مرة أخرى')),
      );
    }
  }

  void _exitAssessment() {
    if (isSubmitting) return;

    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFCFAF6),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6FA7A3)),
        ),
      );
    }

    if (errorMessage != null || questions.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFFCFAF6),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: Text(
              errorMessage ?? 'لا توجد أسئلة متاحة',
              style: const TextStyle(fontSize: 16.0),
            ),
          ),
        ),
      );
    }

    final currentQuestion = questions[currentQuestionIndex];

    final hasAnswer = answers[currentQuestionIndex]?.isNotEmpty ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFFCFAF6),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: IconButton(
                          onPressed: isSubmitting
                              ? null
                              : () {
                                  if (currentQuestionIndex > 0) {
                                    setState(() {
                                      currentQuestionIndex--;
                                    });
                                  } else {
                                    Navigator.pop(context);
                                  }
                                },
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Color(0xFF526B68),
                            size: 24,
                          ),
                        ),
                      ),

                      Column(
                        children: [
                          const SizedBox(height: 35.0),

                          JourneyStepper(currentStep: 2),

                          const SizedBox(height: 12.0),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(questions.length, (index) {
                              return Container(
                                width: 20.0,
                                height: 8.0,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4.0,
                                ),
                                decoration: BoxDecoration(
                                  color: index <= currentQuestionIndex
                                      ? const Color(0xFF6FA7A3)
                                      : const Color(0xFFE0E0E0),
                                  borderRadius: BorderRadius.circular(4.0),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                      Align(
                        alignment: AlignmentDirectional.topEnd,
                        child: IconButton(
                          tooltip: 'العودة إلى الرئيسية',
                          onPressed: isSubmitting ? null : _exitAssessment,
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFF526B68),
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20.0),
                  Text(
                    currentQuestion['question'],
                    style: const TextStyle(
                      fontSize: 24.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  Text(
                    currentQuestion['subtitle'],
                    style: const TextStyle(
                      fontSize: 15.0,
                      fontWeight: FontWeight.normal,
                      color: Color.fromARGB(255, 138, 138, 138),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  ...currentQuestion['options'].map<Widget>((option) {
                    final isSelected =
                        answers[currentQuestionIndex]?.contains(option) ??
                        false;

                    return GestureDetector(
                      onTap: isSubmitting
                          ? null
                          : () {
                              setState(() {
                                if (currentQuestion['multiple'] == true) {
                                  answers.putIfAbsent(
                                    currentQuestionIndex,
                                    () => {},
                                  );

                                  if (isSelected) {
                                    answers[currentQuestionIndex]?.remove(
                                      option,
                                    );
                                  } else {
                                    answers[currentQuestionIndex]?.add(option);
                                  }
                                } else {
                                  answers[currentQuestionIndex] = {option};
                                }
                              });
                            },
                      child: Container(
                        width: double.infinity,
                        height: 60,
                        margin: const EdgeInsets.symmetric(vertical: 6.0),
                        padding: const EdgeInsets.all(13.0),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color.fromARGB(255, 240, 255, 251)
                              : const Color.fromARGB(255, 255, 255, 255),
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(
                            color: isSelected
                                ? const Color.fromARGB(255, 182, 202, 205)
                                : const Color.fromARGB(255, 219, 230, 229),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              currentQuestion['multiple'] == true
                                  ? (isSelected
                                        ? Icons.check_box
                                        : Icons.check_box_outline_blank)
                                  : (isSelected
                                        ? Icons.check_circle
                                        : Icons.circle_outlined),
                              size: 20.0,
                              color: isSelected
                                  ? const Color(0xFF6FA7A3)
                                  : const Color.fromARGB(255, 219, 230, 229),
                            ),
                            const SizedBox(width: 8.0),
                            Expanded(
                              child: Text(
                                option,
                                style: const TextStyle(
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.normal,
                                  color: Color.fromARGB(255, 0, 0, 0),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 24.0),
        child: SizedBox(
          height: 56.0,
          child: ElevatedButton(
            onPressed: hasAnswer && !isSubmitting
                ? () async {
                    if (currentQuestionIndex < questions.length - 1) {
                      setState(() {
                        currentQuestionIndex++;
                      });
                    } else {
                      await _submitAnswers();
                    }
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: TaleeqTheme.primaryTeal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18.0),
              ),
            ),
            child: isSubmitting
                ? const SizedBox(
                    width: 24.0,
                    height: 24.0,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    currentQuestionIndex == questions.length - 1
                        ? 'إرسال'
                        : 'التالي',
                    style: const TextStyle(fontSize: 16.0, color: Colors.white),
                  ),
          ),
        ),
      ),
    );
  }
}
