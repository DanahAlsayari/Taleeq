import 'package:flutter/material.dart';

import 'speech_assesment_intro_screen.dart';

import 'package:client/data_and_integration_layer/services/recording_service.dart';
import 'package:client/data_and_integration_layer/services/audio_storage_service.dart';

import "package:just_audio/just_audio.dart";
import 'package:client/presentation_layer/profileUI/widgets/audio_waveform.dart';

import 'dart:async';

class SpeechAssesmentQuestionsScreen extends StatefulWidget {
  const SpeechAssesmentQuestionsScreen({super.key});

  @override
  State<SpeechAssesmentQuestionsScreen> createState() =>
      _SpeechAssesmentQuestionsScreen();
}

class _SpeechAssesmentQuestionsScreen
    extends State<SpeechAssesmentQuestionsScreen> {
  int currentQuestionIndex = 0;

  final recordingService = RecordingService();
  final player = AudioPlayer();
  final storageService = StorageService();

  bool isRecording = false;

  //the answers are records not strings
  final Map<int, Set<String>> answers = {};

  final Map<int, String> recordingPaths = {};
  final Map<int, int> recordingDurations = {};
  final Map<int, List<double>> recordingAmplitudes = {};

  final List<double> amplitudes = [];
  Timer? amplitudeTimer;

  int recordingSeconds = 0;
  Timer? recordingTimer;

  // Questions list
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

  void startAmplitudeTimer() {
    amplitudeTimer = Timer.periodic(const Duration(milliseconds: 150), (
      timer,
    ) async {
      final amplitude = await recordingService.getAmplitude();

      if (!mounted || !isRecording) return;

      setState(() {
        amplitudes.add(amplitude.current);

        if (amplitudes.length > 35) {
          amplitudes.removeAt(0);
        }
      });
    });
  }

  void stopAmplitudeTimer() {
    amplitudeTimer?.cancel();
    amplitudeTimer = null;
  }

  void startRecordingTimer() {
    recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        recordingSeconds++;
      });
    });
  }

  void stopRecordingTimer() {
    recordingTimer?.cancel();
    recordingTimer = null;
  }

  String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final currentQuestion = questions[currentQuestionIndex];

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
                          onPressed: () {
                            if (isRecording) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "أوقف التسجيل أولًا قبل الرجوع",
                                  ),
                                ),
                              );
                              return;
                            }

                            if (currentQuestionIndex > 0) {
                              setState(() {
                                currentQuestionIndex--;
                              });
                            } else {
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
                          Text(
                            "${questions.length}/${currentQuestionIndex + 1}",
                            style: const TextStyle(
                              color: const Color(0xFF8FA39F),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Container(
                          width: MediaQuery.of(context).size.width / 4,
                          height: 30,
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCFE4E1),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Align(
                            alignment: AlignmentDirectional.center,
                            child: Text(
                              currentQuestion['title'],
                              style: const TextStyle(
                                color: const Color(0xFF1F5F5A),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
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
                              color: const Color(0xFF6FA7A3),
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
                        fontSize: 22,
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
                          offset: const Offset(
                            0,
                            1,
                          ), // changes position of shadow
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
                                fontSize: 18,
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

                              children: const [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline,
                                      color: Color(0xFF6FA7A3),
                                    ),
                                    SizedBox(width: 10),

                                    Text(
                                      "يمكنك التحدث عن: ",
                                      style: const TextStyle(
                                        color: Color(0xFF1F5F5A),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 20),
                                Text(
                                  "دراستك ، عملك ، هواياتك ، اهتماماتك، او اي شيء تود مشاركته",
                                  style: const TextStyle(
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
                  //Recording Ui
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
                                //outer circle
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF4F2),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Container(
                                    //inner circle
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6FA7A3),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
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

                            const Text(
                              "يبدأ التسجيل فقط عند ضغطك",
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 14,
                                color: Color(0xFF8FA39F),
                              ),
                            ),
                          ],
                        ),

                      //during recording
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
                                  Icon(
                                    Icons.circle,
                                    color: Color(0xFFE57373),
                                    size: 12,
                                  ),
                                  SizedBox(width: 8),

                                  Text(
                                    "التسجيل جار",
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2E3A38),
                                    ),
                                  ),
                                  SizedBox(width: 20),

                                  Text(
                                    formatTime(recordingSeconds),
                                    style: TextStyle(
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

                            //stop recording
                            GestureDetector(
                              onTap: () async {
                                final path = await recordingService
                                    .stopRecording();

                                stopAmplitudeTimer();
                                stopRecordingTimer();

                                setState(() {
                                  isRecording = false;

                                  if (path != null) {
                                    recordingPaths[currentQuestionIndex] = path;
                                    recordingDurations[currentQuestionIndex] =
                                        recordingSeconds;
                                    recordingAmplitudes[currentQuestionIndex] =
                                        List.from(amplitudes);
                                  }
                                });
                              },
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF287D78),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
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

                      //after recording Ui
                      if (recordingPaths.containsKey(currentQuestionIndex) &&
                          !isRecording)
                        Column(
                          children: [
                            AudioWaveform(
                              amplitudes:
                                  recordingAmplitudes[currentQuestionIndex] ??
                                  [],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    GestureDetector(
                                      //play record
                                      onTap: () async {
                                        if (recordingPaths[currentQuestionIndex] !=
                                            null) {
                                          await player.setFilePath(
                                            recordingPaths[currentQuestionIndex]!,
                                          );
                                          await player.play();
                                        }
                                      },
                                      child: Container(
                                        width: 58,
                                        height: 58,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFD7EBE8),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow,
                                          color: Color(0xFF287D78),
                                          size: 30,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 10),

                                    Text(
                                      formatTime(
                                        recordingDurations[currentQuestionIndex] ??
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
                                  //re-record
                                  onTap: () async {
                                    await player.stop();

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
                  ), //Record Ui
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
            onPressed: () async {
              final path = recordingPaths[currentQuestionIndex];
              if (path == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("سجل إجابتك أولًا")),
                );
                return;
              }
              try {
                await storageService.uploadAudio(
                  path,
                  "assesment_q${currentQuestionIndex + 1}.m4a",
                );

                if (currentQuestionIndex < questions.length - 1) {
                  setState(() {
                    currentQuestionIndex++;
                  });
                }
              } catch (e) {
                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("فشل رفع التسجيل، حاول مرة أخرى"),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6FA7A3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            child: Text(
              (currentQuestionIndex == questions.length - 1
                  ? "إرسال"
                  : "التالي"),
              style: TextStyle(fontSize: 16.0, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    amplitudeTimer?.cancel();
    recordingTimer?.cancel();
    player.dispose();
    recordingService.disposeRecord();
    super.dispose();
  }
}
