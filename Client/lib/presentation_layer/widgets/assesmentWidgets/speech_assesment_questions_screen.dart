import 'package:flutter/material.dart';

import '../../../services/assessment_api_service.dart';
import '../../fluencyUI/fluency_profile_screen.dart';
import 'speech_assesment_intro_screen.dart';

import 'dart:io';

import '../../../models/fluency_profile_data.dart';

import 'package:client/services/recording_service.dart';
import 'package:client/presentation_layer/error_snackbar.dart';

import "package:just_audio/just_audio.dart";
import 'package:client/presentation_layer/widgets/audio_waveform.dart';
import '../../widgets/journey_stepper.dart';
import 'dart:async';

class SpeechAssesmentQuestionsScreen extends StatefulWidget {
  const SpeechAssesmentQuestionsScreen({super.key});

  @override
  State<SpeechAssesmentQuestionsScreen> createState() =>
      _SpeechAssesmentQuestionsScreen();
}

class _SpeechAssesmentQuestionsScreen
    extends State<SpeechAssesmentQuestionsScreen> {
  AppLifecycleListener? lifecycleListener;
  int currentQuestionIndex = 0;

  final AssessmentApiService _assessmentApiService = AssessmentApiService();

  bool _isSubmitting = false;
  int? _assessmentId;

  @override
  void initState() {
    super.initState();
    lifecycleListener = AppLifecycleListener(
      onPause: () {
        if (isRecording && !isStoppingRecording) {
          finishRecording();
        }
      },
    );
    _createAssessment();
    _loadTasks();

    player.positionStream.listen((position) {
      if (!mounted) return;

      setState(() {
        playbackPosition = position;
      });
    });

    player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (!mounted) return;

        setState(() {
          isPlaying = false;
          playbackPosition = Duration.zero;
        });
      }
    });
  }

  Future<void> _createAssessment() async {
    try {
      final assessmentId = await _assessmentApiService.createAssessment();

      if (!mounted) return;

      setState(() {
        _assessmentId = assessmentId;
      });
    } catch (e) {
      if (!mounted) return;
      ErrorSnackBar.show(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _submitAssessment() async {
    if (_isSubmitting) return;

    if (_assessmentId == null) {
      throw Exception('لم يتم إنشاء التقييم.');
    }

    if (recordingPaths.length != questions.length) {
      throw Exception('يجب تسجيل جميع المهام قبل إرسال التقييم.');
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final analysisResponse = await _assessmentApiService
          .analyzeAssessmentAudio(
            assessmentId: _assessmentId!,
            recordingPaths: recordingPaths,
          );

      final result = Map<String, dynamic>.from(
        analysisResponse['result'] as Map,
      );

      result['overall_stuttering_percent'] = result['stuttering_percent'];

      final profileData = FluencyProfileData.fromJson(result);

      // Delete local recordings after successful analysis
      for (final path in recordingPaths.values) {
        final file = File(path);

        if (await file.exists()) {
          await file.delete();
        }
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => FluencyProfileScreen(profileData: profileData),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      ErrorSnackBar.show(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  final recordingService = RecordingService();
  late final AudioPlayer player = recordingService.player;

  bool isPlaying = false;
  Duration playbackPosition = Duration.zero;
  String? loadedAudioPath;
  bool hasStartedPlaying = false;

  bool isRecording = false;
  bool isStoppingRecording = false;

  final Map<int, String> recordingPaths = {};
  final Map<int, int> recordingDurations = {};
  final Map<int, List<double>> recordingAmplitudes = {};

  final List<double> amplitudes = [];

  int recordingSeconds = 0;

  // Questions list
  /*
  final List<Map<String, dynamic>> questions = [
    {
      'title': 'المهمة ١ من ٣',
      'category': 'القراءة',
      'instruction': 'اقرأ الفقرة بصوت عال بإيقاعك الطبيعي، خذ وقتك ولاتتسرع',
      'type': 'text',
      'content': 'يمكن للبيئة من حولنا أن تؤثر في تركيزنا أكثر مما نتوقع. فعندما يمتلئ المكان بالأشياء والمشتتات، يستقبل الدماغ معلومات بصرية أكثر ويحاول باستمرار تحديد ما يستحق الانتباه. لذلك، قد يساعد ترتيب مساحة العمل وتقليل العناصر غير الضرورية على تخفيف التشتت وتسهيل التركيز.',
    },
    {
      'title': 'المهمة ٢ من ٣',
      'category': 'وصف صورة',
      'instruction':
          'صف ماتراه في الصورة بكلماتك الخاصة، تحدث بشكل طبيعي ومريح',
      'type': 'image',
      'content': 'assets/images/Q2speechassesment.jpg',
    },
    {
      'title': 'المهمة ٣ من ٣',
      'category': 'الحديث الحر',
      'instruction':
          'تحدث عن نفسك ، خذ وقتك وتحدث بطريقتك الطبيعية بدون تحضير مسبق',
      'type': 'self',
      'content': 'this is the text"',
    },
  ];
*/
List<Map<String, dynamic>> questions = [];
  bool _isLoadingTasks = true;
  String? _tasksError;

  Future<void> _loadTasks() async {
    try {
      final tasks = await _assessmentApiService.getSpeechTasks();

      if (!mounted) return;

      setState(() {
        questions = tasks;
        _isLoadingTasks = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _tasksError = 'تعذر تحميل مهام التقييم';
        _isLoadingTasks = false;
      });
    }
  }

  void startAmplitudeTimer() {
    recordingService.startAmplitudeTimer((values) {
      if (!mounted || !isRecording) return;

      setState(() {
        amplitudes
          ..clear()
          ..addAll(values);
      });
    });
  }

  void stopAmplitudeTimer() {
    recordingService.stopAmplitudeTimer();
  }

  void startRecordingTimer() {
    recordingService.startRecordingTimer(
      (seconds) {
        if (!mounted) return;

        setState(() {
          recordingSeconds = seconds;
        });
      },
      () async {
        if (!mounted) return;
        await finishRecording();

        if (!mounted) return;

        ErrorSnackBar.show(
          context,
          "تم إيقاف التسجيل تلقائيًا لوصوله للحد الأقصى (5 دقائق)",
        );
      },
    );
  }

  void stopRecordingTimer() {
    recordingService.stopRecordingTimer();
  }

  String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> finishRecording() async {
    if (!isRecording || isStoppingRecording) return;

    isStoppingRecording = true;

    stopAmplitudeTimer();
    stopRecordingTimer();

    try {
      final path = await recordingService.stopRecording();

      if (!mounted) return;

      setState(() {
        isRecording = false;

        if (path != null) {
          recordingPaths[currentQuestionIndex] = path;
          recordingDurations[currentQuestionIndex] = recordingSeconds;
          recordingAmplitudes[currentQuestionIndex] = List<double>.from(
            amplitudes,
          );
        }
      });
    } finally {
      isStoppingRecording = false;
    }
  }

  @override
  Widget build(BuildContext context) {
        if (_isLoadingTasks) {
      return const Scaffold(
        backgroundColor: Color(0xFFFCFAF6),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6FA7A3)),
        ),
      );
    }

    if (_tasksError != null || questions.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFFCFAF6),
        body: Center(
          child: Text(
            _tasksError ?? 'لا توجد مهام متاحة',
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontSize: 16.0),
          ),
        ),
      );
    }

    final currentQuestion = questions[currentQuestionIndex];
    if (_isSubmitting) {
      return const Scaffold(
        backgroundColor: Color(0xFFFCFAF6),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF6FA7A3)),
              SizedBox(height: 16),
              Text(
                'نجهّز لك تحليل طلاقتك...',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E3A38),
                ),
              ),
              SizedBox(height: 6),
              Text(
                'لحظات ونعرِض لك النتائج',
                style: TextStyle(fontSize: 12, color: Color(0xFF8FA39F)),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Color(0xFFFCFAF6),
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
                          onPressed: () async {
                            if (isRecording) {
                              ErrorSnackBar.show(
                                context,
                                "أوقف التسجيل أولًا قبل الرجوع",
                              );
                              return;
                            }

                            if (currentQuestionIndex > 0) {
                              await recordingService.stopAudio();
                              await player.seek(Duration.zero);

                              setState(() {
                                currentQuestionIndex--;
                                isPlaying = false;
                                playbackPosition = Duration.zero;
                                loadedAudioPath = null;
                                hasStartedPlaying = false;
                              });
                            } else {
                              await recordingService.stopAudio();
                              await player.seek(Duration.zero);

                              if (!mounted) return;

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const SpeechAssesmentIntroScreen(),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.arrow_back),
                        ),
                        
                      ),
           
                      const SizedBox(width: 120.0),
                      Column(
                        children: [       
                              const SizedBox(height: 35.0),
                              // Journey stepper
                             const JourneyStepper(currentStep: 3),
                          
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
                    ],
                  ),
                  const SizedBox(height: 20.0),
                  Row(
                    children: [
                      
                        Container(
                         
                          padding: const EdgeInsets.symmetric(horizontal: 14.0 , vertical: 6.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCFE4E1),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Align(
                            alignment: AlignmentDirectional.center,
                            child: Text(
                              'المهمة ${currentQuestionIndex + 1} من ${questions.length}',                              style: const TextStyle(
                                color: Color(0xFF1F5F5A),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        
                      ),
                      const SizedBox(width: 6.0),
                      Container(
                        width: MediaQuery.of(context).size.width / 4,
                        height: 30,
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF4F2),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.center,
                          child: Text(
                            currentQuestion['category'],
                            style: const TextStyle(
                              color: Color(0xFF6FA7A3),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20.0),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      currentQuestion['instruction'],
                      style: const TextStyle(
                        color: Color.fromARGB(255, 8, 8, 8),
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  Container(
                    width: double.infinity,
                    height: 250,
                    padding: const EdgeInsets.all(20.0),
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7EAD7),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Color.fromARGB(255, 220, 197, 162),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Align(
                      child: currentQuestion['type'] == 'text'
                          ? Text(
                              currentQuestion['content'],
                              style: const TextStyle(
                                color: Color(0xFF2E3A38),
                                fontWeight: FontWeight.normal,
                                fontSize: 16,
                                height: 1.8,
                              ),
                            )
                          : currentQuestion['type'] == 'image'
                          ? Image.asset(
                              currentQuestion['content'],
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : currentQuestion['type'] == 'self'
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children:  [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline,
                                      color: Color(0xFF6FA7A3),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      "يمكنك التحدث عن: ",
                                      style: TextStyle(
                                        color: Color(0xFF1F5F5A),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 20),
                                  Text(currentQuestion['content'],
                                  style: TextStyle(
                                    color: Color(0xFF23E3A38),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                    height: 1.7,
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: 16.0),

                  // Recording Ui
                  Column(
                    children: [
                      if (!recordingPaths.containsKey(currentQuestionIndex) &&
                          !isRecording)
                        Column(
                          children: [
                            GestureDetector(
                              onTap: () async {
                                if (await recordingService.startRecording(
                                  "assesment_q${currentQuestionIndex + 1}",
                                )) {
                                  setState(() {
                                    amplitudes.clear();
                                    recordingSeconds = 0;
                                    isRecording = true;
                                  });

                                  startAmplitudeTimer();
                                  startRecordingTimer();
                                }
                              },
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
                            const SizedBox(height: 16.0),
                            const Text(
                              "اضغط للبدء في التسجيل",
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E3A38),
                              ),
                            ),
                            const SizedBox(height: 4.0),
                            
                          ],
                        ),

                      // during recording
                      if (isRecording)
                        Column(
                          children: [
                            Container(
                              width: 225,
                              height: 70,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFBE9E7),
                                borderRadius: BorderRadius.circular(35),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.circle,
                                    color: Color(0xFFE57373),
                                    size: 12,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    "التسجيل جار",
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2E3A38),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Text(
                                    formatTime(recordingSeconds),
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF2E3A38),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),
                            AudioWaveform(amplitudes: amplitudes),
                            const SizedBox(height: 24),

                            // stop recording
                            GestureDetector(
                              onTap: () async {
                                await finishRecording();
                              },
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF287D78),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.stop_rounded,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              "اضغط للإيقاف",
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 14,
                                color: Color(0xFF8FA39F),
                              ),
                            ),
                          ],
                        ),

                      // after recording Ui
                      if (recordingPaths.containsKey(currentQuestionIndex) &&
                          !isRecording)
                        Column(
                          children: [
                            AudioWaveform(
                              amplitudes:
                                  recordingAmplitudes[currentQuestionIndex] ??
                                  [],
                              progress: hasStartedPlaying
                                  ? (playbackPosition.inMilliseconds /
                                            ((recordingDurations[currentQuestionIndex] ??
                                                    1) *
                                                1000))
                                        .clamp(0.0, 1.0)
                                        .toDouble()
                                  : 0.0,
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    GestureDetector(
                                      // play record
                                      onTap: () async {
                                        if (isPlaying) {
                                          await recordingService.pauseAudio();

                                          setState(() {
                                            isPlaying = false;
                                          });

                                          return;
                                        }

                                        if (recordingPaths[currentQuestionIndex] !=
                                            null) {
                                          final currentPath =
                                              recordingPaths[currentQuestionIndex]!;

                                          if (loadedAudioPath != currentPath) {
                                            await recordingService.loadAudio(
                                              currentPath,
                                            );

                                            loadedAudioPath = currentPath;

                                            playbackPosition = Duration.zero;
                                          }

                                          if (player.processingState ==
                                              ProcessingState.completed) {
                                            await player.seek(Duration.zero);
                                          }

                                          setState(() {
                                            isPlaying = true;
                                            hasStartedPlaying = true;
                                          });

                                          await recordingService.resumeAudio();
                                        }
                                      },
                                      child: Container(
                                        width: 58,
                                        height: 58,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFD7EBE8),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isPlaying
                                              ? Icons.pause
                                              : Icons.play_arrow,
                                          color: const Color(0xFF287D78),
                                          size: 30,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      formatTime(
                                        hasStartedPlaying
                                            ? playbackPosition.inSeconds
                                            : recordingDurations[currentQuestionIndex] ??
                                                  0,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF8FA39F),
                                      ),
                                    ),
                                  ],
                                ),
                                GestureDetector(
                                  // re-record
                                  onTap: () async {
                                    await recordingService.stopAudio();
                                    await player.seek(Duration.zero);

                                    if (await recordingService.startRecording(
                                      "assesment_q${currentQuestionIndex + 1}",
                                    )) {
                                      setState(() {
                                        amplitudes.clear();

                                        recordingSeconds = 0;

                                        playbackPosition = Duration.zero;

                                        loadedAudioPath = null;

                                        hasStartedPlaying = false;

                                        isPlaying = false;
                                        isRecording = true;
                                      });

                                      startAmplitudeTimer();
                                      startRecordingTimer();
                                    }
                                  },
                                  child: Container(
                                    height: 54,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(
                                        color: const Color(0xFFD7EBE8),
                                      ),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(
                                          Icons.refresh,
                                          color: Color(0xFF6FA7A3),
                                          size: 22,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          "إعادة التسجيل",
                                          style: TextStyle(
                                            fontFamily: 'Tajawal',
                                            fontSize: 14,
                                            color: Color(0xFF6FA7A3),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
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
            onPressed: () async {
              if (isRecording) {
                ErrorSnackBar.show(
                  context,
                  currentQuestionIndex == questions.length - 1
                      ? "أوقف التسجيل أولًا قبل إرسال التقييم"
                      : "أوقف التسجيل أولًا قبل الانتقال للسؤال التالي",
                );
                return;
              }
              final path = recordingPaths[currentQuestionIndex];

              if (path == null) {
                ErrorSnackBar.show(context, "سجل إجابتك أولًا");
                return;
              }

              final duration = recordingDurations[currentQuestionIndex] ?? 0;

              if (!recordingService.isRecordingDurationValid(duration)) {
                ErrorSnackBar.show(
                  context,
                  "مدة التسجيل لازم تكون 15 ثانية على الأقل، أعيد التسجيل",
                );
                return;
              }
              try {
                if (_assessmentId == null) {
                  throw Exception('لم يتم إنشاء التقييم.');
                }

                if (currentQuestionIndex < questions.length - 1) {
                  await recordingService.stopAudio();
                  await player.seek(Duration.zero);

                  setState(() {
                    currentQuestionIndex++;
                    isPlaying = false;
                    playbackPosition = Duration.zero;
                    loadedAudioPath = null;
                    hasStartedPlaying = false;
                  });
                } else {
                  await recordingService.stopAudio();
                  await player.seek(Duration.zero);
                  await _submitAssessment();
                }
              } catch (e) {
                if (!mounted) return;

                ErrorSnackBar.show(
                  context,
                  e.toString().replaceFirst('Exception: ', ''),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6FA7A3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18.0),
              ),
            ),
            child: Text(
              currentQuestionIndex == questions.length - 1 ? "إرسال" : "التالي",
              style: const TextStyle(fontSize: 18.0, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    lifecycleListener?.dispose();

    recordingService.stopAmplitudeTimer();
    recordingService.stopRecordingTimer();
    recordingService.disposeRecord();

    super.dispose();
  }
}
