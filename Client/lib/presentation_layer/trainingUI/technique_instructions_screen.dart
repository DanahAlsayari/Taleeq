import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:client/models/technique_model.dart';
import 'package:client/services/technique_service.dart';
import 'package:client/theme/taleeq_theme.dart';

class TechniqueInstructionsScreen extends StatefulWidget {
  final int techniqueId;

  // Exercise data will be provided by another team member.
  final String exerciseTitle;
  final String exerciseDescription;
  final List<String> exerciseInstructions;

  // Exercise navigation will be connected later.
  final VoidCallback? onStartExercise;

  const TechniqueInstructionsScreen({
    super.key,
    required this.techniqueId,
    required this.exerciseTitle,
    required this.exerciseDescription,
    required this.exerciseInstructions,
    this.onStartExercise,
  });

  @override
  State<TechniqueInstructionsScreen> createState() =>
      _TechniqueInstructionsScreenState();
}

class _TechniqueInstructionsScreenState
    extends State<TechniqueInstructionsScreen> {
  final TechniqueService _service = TechniqueService();

  late Future<TechniqueModel> _techniqueFuture;

  @override
  void initState() {
    super.initState();
    _loadTechnique();
  }

  @override
  void didUpdateWidget(covariant TechniqueInstructionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.techniqueId != widget.techniqueId) {
      _loadTechnique();
    }
  }

  void _loadTechnique() {
    if (kDebugMode) {
      debugPrint(
        '[TechniqueScreen] Loading technique_id=${widget.techniqueId}',
      );
    }

    _techniqueFuture = _service.getTechnique(widget.techniqueId);
  }

  void _retry() {
    setState(_loadTechnique);
  }

  Future<void> _openVideo(String videoUrl) async {
    try {
      final uri = Uri.parse(videoUrl);

      if (uri.scheme != 'https' && uri.scheme != 'http') {
        throw Exception('Unsupported video URL');
      }

      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!opened) {
        throw Exception('Could not open video');
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[TechniqueScreen] Video error: $error');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح الفيديو، حاول مرة أخرى.')),
      );
    }
  }

  Widget _sectionCard({required Widget child, Color color = Colors.white}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TaleeqTheme.borderSubtle),
        boxShadow: TaleeqTheme.cardShadow,
      ),
      child: child,
    );
  }

  Widget _buildInstructions() {
    return _sectionCard(
      color: const Color(0xFFEAF4F2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'قبل أن تبدأ',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: TaleeqTheme.primaryTeal,
            ),
          ),
          const SizedBox(height: 14),
          ...widget.exerciseInstructions.map(
            (instruction) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 21,
                    color: TaleeqTheme.primaryTeal,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      instruction,
                      style: const TextStyle(fontSize: 15, height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnique(TechniqueModel technique) {

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'التقنية المقترحة لك',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: TaleeqTheme.primaryTeal,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            technique.nameAr,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            technique.nameEn,
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontSize: 14, color: TaleeqTheme.textMuted),
          ),
          const SizedBox(height: 14),
          Text(
            technique.description,
            style: const TextStyle(fontSize: 15, height: 1.7),
          ),
          const SizedBox(height: 22),
          
          const Text(
            'خطوات تطبيق التقنية',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...technique.steps.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: TaleeqTheme.softTeal,
                    child: Text(
                      '${entry.key + 1}',
                      style: const TextStyle(
                        color: TaleeqTheme.primaryTeal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: const TextStyle(fontSize: 15, height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (technique.example != null &&
              technique.example!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'مثال',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(technique.example!),
          ],
          if (technique.tips.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'نصائح',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...technique.tips.map(
              (tip) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text('• $tip'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: TaleeqTheme.warmBackground,
        appBar: AppBar(
          backgroundColor: TaleeqTheme.warmBackground,
          centerTitle: true,
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.menu_book_rounded,
                color: TaleeqTheme.primaryTeal,
                size: 25,
              ),
              SizedBox(width: 8),
              Text(
                'تعليمات التمرين',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: TaleeqTheme.primaryTeal,
                ),
              ),
            ],
          ),
        ),
        body: FutureBuilder<TechniqueModel>(
          future: _techniqueFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(
                  color: TaleeqTheme.primaryTeal,
                ),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              if (kDebugMode) {
                debugPrint('[TechniqueScreen] Load failed: ${snapshot.error}');
              }

              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('تعذر تحميل معلومات التقنية'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _retry,
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              );
            }

            final technique = snapshot.data!;

            return SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text(
                          widget.exerciseTitle,
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: TaleeqTheme.darkSlate,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.exerciseDescription,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.6,
                            color: TaleeqTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildInstructions(),
                        const SizedBox(height: 20),
                        _buildTechnique(technique),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: widget.onStartExercise,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TaleeqTheme.primaryTeal,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: TaleeqTheme.softTeal,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'ابدأ التمرين',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
