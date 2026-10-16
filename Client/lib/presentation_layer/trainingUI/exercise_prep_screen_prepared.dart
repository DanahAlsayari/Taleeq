import 'package:flutter/material.dart';
import 'package:client/services/technique_service.dart';
import 'package:client/models/technique_model.dart';

// ==================== COLORS ====================
class TaleeqColors {
  static const primary = Color(0xFF1F5F5A);
  static const medium = Color(0xFF6FA7A3);
  static const soft = Color(0xFFCFE4E1);
  static const background = Color(0xFFFFFCF8);
  static const text = Color(0xFF2E3A38);
  static const border = Color(0xFFE8EFEF);
  static const muted = Color(0xFF6C807D);
}

// ==================== MODELS ====================
class ExerciseDetails {
  final int id;
  final String title;
  final String description;
  final List<String> instructions;
  const ExerciseDetails({
    required this.id,
    required this.title,
    required this.description,
    this.instructions = const [],
  });
}

// Future connection to the exercise team's API.
typedef ExerciseDetailsLoader = Future<ExerciseDetails> Function(
  int exerciseId,
);

class Technique {
  final int id;
  final String nameAr;
  final String nameEn;
  final String explanation;
  final List<String> steps;
  final String? example;
  final List<String> tips;

  const Technique({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.explanation,
    this.steps = const [],
    this.example,
    this.tips = const [],
  
  });
}



Technique techniqueFromModel(TechniqueModel model) => Technique(
  id: model.id,
  nameAr: model.nameAr,
  nameEn: model.nameEn,
  explanation: model.description,
  steps: model.steps,
  example: model.example,
  tips: model.tips,
 
);

// ==================== SCREEN ====================
class ExercisePrepScreen extends StatefulWidget {
  final int? exerciseId;
  final ExerciseDetailsLoader? exerciseLoader;
  // Preview only; remove when the exercise API is connected.
  final ExerciseDetails? previewExercise;
  final List<Technique> techniques;
  final ValueChanged<Technique> onStart;
  const ExercisePrepScreen({
    super.key,
    this.exerciseId,
    this.exerciseLoader,
    this.previewExercise,
    this.techniques = const [],
    required this.onStart,
  });
  @override
  State<ExercisePrepScreen> createState() => _ExercisePrepScreenState();
}

class NoStretchScrollBehavior extends MaterialScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class _ExercisePrepScreenState extends State<ExercisePrepScreen> {
  final TechniqueService techniqueService = TechniqueService();
  Technique? selectedTechnique;
  List<Technique> availableTechniques = [];
  bool loadingTechniques = false;
  bool loadingDetails = false;
  String? techniqueError;
  int selectionRequest = 0;
  bool _showTechniqueList = false;
  final ScrollController _pageScrollController = ScrollController();
  late Future<ExerciseDetails> exerciseFuture;

  @override
  void initState() {
    super.initState();
    loadExercise();
    if (widget.techniques.isNotEmpty) {
      availableTechniques = widget.techniques;
      selectedTechnique = widget.techniques.first;
    } else {
      loadTechniques();
    }
  }

  @override
  void didUpdateWidget(covariant ExercisePrepScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exerciseId != widget.exerciseId ||
        oldWidget.exerciseLoader != widget.exerciseLoader ||
        oldWidget.previewExercise != widget.previewExercise) {
      setState(loadExercise);
    }
    if (oldWidget.techniques != widget.techniques &&
        widget.techniques.isNotEmpty) {
      setState(() {
        availableTechniques = widget.techniques;
        selectedTechnique = widget.techniques.first;
        _showTechniqueList = false;
      });
    }
  }

  Future<void> loadTechniques() async {
    setState(() {
      loadingTechniques = true;
      techniqueError = null;
    });
    try {
      final models = await techniqueService.getAllTechniques();
      if (!mounted) return;
      final fetched = models.map(techniqueFromModel).toList();
      setState(() {
        availableTechniques = fetched;
        selectedTechnique = fetched.isEmpty ? null : fetched.first;
        loadingTechniques = false;
      });
      if (fetched.isNotEmpty) await loadTechniqueDetails(fetched.first.id);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loadingTechniques = false;
        techniqueError =
            'تعذر تحميل التقنيات. تأكد من تشغيل السيرفر والاتصال به.';
      });
    }
  }

  Future<void> loadTechniqueDetails(int id) async {
    final request = ++selectionRequest;
    setState(() {
      loadingDetails = true;
      techniqueError = null;
    });
    try {
      final model = await techniqueService.getTechnique(id);
      if (!mounted || request != selectionRequest) return;
      setState(() {
        selectedTechnique = techniqueFromModel(model);
        loadingDetails = false;
      });
    } catch (error) {
      if (!mounted || request != selectionRequest) return;
      setState(() {
        loadingDetails = false;
        techniqueError = 'تعذر تحميل تعليمات التقنية. حاول مرة أخرى.';
      });
    }
  }

  void loadExercise() {
    if (widget.exerciseId != null && widget.exerciseLoader != null) {
      exerciseFuture = widget.exerciseLoader!(widget.exerciseId!);
    } else if (widget.previewExercise != null) {
      exerciseFuture = Future.value(widget.previewExercise!);
    } else {
      exerciseFuture = Future.error(
        StateError('Exercise API is not connected yet'),
      );
    }
  }

  void retryExercise() {
    setState(loadExercise);
  }

  @override
  void dispose() {
    _pageScrollController.dispose();
    super.dispose();
  }

  Future<void> selectTechnique(Technique technique) async {
    setState(() => _showTechniqueList = false);
    if (selectedTechnique?.id == technique.id) return;
    await loadTechniqueDetails(technique.id);
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: TaleeqColors.background,
          appBar: AppBar(
            backgroundColor: TaleeqColors.background,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            title: const Text(
              'الاستعداد للتمرين',
              style: TextStyle(
                color: TaleeqColors.primary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            leading: Padding(
              padding: const EdgeInsets.all(7),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.maybePop(context),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: TaleeqColors.primary,
                  ),
                ),
              ),
            ),
          ),
          body: ListView(
            controller: _pageScrollController,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
            children: [
              FutureBuilder<ExerciseDetails>(
                future: exerciseFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: TaleeqColors.primary,
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return CardContainer(
                      child: Column(
                        children: [
                          const Text('تعذر تحميل بيانات التمرين'),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: retryExercise,
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    );
                  }
                  return ExerciseCard(exercise: snapshot.data!);
                },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Flexible(
                    child: Text(
                      'اختر تقنية تساعدك أثناء التمرين',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: TaleeqColors.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'معلومات عن اختيار التقنية',
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.info_outline_rounded,
                      color: TaleeqColors.primary,
                      size: 21,
                    ),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        backgroundColor: TaleeqColors.background,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        title: const Text(
                          'لماذا أختار تقنية؟',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: TaleeqColors.primary,
                          ),
                        ),
                        content: const Text(
                          'توجد طرق مختلفة تساعدك على ممارسة الكلام براحة أكبر. '
                          'يمكنك اختيار أي تقنية والاطلاع على طريقة تطبيقها قبل بدء التمرين. '
                          'اختيارك للتقنية لا يؤثر على تقييم أدائك.',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.7,
                            color: TaleeqColors.text,
                          ),
                        ),
                        actions: [
                          ElevatedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: TaleeqColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'فهمت',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (loadingTechniques || loadingDetails)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: TaleeqColors.primary,
                    ),
                  ),
                ),
              if (techniqueError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      Text(techniqueError!, textAlign: TextAlign.center),
                      TextButton(
                        onPressed:
                            loadingTechniques || availableTechniques.isEmpty
                            ? loadTechniques
                            : () => loadTechniqueDetails(selectedTechnique!.id),
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              if (selectedTechnique != null &&
                  !loadingTechniques &&
                  !loadingDetails &&
                  techniqueError == null)
                CardContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The technique selector and its instructions share one card.
                      TechniqueSelector(
                        technique: selectedTechnique!,
                        onTap: () {
                          final opening = !_showTechniqueList;

                          setState(() {
                            _showTechniqueList = opening;
                          });

                          if (opening) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted || !_pageScrollController.hasClients)
                                return;

                              _pageScrollController.animateTo(
                                _pageScrollController.position.maxScrollExtent,
                                duration: const Duration(milliseconds: 1400),
                                curve: Curves.easeInOutCubic,
                              );
                            });
                          }
                        },
                        expanded: _showTechniqueList,
                        embedded: true,
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOut,
                        alignment: Alignment.topCenter,
                        child: _showTechniqueList
                            ? Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: TechniqueInlineList(
                                  techniques: availableTechniques,
                                  selectedId: selectedTechnique!.id,
                                  onSelect: selectTechnique,
                                ),
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: TaleeqColors.border),
                      const SizedBox(height: 14),
                      TechniqueInstructionsCard(
                        key: ValueKey(selectedTechnique!.id),
                        technique: selectedTechnique!,
                        embedded: true,
                      ),
                    ],
                  ),
                ),
              if (!loadingTechniques &&
                  !loadingDetails &&
                  selectedTechnique == null &&
                  techniqueError == null)
                const Text('لا توجد تقنيات متاحة'),
            ],  
          ),
          // Fixed bottom button
          bottomNavigationBar: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: const BoxDecoration(
              color: TaleeqColors.background,
              border: Border(top: BorderSide(color: TaleeqColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 58,
                child: ElevatedButton.icon(
                  onPressed:
                      selectedTechnique == null ||
                          loadingTechniques ||
                          loadingDetails ||
                          techniqueError != null
                      ? null
                      : () => widget.onStart(selectedTechnique!),
                  icon: const Icon(Icons.play_arrow_rounded, size: 26),
                  label: const Text(
                    'ابدأ التمرين',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TaleeqColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== SHARED CARD ====================
class CardContainer extends StatelessWidget {
  final Widget child;
  const CardContainer({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: TaleeqColors.border),
        boxShadow: [
          BoxShadow(
            color: TaleeqColors.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ==================== EXERCISE CARD ====================
class ExerciseCard extends StatelessWidget {
  final ExerciseDetails exercise;
  const ExerciseCard({super.key, required this.exercise});
  @override
  Widget build(BuildContext context) {
    return CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: TaleeqColors.soft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: TaleeqColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'التمرين',
                      style: TextStyle(color: TaleeqColors.muted, fontSize: 12),
                    ),
                    Text(
                      exercise.title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: TaleeqColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            exercise.description,
            style: const TextStyle(
              fontSize: 15,
              height: 1.7,
              color: TaleeqColors.text,
            ),
          ),
          if (exercise.instructions.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: TaleeqColors.border),
            const SizedBox(height: 10),
            for (final instruction in exercise.instructions)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: TaleeqColors.medium,
                      size: 19,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        instruction,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: TaleeqColors.text,
                        ),
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
}

// ==================== TECHNIQUE SELECTOR ====================
class TechniqueSelector extends StatelessWidget {
  final Technique technique;
  final VoidCallback onTap;
  final bool embedded;
  final bool expanded;
  const TechniqueSelector({
    super.key,
    required this.technique,
    required this.onTap,
    this.embedded = false,
    this.expanded = false,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: TaleeqColors.soft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.graphic_eq_rounded,
                color: TaleeqColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    technique.nameAr,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: TaleeqColors.primary,
                    ),
                  ),
                  Text(
                    technique.nameEn,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12,
                      color: TaleeqColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 27,
                color: TaleeqColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== INLINE TECHNIQUE LIST ====================
class TechniqueInlineList extends StatelessWidget {
  final List<Technique> techniques;
  final int selectedId;
  final ValueChanged<Technique> onSelect;

  const TechniqueInlineList({
    super.key,
    required this.techniques,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    // All items show when they fit; otherwise this area scrolls independently.
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: techniques.length,
      separatorBuilder: (_, __) => const SizedBox(height: 7),
      itemBuilder: (context, index) {
        final technique = techniques[index];
        final selected = technique.id == selectedId;
        return Material(
          color: selected ? const Color(0xFFEEF6F5) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
            side: BorderSide(
              color: selected ? TaleeqColors.primary : TaleeqColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: InkWell(
            onTap: () => onSelect(technique),
            borderRadius: BorderRadius.circular(13),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? TaleeqColors.primary
                          : TaleeqColors.soft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: selected ? Colors.white : TaleeqColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          technique.nameAr,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: selected
                                ? TaleeqColors.primary
                                : TaleeqColors.text,
                          ),
                        ),
                        Text(
                          technique.nameEn,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: TaleeqColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: TaleeqColors.primary,
                      size: 22,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ==================== TECHNIQUE INSTRUCTIONS ====================
class TechniqueInstructionsCard extends StatefulWidget {
  final Technique technique;
  final bool embedded;

  const TechniqueInstructionsCard({
    super.key,
    required this.technique,
    this.embedded = false,
  });

  @override
  State<TechniqueInstructionsCard> createState() =>
      _TechniqueInstructionsCardState();
}

class _TechniqueInstructionsCardState extends State<TechniqueInstructionsCard> {
  bool _showSteps = false;
  Technique get technique => widget.technique;

  // Short UI summaries. Full descriptions remain unchanged in PostgreSQL.
  static const Map<int, String> _shortDescriptions = {
    1: 'ابدأ الكلام بصوت هادئ وتدريجي، دون الضغط على الحلق.',
    2: 'أطِل بعض الأصوات بلطف وانتقل بينها بسلاسة.',
    3: 'تحدث بوتيرة مريحة تمنحك وقتًا لنطق الكلمات بوضوح.',
    4: 'استخدم وقفات قصيرة بين العبارات لتنظيم الكلام.',
    5: 'انطق مقاطع الكلام مع إيقاع منتظم ومريح.',
    6: 'تدرّب على تأتأة خفيفة ومقصودة لتقليل الخوف منها.',
    7: 'بعد التأتأة، توقف قليلًا ثم أعد الكلمة بلطف.',
    8: 'خفف الشد أثناء التأتأة وأكمل الكلمة براحة.',
  };

  // The description already includes a detailed text example.
  // Show it once in the example card instead of repeating it in the text.
  String? _descriptionExample() {
    const marker = 'مثال تطبيقي:';
    final index = technique.explanation.indexOf(marker);
    if (technique.example != null && technique.example!.trim().isNotEmpty) {
      return technique.example!.trim();
    }
    if (index == -1) return null;
    final example = technique.explanation
        .substring(index + marker.length)
        .trim();
    return example.isNotEmpty ? example : null;
  }

  String _description() {
    final text = technique.explanation.split('مثال تطبيقي:').first.trim();
    return _shortDescriptions[technique.id] ?? text;
  }

  @override
  Widget build(BuildContext context) {
    final visibleSteps = technique.steps.take(3).toList();
    final example = _descriptionExample();

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _description(),
          style: const TextStyle(
            fontSize: 14,
            height: 1.55,
            color: TaleeqColors.text,
          ),
        ),
        if (visibleSteps.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Divider(color: TaleeqColors.border),
          InkWell(
            onTap: () => setState(() => _showSteps = !_showSteps),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'طريقة التطبيق',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color.fromARGB(255, 53, 82, 77),
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _showSteps ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: TaleeqColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _showSteps
                ? Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Column(
                      children: [
                        for (var i = 0; i < visibleSteps.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: TaleeqColors.primary,
                                  child: Text(
                                    '${i + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    visibleSteps[i],
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.5,
                                      color: TaleeqColors.text,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (example != null && example.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: TaleeqColors.soft,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      color: TaleeqColors.primary,
                                      size: 18,
                                    ),
                                    SizedBox(width: 7),
                                    Text(
                                      'مثال تطبيقي',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: TaleeqColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  example,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.55,
                                    color: TaleeqColors.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ],
    );
    return widget.embedded ? content : CardContainer(child: content);
  }
}


// ==================== TEMPORARY PREVIEW DATA ====================
// Exercise data will come from the exercise team's DB table.
// Technique data is loaded from the existing API.
// Preview exercise
const previewExercise = ExerciseDetails(
  id: 1,
  title: 'تمرين القراءة',
  description: 'اقرأ النص بصوت واضح مع تطبيق التقنية التي تختارها.',
  instructions: [
    'اختر مكانًا هادئًا ومريحًا.',
    'تأكد من عمل الميكروفون.',
    'خذ وقتك وتحدث براحة.',
  ],
);
