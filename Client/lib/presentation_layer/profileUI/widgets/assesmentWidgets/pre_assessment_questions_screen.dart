import 'package:flutter/material.dart';

import '../../../../data_and_integration_layer/services/pre_assessment_service.dart';
import 'pre_assessment_intro_screen.dart';
import 'pre_assesment_success_screen.dart';

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

  final PreAssessmentService _preAssessmentService =
      PreAssessmentService();

  List<Map<String, dynamic>> questions = [];

  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final loadedQuestions =
          await _preAssessmentService.getQuestions();

      if (!mounted) return;

      setState(() {
        questions = loadedQuestions;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'تعذر تحميل أسئلة التقييم';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFCFAF6),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF6FA7A3),
          ),
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
              style: const TextStyle(
                fontSize: 16.0,
              ),
            ),
          ),
        ),
      );
    }

    final currentQuestion = questions[currentQuestionIndex];

    final hasAnswer =
        answers[currentQuestionIndex]?.isNotEmpty ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFFCFAF6),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Align(
                        alignment:
                            AlignmentDirectional.centerStart,
                        child: IconButton(
                          onPressed: () {
                            if (currentQuestionIndex > 0) {
                              setState(() {
                                currentQuestionIndex--;
                              });
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const PreAssessmentIntroScreen(),
                                ),
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.arrow_back,
                          ),
                        ),
                      ),

                      const SizedBox(
                        width: 120.0,
                      ),

                      Column(
                        children: [
                          Text(
                            '${questions.length}/${currentQuestionIndex + 1}',
                            style: const TextStyle(
                              color: Color(0xFF8FA39F),
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(
                            height: 12.0,
                          ),

                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: List.generate(
                              questions.length,
                              (index) {
                                return Container(
                                  width: 20.0,
                                  height: 8.0,
                                  margin:
                                      const EdgeInsets.symmetric(
                                    horizontal: 4.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: index <=
                                            currentQuestionIndex
                                        ? const Color(
                                            0xFF6FA7A3,
                                          )
                                        : const Color(
                                            0xFFE0E0E0,
                                          ),
                                    borderRadius:
                                        BorderRadius.circular(
                                      4.0,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 20.0,
                  ),

                  Text(
                    currentQuestion['question'],
                    style: const TextStyle(
                      fontSize: 24.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 12.0,
                  ),

                  Text(
                    currentQuestion['subtitle'],
                    style: const TextStyle(
                      fontSize: 15.0,
                      fontWeight: FontWeight.normal,
                      color: Color.fromARGB(
                        255,
                        138,
                        138,
                        138,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 16.0,
                  ),

                  ...currentQuestion['options'].map<Widget>(
                    (option) {
                      final isSelected =
                          answers[currentQuestionIndex]
                                  ?.contains(option) ??
                              false;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (currentQuestion['multiple'] ==
                                true) {
                              answers.putIfAbsent(
                                currentQuestionIndex,
                                () => {},
                              );

                              if (isSelected) {
                                answers[currentQuestionIndex]
                                    ?.remove(option);
                              } else {
                                answers[currentQuestionIndex]
                                    ?.add(option);
                              }
                            } else {
                              answers[currentQuestionIndex] = {
                                option
                              };
                            }
                          });
                        },
                        child: Container(
                          width: double.infinity,
                          height: 60,
                          margin: const EdgeInsets.all(7.0),
                          padding: const EdgeInsets.all(13.0),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color.fromARGB(
                                    255,
                                    240,
                                    255,
                                    251,
                                  )
                                : const Color.fromARGB(
                                    255,
                                    255,
                                    255,
                                    255,
                                  ),
                            borderRadius:
                                BorderRadius.circular(8.0),
                            border: Border.all(
                              color: isSelected
                                  ? const Color.fromARGB(
                                      255,
                                      182,
                                      202,
                                      205,
                                    )
                                  : const Color.fromARGB(
                                      255,
                                      219,
                                      230,
                                      229,
                                    ),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              isSelected
                                  ? const Icon(
                                      Icons.check_circle,
                                      size: 20.0,
                                      color: Color(
                                        0xFF6FA7A3,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.circle_outlined,
                                      size: 20.0,
                                      color:
                                          Color.fromARGB(
                                        255,
                                        219,
                                        230,
                                        229,
                                      ),
                                    ),

                              const SizedBox(
                                width: 8.0,
                              ),

                              Expanded(
                                child: Text(
                                  option,
                                  style: const TextStyle(
                                    fontSize: 16.0,
                                    fontWeight:
                                        FontWeight.normal,
                                    color: Color.fromARGB(
                                      255,
                                      0,
                                      0,
                                      0,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ).toList(),
                ],
              ),
            ),
          ),
        ),
      ),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SizedBox(
          height: 60.0,
          child: ElevatedButton(
            onPressed: hasAnswer
                ? () {
                    if (currentQuestionIndex <
                        questions.length - 1) {
                      setState(() {
                        currentQuestionIndex++;
                      });
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const PreAssessmentSuccessScreen(),
                        ),
                      );

                      debugPrint(
                        'Answers: $answers',
                      );
                    }
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  const Color(0xFF6FA7A3),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(8.0),
              ),
            ),
            child: Text(
              currentQuestionIndex ==
                      questions.length - 1
                  ? 'إرسال'
                  : 'التالي',
              style: const TextStyle(
                fontSize: 16.0,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}