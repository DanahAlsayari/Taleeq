import 'package:flutter/material.dart';

import '../../models/session_result_model.dart';
import '../../services/session_result_service.dart';
import '../../theme/taleeq_theme.dart';
import '../trainingUI/sessionResult/session_result_screen.dart';

/// "Training sessions" list for the Progress tab (التقدم ← التدريب).
/// Shows completed sessions, newest first; tapping one opens its result.
class SessionHistorySection extends StatefulWidget {
  const SessionHistorySection({super.key});

  @override
  State<SessionHistorySection> createState() => _SessionHistorySectionState();
}

class _SessionHistorySectionState extends State<SessionHistorySection> {
  final _service = SessionResultService();

  late Future<List<SessionHistoryItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchHistory();
  }

  void _reload() {
    setState(() {
      _future = _service.fetchHistory();
    });
  }

  Future<void> _open(SessionHistoryItem item) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SessionResultScreen(sessionId: item.sessionId),
      ),
    );

    if (mounted) {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SessionHistoryItem>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: TaleeqTheme.primaryTeal,
                ),
              ),
            ),
          );
        }

        // The history is optional: hide the section if it cannot be read
        // or if the user has no completed session yet.
        final sessions = snapshot.data;

        if (snapshot.hasError || sessions == null || sessions.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 14),
            const Text(
              'جلساتك التدريبية',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: TaleeqTheme.darkSlate,
              ),
            ),
            const SizedBox(height: 10),
            for (final session in sessions) ...[
              _SessionTile(session: session, onTap: () => _open(session)),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.onTap});

  final SessionHistoryItem session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final change = session.scoreChange;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: TaleeqTheme.borderSubtle),
            boxShadow: TaleeqTheme.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: TaleeqTheme.softTeal,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fact_check_outlined,
                  color: TaleeqTheme.primaryTeal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.sequenceNumber == null
                          ? 'جلسة تدريبية'
                          : 'الجلسة ${session.sequenceNumber}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: TaleeqTheme.darkSlate,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${session.practiceDate ?? ''} · '
                      '${session.exerciseCount} تمارين',
                      style: const TextStyle(
                        fontSize: 12,
                        color: TaleeqTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      session.totalScore == null
                          ? '--'
                          : session.totalScore!.toStringAsFixed(1),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: TaleeqTheme.primaryTeal,
                      ),
                    ),
                  ),
                  if (change != null)
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: change >= 0
                              ? TaleeqTheme.primaryTeal
                              : const Color(0xFFA5483B),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_left_rounded,
                color: TaleeqTheme.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
