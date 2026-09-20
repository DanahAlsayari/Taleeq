import 'package:flutter/material.dart';

import 'widgets/account_card.dart';
import 'widgets/assessment_card.dart';
import 'widgets/logout_button.dart';
import 'widgets/profile_header.dart';
import 'widgets/reminder_card.dart';
import 'widgets/training_goals_section.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color darkGreen = Color(0xFF1F5F5A);
  static const Color background = Color(0xFFFCFAF6);
  static const Color darkText = Color(0xFF233330);
  static const Color border = Color(0xFFE3EEEB);

  final ScrollController _scrollController = ScrollController();

  final String _name = 'سارة الراشد';
  final String _email = 'sara@example.com';

  bool _reminderEnabled = true;

  TimeOfDay _reminderTime = const TimeOfDay(
    hour: 18,
    minute: 0,
  );

  final List<String> _goals = [
    'تقليل التكرار في المحادثة',
    'التحدث بثقة أكبر أمام الآخرين',
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<String?> _showGoalDialog({
    required String title,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(
      text: initialValue,
    );

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
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'اكتبي هدفك التدريبي',
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
                  final value = controller.text.trim();

                  if (value.isNotEmpty) {
                    Navigator.pop(
                      dialogContext,
                      value,
                    );
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

    controller.dispose();
    return result;
  }

  Future<void> _addGoal() async {
    final goal = await _showGoalDialog(
      title: 'إضافة هدف جديد',
    );

    if (goal == null || !mounted) return;

    setState(() {
      _goals.add(goal);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _editGoal(int index) async {
    final updatedGoal = await _showGoalDialog(
      title: 'تعديل الهدف',
      initialValue: _goals[index],
    );

    if (updatedGoal == null || !mounted) return;

    setState(() {
      _goals[index] = updatedGoal;
    });
  }

  Future<void> _deleteGoal(int index) async {
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
              'هل أنتِ متأكدة من حذف هذا الهدف؟',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    false,
                  );
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
                  Navigator.pop(
                    dialogContext,
                    true,
                  );
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

    if (shouldDelete == true && mounted) {
      setState(() {
        _goals.removeAt(index);
      });
    }
  }

  Future<void> _changeReminderTime() async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: darkGreen,
              onPrimary: Colors.white,
              surface: background,
              onSurface: darkText,
            ),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
        );
      },
    );

    if (selectedTime != null && mounted) {
      setState(() {
        _reminderTime = selectedTime;
      });
    }
  }

  void _retakeAssessment() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'سيتم ربط إعادة التقييم بواجهة التقييم',
          textAlign: TextAlign.center,
        ),
        backgroundColor: darkGreen,
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
              'هل تريدين تسجيل الخروج من حسابك؟',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    false,
                  );
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
                  Navigator.pop(
                    dialogContext,
                    true,
                  );
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

    if (shouldLogout == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'سيتم ربط تسجيل الخروج بواجهة تسجيل الدخول',
            textAlign: TextAlign.center,
          ),
          backgroundColor: darkGreen,
        ),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
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
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            interactive: true,
            thickness: 4,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                18,
                8,
                18,
                30,
              ),
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
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle('التذكيرات'),
                  const SizedBox(height: 10),
                  ReminderCard(
                    enabled: _reminderEnabled,
                    time: _reminderTime,
                    onChanged: (value) {
                      setState(() {
                        _reminderEnabled = value;
                      });
                    },
                    onChangeTime: _changeReminderTime,
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle('التقييم'),
                  const SizedBox(height: 10),
                  AssessmentCard(
                    onTap: _retakeAssessment,
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
        ),
      ),
    );
  }
}