import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../services/auth_storage.dart';
import '../../services/profile_service.dart';
import '../widgets/account_card.dart';
import '../widgets/logout_button.dart';
import '../widgets/profile_header.dart';
import '../widgets/reminder_card.dart';
import '../widgets/training_goals_section.dart';
import '../authenticationUI/welcome_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.isActive = true});

  final bool isActive;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color darkGreen = Color(0xFF1F5F5A);
  static const Color background = Color(0xFFFCFAF6);
  static const Color darkText = Color(0xFF233330);
  static const Color border = Color(0xFFE3EEEB);

  final ScrollController _scrollController = ScrollController();
  final ProfileService _profileService = ProfileService();

  String _name = '';
  String _email = '';

  bool _reminderEnabled = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 18, minute: 0);

  final List<Map<String, dynamic>> _goals = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isActive && !oldWidget.isActive) {
      _loadProfileData();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    try {
      final profile = await _profileService.getProfile();
      final goals = await _profileService.getGoals();
      final reminder = await _profileService.getReminder();

      if (!mounted) return;

      setState(() {
        _name = profile['name']?.toString() ?? '';
        _email = profile['email']?.toString() ?? '';

        _goals
          ..clear()
          ..addAll(
            goals.map(
              (goal) => Map<String, dynamic>.from(goal as Map),
            ),
          );

        _reminderEnabled = reminder['enabled'] as bool? ?? true;

        _reminderTime = _parseTime(
          reminder['reminder_time']?.toString(),
        );

        _isLoading = false;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'تعذر تحميل بيانات الملف الشخصي';
      });
    }
  }

  TimeOfDay _parseTime(String? value) {
    if (value == null || value.isEmpty) {
      return const TimeOfDay(hour: 18, minute: 0);
    }

    final parts = value.split(':');

    if (parts.length < 2) {
      return const TimeOfDay(hour: 18, minute: 0);
    }

    final hour = int.tryParse(parts[0]) ?? 18;
    final minute = int.tryParse(parts[1]) ?? 0;

    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return const TimeOfDay(hour: 18, minute: 0);
    }

    return TimeOfDay(
      hour: hour,
      minute: minute,
    );
  }

  String _formatTimeForApi(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');

    return '$hour:$minute:00';
  }

  Future<String?> _showGoalDialog({
    required String title,
    String initialValue = '',
  }) async {
  String goalText = initialValue;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Text(
              title,
              style: const TextStyle(
                color: darkGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
           content: TextFormField(
  initialValue: initialValue,
  onChanged: (value) {
    goalText = value;
  },
  autofocus: true,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'اكتب هدفك التدريبي',
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: border,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: darkGreen,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text(
                  'إلغاء',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  final value = goalText.trim();

                  if (value.isNotEmpty) {
                    Navigator.pop(dialogContext, value);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: darkGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('حفظ'),
              ),
            ],
          ),
        );
      },
    );


    return result;
  }

  Future<void> _addGoal() async {
    final goal = await _showGoalDialog(
      title: 'إضافة هدف جديد',
    );

    if (goal == null || !mounted) return;

    try {
      final newGoal = await _profileService.addGoal(goal);

      if (!mounted) return;

      setState(() {
        _goals.add(newGoal);
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;

        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      });
    } catch (_) {
      _showError('تعذر إضافة الهدف');
    }
  }

  Future<void> _editGoal(int index) async {
    if (index < 0 || index >= _goals.length) return;

    final currentGoal = _goals[index];
    final goalId = currentGoal['id'] as int;

    final updatedGoal = await _showGoalDialog(
      title: 'تعديل الهدف',
      initialValue: currentGoal['goal']?.toString() ?? '',
    );

    if (updatedGoal == null || !mounted) return;

    try {
      final updated = await _profileService.updateGoal(
        goalId,
        goal: updatedGoal,
      );

      if (!mounted) return;

      setState(() {
        final updatedIndex = _goals.indexWhere(
          (goal) => goal['id'] == goalId,
        );

        if (updatedIndex != -1) {
          _goals[updatedIndex] = updated;
        }
      });
    } catch (_) {
      _showError('تعذر تعديل الهدف');
    }
  }

  Future<void> _toggleGoal(int index) async {
    if (index < 0 || index >= _goals.length) return;

    final currentGoal = _goals[index];
    final goalId = currentGoal['id'] as int;
    final isCompleted = currentGoal['is_completed'] == true;

    try {
      final updatedGoal = await _profileService.updateGoal(
        goalId,
        isCompleted: !isCompleted,
      );

      if (!mounted) return;

      setState(() {
        final updatedIndex = _goals.indexWhere(
          (goal) => goal['id'] == goalId,
        );

        if (updatedIndex != -1) {
          _goals[updatedIndex] = updatedGoal;
        }
      });
    } catch (_) {
      _showError('تعذر تحديث حالة الهدف');
    }
  }

  Future<void> _deleteGoal(int index) async {
    if (index < 0 || index >= _goals.length) return;

    final goalId = _goals[index]['id'] as int;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: const Text(
              'حذف الهدف',
              style: TextStyle(
                color: darkText,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              'هل أنت متأكد من حذف هذا الهدف؟',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text(
                  'إلغاء',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: const Text('حذف'),
              ),
            ],
          ),
        );
      },
    );

    if (shouldDelete != true || !mounted) return;

    try {
      await _profileService.deleteGoal(goalId);

      if (!mounted) return;

      setState(() {
        _goals.removeWhere(
          (goal) => goal['id'] == goalId,
        );
      });
    } catch (_) {
      _showError('تعذر حذف الهدف');
    }
  }

  Future<void> _updateReminder({
    required bool enabled,
    required TimeOfDay time,
  }) async {
    try {
      final reminder = await _profileService.updateReminder(
        enabled: enabled,
        reminderTime: _formatTimeForApi(time),
      );

      if (!mounted) return;

      setState(() {
        _reminderEnabled =
            reminder['enabled'] as bool? ?? enabled;

        _reminderTime = _parseTime(
          reminder['reminder_time']?.toString(),
        );
      });
    } catch (_) {
      _showError('تعذر تحديث التذكير');
    }
  }

  Future<void> _changeReminderStatus(bool value) async {
    await _updateReminder(
      enabled: value,
      time: _reminderTime,
    );
  }

  // ==========================================
  // ساعة التذكير الجديدة - بتصميم طليق
  // ==========================================

  Future<void> _changeReminderTime() async {
    final initialDateTime = DateTime(
      2026,
      1,
      1,
      _reminderTime.hour,
      _reminderTime.minute,
    );

    DateTime selectedDateTime = initialDateTime;

    final selectedTime = await showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: background,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // مؤشر السحب
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(height: 22),

                const Text(
                  'تحديد وقت التذكير',
                  style: TextStyle(
                    color: darkText,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  'اختاري الوقت المناسب لتذكيرك بالتدريب',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF7C918C),
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 22),

                // عجلة اختيار الوقت
                Container(
                  height: 210,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: border),
                  ),
                  child: CupertinoTheme(
                    data: const CupertinoThemeData(
                      brightness: Brightness.light,
                      primaryColor: darkGreen,
                      textTheme: CupertinoTextThemeData(
                        dateTimePickerTextStyle: TextStyle(
                          color: darkGreen,
                          fontSize: 23,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    child: Localizations.override(
                      context: sheetContext,
                      locale: const Locale('en', 'US'),
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: CupertinoDatePicker(
                          mode: CupertinoDatePickerMode.time,
                          initialDateTime: initialDateTime,
                          use24hFormat: false,
                          minuteInterval: 1,
                          backgroundColor: Colors.white,
                          onDateTimeChanged: (dateTime) {
                            selectedDateTime = dateTime;
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'مرري للأعلى أو الأسفل لتغيير الوقت',
                  style: TextStyle(
                    color: Color(0xFF7C918C),
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 26),

                // أزرار إلغاء وحفظ
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: darkGreen,
                            side: const BorderSide(
                              color: darkGreen,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'إلغاء',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(
                              sheetContext,
                              TimeOfDay(
                                hour: selectedDateTime.hour,
                                minute: selectedDateTime.minute,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: darkGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'حفظ',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedTime == null || !mounted) return;

    await _updateReminder(
      enabled: _reminderEnabled,
      time: selectedTime,
    );
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: const Text(
              'تسجيل الخروج',
              style: TextStyle(
                color: darkText,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              'هل تريد تسجيل الخروج من حسابك؟',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text(
                  'إلغاء',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: const Text('تسجيل الخروج'),
              ),
            ],
          ),
        );
      },
    );

    if (shouldLogout != true) return;

    await AuthStorage.deleteToken();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const WelcomeScreen(),
      ),
      (route) => false,
    );
  }

  Widget _sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        title,
        style: const TextStyle(
          color: darkText,
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(
        color: darkGreen,
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: darkGreen,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'حدث خطأ',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: darkText,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });

                _loadProfileData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: darkGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('إعادة المحاولة'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _logout,
              child: const Text(
                'تسجيل الخروج',
                style: TextStyle(
                  color: darkGreen,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfile() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        interactive: true,
        thickness: 4,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProfileHeader(
                name: _name,
                email: _email,
              ),

              const SizedBox(height: 24),

              _sectionTitle('معلومات الحساب'),

              const SizedBox(height: 10),

              AccountCard(
                name: _name,
                email: _email,
              ),

              const SizedBox(height: 24),

              _sectionTitle('أهداف التدريب'),

              const SizedBox(height: 10),

              TrainingGoalsSection(
                goals: _goals,
                onAddGoal: _addGoal,
                onEditGoal: _editGoal,
                onDeleteGoal: _deleteGoal,
                onToggleGoal: _toggleGoal,
              ),

              const SizedBox(height: 24),

              _sectionTitle('التذكيرات'),

              const SizedBox(height: 10),

              ReminderCard(
                enabled: _reminderEnabled,
                time: _reminderTime,
                onChanged: _changeReminderStatus,
                onChangeTime: _changeReminderTime,
              ),

              const SizedBox(height: 28),

              LogoutButton(
                onPressed: _logout,
              ),

              const SizedBox(height: 25),

              const Center(
                child: Text(
                  'طليق • الإصدار 1.0.0',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'الملف الشخصي',
          style: TextStyle(
            color: darkText,
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoading()
            : _errorMessage != null
                ? _buildError()
                : _buildProfile(),
      ),
    );
  }
}