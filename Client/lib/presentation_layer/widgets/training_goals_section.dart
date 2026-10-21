import 'package:flutter/material.dart';

class TrainingGoalsSection extends StatelessWidget {
  const TrainingGoalsSection({
    super.key,
    required this.goals,
    required this.onAddGoal,
    required this.onEditGoal,
    required this.onDeleteGoal,
    required this.onToggleGoal,
  });

  final List<Map<String, dynamic>> goals;

  final VoidCallback onAddGoal;
  final void Function(int index) onEditGoal;
  final void Function(int index) onDeleteGoal;
  final void Function(int index) onToggleGoal;

  static const Color darkGreen = Color(0xFF1F5F5A);
  static const Color lightGreen = Color(0xFFEAF4F2);
  static const Color border = Color(0xFFE3EEEB);
  static const Color darkText = Color(0xFF233330);
  static const Color mutedText = Color(0xFF7C918C);
  static const Color background = Color(0xFFFCFAF6);

  Future<void> _handleToggle(
    BuildContext context,
    int index,
    bool isCompleted,
  ) async {
    // إكمال الهدف يتم مباشرة
    if (!isCompleted) {
      onToggleGoal(index);
      return;
    }

    // إلغاء الإنجاز يحتاج تأكيد
    final shouldCancelCompletion = await showDialog<bool>(
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
              'إلغاء إنجاز الهدف؟',
              style: TextStyle(
                color: darkText,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            content: const Text(
              'هل تريد إعادة هذا الهدف إلى حالة غير مكتمل؟',
              style: TextStyle(
                color: darkText,
                fontSize: 14,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text(
                  'رجوع',
                  style: TextStyle(
                    color: mutedText,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: darkGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('إلغاء الإنجاز'),
              ),
            ],
          ),
        );
      },
    );

    if (shouldCancelCompletion == true) {
      onToggleGoal(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (goals.isEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 22,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: border),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.flag_outlined,
                  color: darkGreen,
                  size: 32,
                ),
                SizedBox(height: 10),
                Text(
                  'لا توجد أهداف تدريبية بعد',
                  style: TextStyle(
                    color: darkText,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'أضف هدفًا لتبدأ رحلتك التدريبية',
                  style: TextStyle(
                    color: mutedText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

        ...List.generate(
          goals.length,
          (index) => _goalCard(
            context: context,
            goal: goals[index],
            index: index,
          ),
        ),

        const SizedBox(height: 6),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: onAddGoal,
            icon: const Icon(
              Icons.add_rounded,
              color: darkGreen,
            ),
            label: const Text(
              'إضافة هدف جديد',
              style: TextStyle(
                color: darkGreen,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: darkGreen),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _goalCard({
    required BuildContext context,
    required Map<String, dynamic> goal,
    required int index,
  }) {
    final String goalText = goal['goal']?.toString() ?? '';

    final bool isCompleted = goal['is_completed'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 13,
        ),
        decoration: BoxDecoration(
          color: isCompleted
              ? const Color(0xFFF4F9F7)
              : Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: isCompleted
                ? const Color(0xFFC8E1D9)
                : border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // دائرة الإنجاز
            InkWell(
              onTap: () {
                _handleToggle(
                  context,
                  index,
                  isCompleted,
                );
              },
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 27,
                  height: 27,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? darkGreen
                        : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: darkGreen,
                      width: 1.8,
                    ),
                  ),
                  child: isCompleted
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 19,
                        )
                      : null,
                ),
              ),
            ),

            const SizedBox(width: 10),

            // اسم الهدف فقط
            Expanded(
              child: Text(
                goalText,
                style: TextStyle(
                  color: isCompleted
                      ? mutedText
                      : darkText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  decoration: isCompleted
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                  decorationColor: mutedText,
                ),
              ),
            ),

            // قائمة الخيارات
            PopupMenuButton<String>(
              color: Colors.white,
              tooltip: 'خيارات الهدف',
              icon: const Icon(
                Icons.more_vert_rounded,
                color: darkGreen,
              ),
              onSelected: (value) {
                if (value == 'toggle') {
                  _handleToggle(
                    context,
                    index,
                    isCompleted,
                  );
                } else if (value == 'edit') {
                  onEditGoal(index);
                } else if (value == 'delete') {
                  onDeleteGoal(index);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'toggle',
                  child: Row(
                    children: [
                      Icon(
                        isCompleted
                            ? Icons.radio_button_unchecked_rounded
                            : Icons.check_circle_outline_rounded,
                        color: darkGreen,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isCompleted
                            ? 'إلغاء الإنجاز'
                            : 'تحديد كمكتمل',
                        style: const TextStyle(
                          color: darkText,
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        color: darkGreen,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'تعديل',
                        style: TextStyle(
                          color: darkText,
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'حذف',
                        style: TextStyle(
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}