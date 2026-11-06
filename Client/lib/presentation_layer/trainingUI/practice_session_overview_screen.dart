import 'package:flutter/material.dart';

import '../../services/practice_session_service.dart';

class PracticeSessionOverviewScreen extends StatefulWidget {
  const PracticeSessionOverviewScreen({
    super.key,
    this.additionalSession = false,
  });

  final bool additionalSession;

  @override
  State<PracticeSessionOverviewScreen> createState() =>
      _PracticeSessionOverviewScreenState();
}

class _PracticeSessionOverviewScreenState
    extends State<PracticeSessionOverviewScreen> {
  final _service = PracticeSessionService();

  late Future<Map<String, dynamic>> _sessionFuture;

  @override
  void initState() {
    super.initState();
    _sessionFuture = _prepareSession();
  }

  Future<Map<String, dynamic>> _prepareSession() {
    return _service.prepareToday(additionalSession: widget.additionalSession);
  }

  void _retry() {
    setState(() {
      _sessionFuture = _prepareSession();
    });
  }

  String _exerciseType(String value) {
    return switch (value) {
      'Reading' => 'القراءة',
      'Picture Description' => 'وصف صورة',
      'Free Speech' => 'الحديث الحر',
      'Question & Answer' => 'سؤال وجواب',
      'Storytelling' => 'سرد قصة',
      _ => value,
    };
  }

  String _difficulty(String value) {
    return switch (value) {
      'Easy' => 'سهل',
      'Medium' => 'متوسط',
      'Hard' => 'متقدم',
      _ => value,
    };
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF1F5F5A);

    return Scaffold(
      backgroundColor: const Color(0xFFFCFAF6),
      appBar: AppBar(
        title: const Text('جلستك التدريبية'),
        backgroundColor: const Color(0xFFFCFAF6),
        foregroundColor: teal,
      ),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _sessionFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: teal),
              );
            }

            if (snapshot.hasError) {
              final error = snapshot.error;
              final message = error is PracticeSessionException
                  ? error.message
                  : 'تعذر تحميل الجلسة. يرجى المحاولة مجددًا.';

              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(message, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _retry,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final session = snapshot.data!;
            final exercises = (session['exercises'] as List)
                .map((item) => Map<String, dynamic>.from(item as Map))
                .toList();

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  '${exercises.length} تمارين مخصصة لك',
                  style: const TextStyle(
                    color: teal,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'تعرّف على التمارين المختارة لجلستك.',
                  style: TextStyle(color: Color(0xFF526B68)),
                ),
                const SizedBox(height: 20),
                for (final exercise in exercises)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: const Color(0xFFF3EADF),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFE0ECE9),
                        foregroundColor: teal,
                        child: Text('${exercise['position']}'),
                      ),
                      title: Text(
                        exercise['title'] as String,
                        style: const TextStyle(
                          color: teal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${_exerciseType(exercise['exercise_type'] as String)}'
                          ' · '
                          '${_difficulty(exercise['difficulty'] as String)}',
                        ),
                      ),
                      trailing: exercise['status'] == 'completed'
                          ? const Icon(Icons.check_circle, color: teal)
                          : null,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
