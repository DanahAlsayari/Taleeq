import 'package:flutter/material.dart';

class TrainingGoalsSection extends StatelessWidget {
  const TrainingGoalsSection({
    super.key,
    required this.goals,
    required this.onAddGoal,
    required this.onEditGoal,
    required this.onDeleteGoal,
  });

  final List<String> goals;
  final VoidCallback onAddGoal;
  final void Function(int index) onEditGoal;
  final void Function(int index) onDeleteGoal;

  static const Color darkGreen = Color(0xFF1F5F5A);
  static const Color lightGreen = Color(0xFFEAF4F2);
  static const Color border = Color(0xFFE3EEEB);
  static const Color darkText = Color(0xFF233330);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...List.generate(
          goals.length,
          (index) => _goalCard(
            context,
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
              side: const BorderSide(
                color: darkGreen,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _goalCard(
    BuildContext context, {
    required String goal,
    required int index,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: lightGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.flag_outlined,
                color: darkGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                goal,
                style: const TextStyle(
                  color: darkText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            PopupMenuButton<String>(
              color: Colors.white,
              icon: const Icon(
                Icons.more_vert_rounded,
                color: darkGreen,
              ),
              onSelected: (value) {
                if (value == 'edit') {
                  onEditGoal(index);
                } else if (value == 'delete') {
                  onDeleteGoal(index);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
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
                PopupMenuItem(
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