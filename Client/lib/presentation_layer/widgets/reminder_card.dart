import 'package:flutter/material.dart';

class ReminderCard extends StatelessWidget {
  const ReminderCard({
    super.key,
    required this.enabled,
    required this.time,
    required this.onChanged,
    required this.onChangeTime,
  });

  final bool enabled;
  final TimeOfDay time;
  final ValueChanged<bool> onChanged;
  final VoidCallback onChangeTime;

  static const Color darkGreen = Color(0xFF1F5F5A);
  static const Color lightGreen = Color(0xFFEAF4F2);
  static const Color border = Color(0xFFE3EEEB);
  static const Color darkText = Color(0xFF233330);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: lightGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: darkGreen,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تذكير التمارين',
                      style: TextStyle(
                        color: darkText,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'ذكّرني بموعد التدريب اليومي',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                onChanged: onChanged,
                activeThumbColor: Colors.white,
                activeTrackColor: darkGreen,
              ),
            ],
          ),

          if (enabled) ...[
            const SizedBox(height: 14),
            const Divider(color: border),
            const SizedBox(height: 8),

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'وقت التذكير',
                    style: TextStyle(
                      color: darkText,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                InkWell(
                  onTap: onChangeTime,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: lightGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          color: darkGreen,
                          size: 19,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          time.format(context),
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                            color: darkGreen,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}