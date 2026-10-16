import 'package:client/presentation_layer/error_snackbar.dart';
import 'package:client/services/recording_service.dart';
import 'package:flutter/material.dart';
import 'package:client/models/technique_model.dart';
import 'package:just_audio/just_audio.dart';

import 'package:client/presentation_layer/widgets/audio_waveform.dart';

import 'package:client/presentation_layer/exerciseUI/exercise_result_screen.dart' ;
import '../../services/exercise_api_service.dart';


class ExerciseScreen extends StatefulWidget {
  final TechniqueModel? technique;
  final Map<String, dynamic> exercise;

  const ExerciseScreen({super.key,
  this.technique, 
   required this.exercise ,});
   


  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  

  bool isRecording = false; // Replace with your actual recording state
  bool _isSubmitting = false;
  bool isPlaying = false;
  bool isStoppingRecording = false;

  String? recordingPath;

  int recordingSeconds = 0;
  final List<double> amplitudes = [];

  final recordingService = RecordingService();
  late final AudioPlayer player = recordingService.player;

  Duration playbackPosition = Duration.zero;
  String? loadedAudioPath;
  bool hasStartedPlaying = false;
  int savedRecordingSeconds = 0;

@override
  void initState() {
    super.initState();

    player.positionStream.listen((position) {
      if (!mounted) return;

      setState(() {
        playbackPosition = position;
      });
    });

    player.playerStateStream.listen((position) {
      if (!mounted) return;

      
      if (position.processingState == ProcessingState.completed) {
        setState(() {
          isPlaying = false;
          playbackPosition = Duration.zero;
        });
      }
    });
   
  }



  

  Map<String, dynamic> get exerciseData => widget.exercise;


   
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

   String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }


  void stopRecordingTimer() {
    recordingService.stopRecordingTimer();
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
          recordingPath = path;
        }
      });

    } finally {
      isStoppingRecording = false;
    }
  }



 Future<void> _submitExercise() async {
  if (isRecording) {
    ErrorSnackBar.show(context, 'أوقفي التسجيل أولًا قبل الإرسال');
    return;
  }

  if (recordingPath == null) {
    ErrorSnackBar.show(context, 'سجّلي إجابتك أولًا');
    return;
  }

  setState(() {
    _isSubmitting = true;
  });

  try {
    final result = await ExerciseApiService().analyzeExerciseAudio(
      exerciseId: widget.exercise['id'].toString(),
      recordingPath: recordingPath!,
    );

    if (!mounted) return;

    debugPrint('Exercise analysis result: $result');

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ExerciseResultScreen(result: result, exercise: widget.exercise))
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تحليل التمرين بنجاح')),
    );
  } catch (e) {
    if (!mounted) return;

    debugPrint('Exercise analysis error: $e');

    ErrorSnackBar.show(context, 'تعذر تحليل التسجيل، حاولي مرة ثانية');
  } finally {
    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });
    }
  }
}


  @override
  Widget build(BuildContext context) {
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
                  SizedBox(
                    height: 58.0,
                    width: double.infinity,
                  child: Stack(
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () async {
                            if (isRecording) {
                              ErrorSnackBar.show(
                                context,
                                "أوقف التسجيل أولًا قبل الرجوع",
                              );
                              return;
                            } }
                        )
                      ),
                      Align(
                        
                        alignment: AlignmentDirectional.center,
                        child: Text(
                          'تمرين',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F5F5A),
                            
                          ),
                        ),
                      ),
                    
                    ]
                  )
                  ),
                  
              
                 const SizedBox(height: 20.0),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                  child:
                  Wrap(
                    alignment: WrapAlignment.start,
                    textDirection: TextDirection.rtl,
                    spacing: 1.0,
                    runSpacing: 8.0,

                    children: [
                      
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14.0 , vertical: 6.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCFE4E1),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          
                            child: Text(
                              exerciseData['title'],
                                style: const TextStyle(
                                color: Color(0xFF1F5F5A),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                      Container(
                         padding: const EdgeInsets.symmetric(horizontal: 14.0 , vertical: 6.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF4F2),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        
                          child: Text(
                            exerciseData['difficulty'],
                            style: const TextStyle(
                              color: Color(0xFF6FA7A3),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                      ),
                      
                  
                
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14.0 , vertical: 6.0),
                        height: 30,
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 255, 255, 255),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFCFE4E1), width: 1.25),
                        ),
                                                  child: Text(
                          widget.technique?.nameAr ?? 'بدون تقنية',
                            style: const TextStyle(
                              color: Color(0xFF1F5F5A),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                    ]
                  ),
                  ),
                  
                  
                      const SizedBox(height: 20.0),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      exerciseData['instructions'],
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
                      child: exerciseData['type'] == 'Reading'
                          ? Text(
                              exerciseData['content']['text'],
                              style: const TextStyle(
                                color: Color(0xFF2E3A38),
                                fontWeight: FontWeight.normal,
                                fontSize: 16,
                                height: 1.8,
                              ),
                            )
                          : exerciseData['type'] == 'Picture Description'
                          ? Image.network(
                              exerciseData['content']['image_url'],
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : exerciseData['type'] == 'Question & Answer'
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
                                      exerciseData['content']['question'],
                                      style: TextStyle(
                                        color: Color(0xFF1F5F5A),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                                
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),

                  const SizedBox(height: 20.0),

                  if (!isRecording && recordingPath == null)

                Column(
                    children: [                
                  GestureDetector(
                    onTap:() async {
                      if (await recordingService.startRecording('exercise_recording')) {
                         setState(() {
                                    amplitudes.clear();
                                    recordingSeconds = 0;
                                    isRecording = true;
                                  });

                                  startAmplitudeTimer();
                                  startRecordingTimer();
                                }
                              },
                    child : Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color:  Color(0xFFEAF4F2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
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
                      if (recordingPath != null &&
                          !isRecording)
                        Column(
                          children: [
                            AudioWaveform(
                              amplitudes:
                                  amplitudes
                                  ,
                              progress: hasStartedPlaying && savedRecordingSeconds > 0
                                  ? (playbackPosition.inMilliseconds /
                                            (savedRecordingSeconds * 1000))
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

                                        if (recordingPath != null) 
                                            {
                                          final currentPath =
                                              recordingPath!;

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
                                            : savedRecordingSeconds,
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
                                      "exercise_recording",
                                    )) {
                                      setState(() {
                                        recordingPath = null;
                                        savedRecordingSeconds = 0;
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
                    













//////////////////////////////////////////
///         Add your recording controls and other UI elements hereconst SizedBox(height: 16.0),

                  // Recording Ui
                  



                  /////////////////////////////////
                  
                ]
              ),
            ),
           


    )
        )
      ),
/*

bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 24.0),
        child: SizedBox(
          height: 56.0,
          child: ElevatedButton(
            onPressed: () _isSubmitting ? null :() async {
              if (isRecording) {
                ErrorSnackBar.show(
                  context,
                      ? "أوقف التسجيل أولًا قبل إرسال التقييم"
                );
                return;
              }

              if (recordingPath == null) {
                ErrorSnackBar.show(context, "سجل إجابتك أولًا");
                return;
              }

              final duration = [currentQuestionIndex] ?? 0;

              if (!recordingService.isRecordingDurationValid(duration)) {
                ErrorSnackBar.show(
                  context,
                  "مدة التسجيل لازم تكون 15 ثانية على الأقل، أعيد التسجيل",
                );
                return;
              }
              try {
                if (currentQuestionIndex < questions.length - 1) {
                  print('1. بدأ التحقق من التسجيل');

                  await recordingService.stopAudio();
                  await player.seek(Duration.zero);

                  print('2. إرسال التسجيل للتحقق');

                  await _assessmentApiService.validateAssessmentAudio(
                    assessmentId: _assessmentId!,
                    recordingPath: path,
                  );

                  print('3. التسجيل اجتاز التحقق');

                  if (!mounted) return;

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
*/

bottomNavigationBar: Padding(
  padding: const EdgeInsets.all(24),
  child: ElevatedButton(
    onPressed: _isSubmitting ? null : _submitExercise,
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF6FA7A3),
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 56),
    ),
    child: Text(_isSubmitting ? 'جاري التحليل...' : 'إرسال التسجيل'),
  ),
),



    );
  }
}