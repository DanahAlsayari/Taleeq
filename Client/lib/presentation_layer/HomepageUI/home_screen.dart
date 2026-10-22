import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

import '../../services/assessment_api_service.dart';
import '../../services/profile_service.dart';
import '../widgets/assesmentWidgets/pre_assessment_intro_screen.dart';
import '../widgets/assesmentWidgets/speech_assesment_intro_screen.dart';
import '../../services/weekly_plan_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.isActive = true});

  final bool isActive;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  String _userName = '';
  final ProfileService _profileService = ProfileService();
  String? _profileError;
  final AssessmentApiService _assessmentService = AssessmentApiService();
  final WeeklyPlanService _weeklyPlanService = WeeklyPlanService();
  DateTime? _selectedPracticeDate;

  Map<String, dynamic>? _weeklyPlan;
  bool _isLoadingWeeklyPlan = true;
  String? _weeklyPlanError;
  String? _nextStep;
  bool _isLoadingAssessmentStatus = true;
  bool _isUpdatingCompletion = false;
  String? _assessmentStatusError;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProfile();
    _loadAssessmentStatus();
    _loadWeeklyPlan();
  }

  DateTime _riyadhToday() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 3));
    return DateTime.utc(now.year, now.month, now.day);
  }

  DateTime _parsePracticeDate(String value) {
    final date = DateTime.parse(value);
    return DateTime.utc(date.year, date.month, date.day);
  }

  String _arabicDate(DateTime date) {
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];

    return '${date.day} ${months[date.month - 1]}';
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _profileService.getProfile();

      if (!mounted) return;

      setState(() {
        _userName = profile['name'] as String;
        _profileError = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _profileError = 'تعذر تحميل بيانات الحساب';
      });
    }
  }

  Future<void> _loadAssessmentStatus() async {
    setState(() {
      _isLoadingAssessmentStatus = true;
      _assessmentStatusError = null;
    });

    try {
      final status = await _assessmentService.getOnboardingStatus();
      final nextStep = status['next_step'];

      if (nextStep != 'pre_assessment' &&
          nextStep != 'speech_assessment' &&
          nextStep != 'completed') {
        throw Exception('Unexpected assessment status');
      }

      if (!mounted) return;

      setState(() {
        _nextStep = nextStep as String;
        _isLoadingAssessmentStatus = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _assessmentStatusError = 'تعذر تحميل حالة التقييم';
        _isLoadingAssessmentStatus = false;
      });
    }
  }

  Future<void> _continueAssessment() async {
    final Widget screen;

    if (_nextStep == 'pre_assessment') {
      screen = const PreAssessmentIntroScreen();
    } else if (_nextStep == 'speech_assessment') {
      screen = const SpeechAssesmentIntroScreen();
    } else {
      return;
    }

    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));

    if (!mounted) return;

    await _loadAssessmentStatus();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isActive && !oldWidget.isActive) {
      _loadProfile();
      _loadAssessmentStatus();
      _loadWeeklyPlan();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.isActive) {
      _loadWeeklyPlan();
      _loadAssessmentStatus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadWeeklyPlan() async {
    setState(() {
      _isLoadingWeeklyPlan = true;
      _weeklyPlanError = null;
    });

    try {
      final plan = await _weeklyPlanService.getWeeklyPlan();

      if (!mounted) return;

      setState(() {
        _weeklyPlan = plan;
        _isLoadingWeeklyPlan = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _weeklyPlanError = 'تعذر تحميل الخطة الأسبوعية';
        _isLoadingWeeklyPlan = false;
      });
    }
  }

  Future<void> _editWeeklyPlan({
    List<Map<String, dynamic>>? initialSessions,
  }) async {
    final today = _riyadhToday();
    final weekStart = today.subtract(Duration(days: today.weekday % 7));

    String dateKey(DateTime date) {
      return date.toIso8601String().substring(0, 10);
    }

    final existingSessions =
        initialSessions ??
        ((_weeklyPlan?['sessions'] as List<dynamic>?) ?? [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();

    final durations = <String, int>{};
    final protectedDates = <String>{};

    for (final session in existingSessions) {
      final key = session['practice_date'] as String;
      durations[key] = session['duration_minutes'] as int;

      if (session['is_completed'] == true) {
        protectedDates.add(key);
      }
    }

    final formKey = GlobalKey<FormState>();
    bool saving = false;
    String? error;

    final savedPlan = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return PopScope(
              canPop: !saving,
              child: AlertDialog(
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                backgroundColor: const Color(0xFFFCFAF6),
                title: Text(
                  _weeklyPlan == null
                      ? 'خطّط لأسبوعك'
                      : 'تعديل الخطة الأسبوعية',
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'اختر أيام الممارسة والمدة المناسبة لك.'
                            '\nلتعديل جلسة مكتملة، ألغِ تحديد اكتمالها أولًا.',
                            style: TextStyle(height: 1.6),
                          ),
                          const SizedBox(height: 12),
                          ...List.generate(7, (index) {
                            const days = [
                              'الأحد',
                              'الإثنين',
                              'الثلاثاء',
                              'الأربعاء',
                              'الخميس',
                              'الجمعة',
                              'السبت',
                            ];

                            final date = weekStart.add(Duration(days: index));
                            final key = dateKey(date);
                            final selected = durations.containsKey(key);
                            final locked = protectedDates.contains(key);
                            final disabled = saving || locked;

                            return Container(
                              key: ValueKey('day-$key'),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Color(0xFFE5D8C8)),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Checkbox(
                                        value: selected,
                                        activeColor: const Color(0xFF398681),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        onChanged: disabled
                                            ? null
                                            : (value) {
                                                setDialogState(() {
                                                  error = null;

                                                  if (value == true) {
                                                    durations[key] = 15;
                                                  } else {
                                                    durations.remove(key);
                                                  }
                                                });
                                              },
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              days[index],
                                              style: const TextStyle(
                                                color: Color(0xFF2E3A38),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (locked)
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          child: Icon(
                                            Icons.lock_outline,
                                            size: 16,
                                            color: Color(0xFF526B68),
                                          ),
                                        ),
                                      if (selected)
                                        SizedBox(
                                          width: 92,
                                          child: TextFormField(
                                            key: ValueKey('duration-$key'),
                                            initialValue: '${durations[key]}',
                                            enabled: !disabled,
                                            keyboardType: TextInputType.number,
                                            textDirection: TextDirection.ltr,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Color(0xFF2E3A38),
                                              fontSize: 14,
                                            ),
                                            decoration: InputDecoration(
                                              isDense: true,
                                              suffixText: 'دقيقة',
                                              suffixStyle: const TextStyle(
                                                color: Color(0xFF526B68),
                                                fontSize: 11,
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 12,
                                                  ),
                                              filled: true,
                                              fillColor: Colors.white,
                                              errorMaxLines: 3,
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: const BorderSide(
                                                  color: Color(0xFFE5D8C8),
                                                ),
                                              ),
                                            ),
                                            validator: (value) {
                                              final minutes = int.tryParse(
                                                value?.trim() ?? '',
                                              );

                                              if (minutes == null ||
                                                  minutes < 1 ||
                                                  minutes > 120) {
                                                return 'أدخل عددًا صحيحًا من 1 إلى 120';
                                              }

                                              return null;
                                            },
                                            onSaved: (value) {
                                              durations[key] = int.parse(
                                                value!.trim(),
                                              );
                                            },
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (locked)
                                    const Padding(
                                      padding: EdgeInsetsDirectional.only(
                                        start: 48,
                                        top: 4,
                                      ),
                                      child: Text(
                                        'محفوظة ضمن سجل هذا الأسبوع',
                                        style: TextStyle(
                                          color: Color(0xFF526B68),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
                          if (error != null)
                            Text(
                              error!,
                              style: const TextStyle(color: Color(0xFFB55252)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: const Text('إلغاء'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF398681),
                    ),
                    onPressed: saving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;

                            formKey.currentState!.save();

                            setDialogState(() {
                              saving = true;
                              error = null;
                            });

                            try {
                              final plan = await _weeklyPlanService
                                  .saveWeeklyPlan(
                                    weekStart: dateKey(weekStart),
                                    sessions: durations.entries.map((entry) {
                                      return <String, dynamic>{
                                        'practice_date': entry.key,
                                        'duration_minutes': entry.value,
                                      };
                                    }).toList(),
                                  );

                              if (!dialogContext.mounted) return;

                              // Allow closing after the save completes.
                              setDialogState(() {
                                saving = false;
                              });

                              Navigator.of(dialogContext).pop(plan);
                            } catch (exception) {
                              if (!dialogContext.mounted) return;

                              setDialogState(() {
                                saving = false;
                                error = exception.toString().replaceFirst(
                                  'Exception: ',
                                  '',
                                );
                              });
                            }
                          },
                    child: Text(saving ? 'جارٍ الحفظ...' : 'حفظ الخطة'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted || savedPlan == null) return;

    setState(() {
      _weeklyPlan = savedPlan;
      _weeklyPlanError = null;
    });
  }

  Future<void> _showWeeklyCelebration() async {
    final controller = ConfettiController(duration: const Duration(seconds: 2));

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (dialogContext.mounted &&
                !MediaQuery.of(dialogContext).disableAnimations) {
              controller.play();
            }
          });

          return Stack(
            alignment: Alignment.center,
            children: [
              AlertDialog(
                backgroundColor: const Color(0xFFFCFAF6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                title: const Text('أحسنت! 🎉', textAlign: TextAlign.center),
                content: const Text(
                  'أكملت خطتك الأسبوعية!\n'
                  'كل خطوة تصنع فرقًا، استمر على تقدمك.',
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.7),
                ),
                actionsAlignment: MainAxisAlignment.center,
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('رائع!'),
                  ),
                ],
              ),
              IgnorePointer(
                child: ConfettiWidget(
                  confettiController: controller,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                  emissionFrequency: 0.08,
                  numberOfParticles: 15,
                  gravity: 0.2,
                  pauseEmissionOnLowFrameRate: false,
                  colors: const [
                    Color(0xFF1F5F5A),
                    Color(0xFF6FA7A3),
                    Color(0xFFE6BB70),
                    Color(0xFFD79DAD),
                  ],
                ),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _changeCompletion(
    Map<String, dynamic> session,
    bool completed,
  ) async {
    if (_isUpdatingCompletion || _weeklyPlan == null) return;

    final planId = _weeklyPlan!['id'];
    final before = _weeklyPlan!['sessions'] as List<dynamic>;
    final wasComplete =
        before.isNotEmpty &&
        before.every((item) => item['is_completed'] == true);

    bool celebrate = false;

    setState(() {
      _isUpdatingCompletion = true;
    });

    try {
      final updated = await _weeklyPlanService.updateCompletion(
        sessionId: session['id'] as int,
        isCompleted: completed,
      );

      if (!mounted || _weeklyPlan?['id'] != planId) return;

      setState(() {
        final sessions = _weeklyPlan!['sessions'] as List<dynamic>;
        final index = sessions.indexWhere(
          (item) => item['id'] == updated['id'],
        );

        if (index != -1) {
          sessions[index] = updated;

          celebrate =
              completed &&
              updated['is_completed'] == true &&
              !wasComplete &&
              sessions.isNotEmpty &&
              sessions.every((item) => item['is_completed'] == true);
        }
      });
    } catch (exception) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(exception.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingCompletion = false;
        });
      }
    }

    if (mounted &&
        widget.isActive &&
        ModalRoute.of(context)?.isCurrent == true &&
        celebrate) {
      await _showWeeklyCelebration();
    }
  }

  Widget _buildWeeklyPlanCard() {
    const teal = Color(0xFF398681);
    const darkText = Color(0xFF2E3A38);
    const mutedText = Color(0xFF526B68);

    const dayNames = [
      'أحد',
      'إثنين',
      'ثلاثاء',
      'أربعاء',
      'خميس',
      'جمعة',
      'سبت',
    ];

    final today = _riyadhToday();

    final weekStart = _weeklyPlan == null
        ? today.subtract(Duration(days: today.weekday % 7))
        : _parsePracticeDate(_weeklyPlan!['week_start'] as String);

    final weekEnd = weekStart.add(const Duration(days: 6));

    final selectedDate =
        _selectedPracticeDate == null ||
            _selectedPracticeDate!.isBefore(weekStart) ||
            _selectedPracticeDate!.isAfter(weekEnd)
        ? today
        : _selectedPracticeDate!;

    final sessions = ((_weeklyPlan?['sessions'] as List<dynamic>?) ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    Map<String, dynamic>? sessionFor(DateTime date) {
      for (final session in sessions) {
        final sessionDate = _parsePracticeDate(
          session['practice_date'] as String,
        );

        if (sessionDate == date) return session;
      }

      return null;
    }

    final selectedSession = sessionFor(selectedDate);

    final completedCount = sessions
        .where((session) => session['is_completed'] == true)
        .length;

    final totalMinutes = sessions.fold<int>(
      0,
      (total, session) => total + (session['duration_minutes'] as int),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EADF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5D8C8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'خطتك الأسبوعية',
                  style: TextStyle(
                    color: darkText,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!_isLoadingWeeklyPlan &&
                  _weeklyPlanError == null &&
                  _weeklyPlan != null)
                IconButton(
                  tooltip: 'تعديل الخطة',
                  onPressed: _editWeeklyPlan,
                  icon: const Icon(Icons.edit_outlined, color: teal),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${_arabicDate(weekStart)} – '
            '${_arabicDate(weekEnd)} ${weekEnd.year}',
            style: const TextStyle(color: mutedText, fontSize: 13),
          ),
          const SizedBox(height: 6),
          if (_isLoadingWeeklyPlan)
            const Center(child: CircularProgressIndicator(color: teal))
          else if (_weeklyPlanError != null) ...[
            Text(
              _weeklyPlanError!,
              style: const TextStyle(color: Color(0xFFB55252)),
            ),
            TextButton(
              onPressed: _loadWeeklyPlan,
              child: const Text('إعادة تحميل الخطة'),
            ),
          ] else ...[
            if (_weeklyPlan == null) ...[
              const Text(
                'اختر أيام التدريب والمدة المناسبة لك',
                style: TextStyle(color: darkText, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => _editWeeklyPlan(),
                style: FilledButton.styleFrom(backgroundColor: teal),
                icon: const Icon(Icons.add),
                label: const Text('إنشاء جدول جديد'),
              ),
              const SizedBox(height: 12),
            ],
            if (_weeklyPlan != null) ...[
              Text(
                'أكملت $completedCount من أصل ${sessions.length}',
                style: const TextStyle(
                  color: darkText,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: sessions.isEmpty
                      ? 0
                      : completedCount / sessions.length,
                  minHeight: 8,
                  color: teal,
                  backgroundColor: const Color(0xFFE2D7CA),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$totalMinutes دقيقة مخططة لهذا الأسبوع',
                style: const TextStyle(color: mutedText, fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final tileWidth = (constraints.maxWidth - 24) / 7;

                return Wrap(
                  spacing: 4,
                  runSpacing: 8,
                  children: List.generate(7, (index) {
                    final date = weekStart.add(Duration(days: index));
                    final session = sessionFor(date);
                    final selected = date == selectedDate;
                    final completed = session?['is_completed'] == true;
                    final foreground = selected ? Colors.white : teal;

                    return SizedBox(
                      width: tileWidth,
                      child: Semantics(
                        selected: selected,
                        button: true,
                        label: '${dayNames[index]} ${_arabicDate(date)}',
                        child: Material(
                          color: selected ? teal : const Color(0xFFFFFBF6),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              setState(() {
                                _selectedPracticeDate = date;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 2,
                              ),
                              child: Column(
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      dayNames[index],
                                      style: TextStyle(
                                        color: foreground,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${date.day}',
                                    style: TextStyle(
                                      color: foreground,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    height: 16,
                                    child: completed
                                        ? Icon(
                                            Icons.check_circle,
                                            color: foreground,
                                            size: 15,
                                          )
                                        : Center(
                                            child: Container(
                                              width: 5,
                                              height: 5,
                                              decoration: BoxDecoration(
                                                color: session != null
                                                    ? foreground
                                                    : Colors.transparent,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              selectedDate == today
                  ? 'اليوم، ${_arabicDate(selectedDate)}'
                  : _arabicDate(selectedDate),
              style: const TextStyle(
                color: darkText,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAF8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: selectedSession == null
                  ? Text(
                      _weeklyPlan == null
                          ? 'اختر أيامك وأنشئ خطة تناسب أسبوعك.'
                          : sessions.isEmpty
                          ? 'لم تخطط للممارسة هذا الأسبوع. يمكنك تعديل خطتك في أي وقت.'
                          : 'لا توجد جلسة مخططة لهذا اليوم',
                      style: const TextStyle(color: mutedText, height: 1.6),
                    )
                  : Row(
                      children: [
                        Checkbox(
                          value: selectedSession['is_completed'] == true,
                          activeColor: teal,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          onChanged: _isUpdatingCompletion
                              ? null
                              : (value) {
                                  if (value != null) {
                                    _changeCompletion(selectedSession, value);
                                  }
                                },
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ممارسة الكلام',
                                style: TextStyle(
                                  color: darkText,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${selectedSession['duration_minutes']} دقيقة'
                                ' • '
                                '${selectedSession['is_completed'] == true ? 'مكتملة' : 'مخططة'}',
                                style: const TextStyle(
                                  color: mutedText,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAssessmentCard() {
    final completed = _nextStep == 'completed';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF398681), Color(0xFF5B9D98)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  completed
                      ? Icons.check_circle_outline
                      : Icons.assignment_outlined,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  completed ? 'جلساتك التدريبية' : 'أكمل تقييمك',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            completed
                ? 'أكملت التقييمات بنجاح. جلسات التدريب المخصصة ستكون متاحة قريبًا.'
                : 'أكمل التقييم القبلي وتقييم الكلام للحصول على جلسات تدريب تناسب احتياجاتك.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: completed ? null : _continueAssessment,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1F5F5A),
              disabledBackgroundColor: const Color(0xFFDDE8E6),
              disabledForegroundColor: const Color(0xFF526B68),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              completed
                  ? 'التدريب قريبًا'
                  : _nextStep == 'pre_assessment'
                  ? 'ابدأ التقييم القبلي'
                  : 'متابعة تقييم الكلام',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFAF6),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _userName.isEmpty ? 'مرحبًا 👋🏻' : 'مرحبًا، $_userName 👋🏻',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Color(0xFF2E3A38),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'خطوتك القادمة نحو كلام أكثر راحة',
                textAlign: TextAlign.right,
                style: TextStyle(color: Color(0xFF6FA7A3), fontSize: 16),
              ),
              if (_profileError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _profileError!,
                  style: const TextStyle(color: Color(0xFFB55252)),
                ),
                TextButton(
                  onPressed: _loadProfile,
                  child: const Text('إعادة المحاولة'),
                ),
              ],
              const SizedBox(height: 14),

              if (_isLoadingAssessmentStatus)
                const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1F5F5A)),
                )
              else if (_assessmentStatusError != null) ...[
                Text(
                  _assessmentStatusError!,
                  style: const TextStyle(color: Color(0xFFB55252)),
                ),
                TextButton(
                  onPressed: _loadAssessmentStatus,
                  child: const Text('إعادة تحميل حالة التقييم'),
                ),
              ] else
                _buildAssessmentCard(),
              const SizedBox(height: 14),
              _buildWeeklyPlanCard(),
            ],
          ),
        ),
      ),
    );
  }
}
