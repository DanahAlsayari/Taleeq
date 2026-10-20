import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/taleeq_theme.dart';

void showTaleeqInfoModal(
  BuildContext context, {
  required String title,
  required String category,
  required String description,
  required IconData icon,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          top: 14,
          left: 24,
          right: 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: TaleeqTheme.softTeal,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: TaleeqTheme.softTeal.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: TaleeqTheme.primaryTeal, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: TaleeqTheme.warmCream,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          category,
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: TaleeqTheme.primaryTeal,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        style: GoogleFonts.cairo(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: TaleeqTheme.darkSlate,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close_rounded),
                  color: TaleeqTheme.textMuted,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: TaleeqTheme.borderSubtle),
            const SizedBox(height: 12),
            Text(
              category == 'تفسير النتيجة'
                  ? 'ماذا تعني هذه النتيجة؟'
                  : 'ما هو هذا المقياس؟',
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: TaleeqTheme.darkSlate,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: GoogleFonts.cairo(
                fontSize: 13,
                color: TaleeqTheme.darkSlate.withValues(alpha: 0.85),
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
