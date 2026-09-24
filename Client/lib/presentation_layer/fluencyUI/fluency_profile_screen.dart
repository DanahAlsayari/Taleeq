import 'dart:math' as math;

import 'package:client/models/fluency_profile_data.dart';
import 'package:client/theme/taleeq_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:client/data_and_integration_layer/services/fluency_profile_service.dart';

double _primaryPatternPercent(FluencyProfileData data) {
  switch (data.primaryPattern.toLowerCase().trim()) {
    case 'repetition':
      return data.repetitionPercent;
    case 'prolongation':
      return data.prolongationPercent;
    case 'block':
      return data.blockPercent;
    default:
      return math.max(
        data.repetitionPercent,
        math.max(data.prolongationPercent, data.blockPercent),
      );
  }
}

bool _isPrimaryPattern(FluencyProfileData data, String pattern) =>
    data.primaryPattern.toLowerCase().trim() == pattern.toLowerCase();

// =============================================================================
// 3. MAIN SCREEN: طلاقتي (FluencyProfileScreen)
// =============================================================================

class FluencyProfileScreen extends StatefulWidget {
  final FluencyProfileData? profileData;

  const FluencyProfileScreen({super.key, this.profileData});

  @override
  State<FluencyProfileScreen> createState() => _FluencyProfileScreenState();
}
// mocck data test
// class _FluencyProfileScreenState extends State<FluencyProfileScreen> {
//   late FluencyProfileData _data;

//   @override
//   void initState() {
//     super.initState();
//     _data = widget.profileData ?? FluencyProfileData.mock();
//   }

// real data function
class _FluencyProfileScreenState extends State<FluencyProfileScreen> {
  late FluencyProfileData _data;

  final FluencyProfileService _fluencyProfileService = FluencyProfileService();

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    if (widget.profileData != null) {
      _data = widget.profileData!;
      _isLoading = false;
    } else {
      _loadFluencyProfile();
    }
  }

  Future<void> _loadFluencyProfile() async {
    await Future.delayed(const Duration(seconds: 15)); // مؤقت للتجربة
    try {
      final data = await _fluencyProfileService.getFluencyProfile();

      if (!mounted) return;

      setState(() {
        _data = data;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
   if (_isLoading) {
  return Scaffold(
    backgroundColor: TaleeqTheme.warmBackground,
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: TaleeqTheme.primaryTeal,
          ),

          const SizedBox(height: 16),

          Text(
            'نجهّز لك تحليل طلاقتك...',
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: TaleeqTheme.darkSlate,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'لحظات ونعرِض لك النتائج',
            style: GoogleFonts.cairo(
              fontSize: 12,
              color: TaleeqTheme.textMuted,
            ),
          ),
        ],
      ),
    ),
  );
}

    if (_errorMessage != null) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: TaleeqTheme.warmBackground,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 46,
                    color: TaleeqTheme.primaryTeal,
                  ),
                  const SizedBox(height: 14),

                  Text(
                    'تعذر تحميل بيانات طلاقتك',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: TaleeqTheme.darkSlate,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'تحقق من الاتصال ثم حاول مرة أخرى',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: TaleeqTheme.textMuted,
                    ),
                  ),

                  const SizedBox(height: 18),

                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _errorMessage = null;
                      });

                      _loadFluencyProfile();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TaleeqTheme.primaryTeal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'إعادة المحاولة',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: TaleeqTheme.warmBackground,
        body: SafeArea(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context)
                .copyWith(overscroll: false),
            child: CustomScrollView(
              physics: const SlowClampingScrollPhysics(speedFactor: 0.6),
              slivers: [
                // الشريط العلوي
                SliverToBoxAdapter(child: _buildTopAppBar(context)),

                // محتوى تقرير الطلاقة
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 8.0,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // حالة الجلسة

                      // 1. بطاقة مؤشر التأتأة الكلي المتحركة
                      _OverallFluencyCard(
                            data: _data,
                            onInfoTap: () =>
                                _showOverallStutteringInfo(context),
                          )
                          .animate()
                          .fadeIn(duration: 500.ms, delay: 100.ms)
                          .slideY(begin: 0.08, end: 0),

                      const SizedBox(height: 16),

                      _SimpleSpeechMetricsCard(
                        data: _data,
                        onSpeakingRateInfoTap: () =>
                            _showSpeakingRateInfo(context),
                        onTimingPacingInfoTap: () =>
                            _showTimingPacingInfo(context),
                      ),

                      const SizedBox(height: 24),

                      const SizedBox(height: 20),

                      // 2. الرسم البياني لمقارنة الأنماط (fl_chart)
                      _StutteringPatternsChart(
                            data: _data,
                            onPatternInfoTap: (name, desc) {
                              _showPatternDetailModal(context, name, desc);
                            },
                          )
                          .animate()
                          .fadeIn(duration: 500.ms, delay: 200.ms)
                          .slideY(begin: 0.08, end: 0),

                      const SizedBox(height: 20),

                      // 3. مقاييس ديناميكيات وسرعة النطق (معدل التحدث + الإيقاع)
                      _TaskResultsCard()
                          .animate()
                          .fadeIn(duration: 500.ms, delay: 300.ms)
                          .slideY(begin: 0.08, end: 0),

                      const SizedBox(height: 24),

                      // مشاركة التقرير
                      Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 18,
                            ),
                            decoration: BoxDecoration(
                              color: TaleeqTheme.softTeal.withValues(
                                alpha: 0.65,
                              ),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Text(
                              '✨ بناءً على نتائج تقييمك، جهزنا لك خطة تدريب مخصصة تركز على احتياجاتك وتطور طلاقتك.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: TaleeqTheme.primaryTeal,
                                height: 1.7,
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: () {
                                // نربطه بصفحة الخطة لاحقاً
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: TaleeqTheme.primaryTeal,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Text(
                                'ابدأ خطتي',
                                style: GoogleFonts.cairo(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(duration: 500.ms, delay: 450.ms),

                      const SizedBox(height: 32),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF16A34A),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'اكتمل التقييم بنجاح ✓',
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Text(
                    'ملف طلاقتي',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.cairo(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: TaleeqTheme.darkSlate,
                      height: 1.2,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    'بناءً على تسجيلاتك، يعرض طليق الأنماط في كلامك',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      color: TaleeqTheme.textMuted,
                      height: 1.5,
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

  void _showOverallStutteringInfo(BuildContext context) {
    _showTaleeqModal(
      context,
      title:
          'مؤشر التأتأة الكلي (${_data.overallStutteringPercent.toStringAsFixed(0)}%)',
      category: 'نتائج التقييم',
      description: 'يعرض هذا المؤشر نسبة التأتأة الكلية المسجلة في نتيجة الجلسة الحالية كما يعيدها نظام التحليل.',
      icon: Icons.pie_chart_rounded,
    );
  }

  void _showSpeakingRateInfo(BuildContext context) {
    _showTaleeqModal(
      context,
      title: 'معدل التحدث (${_data.speakingRate.toStringAsFixed(0)}%)',
      category: 'مؤشرات الجلسة',
      description: 'يقيس مدى ملاءمة وثبات سرعة التحدث أثناء الكلام. النسبة الأعلى تعني أن سرعة الكلام كانت أكثر استقرارًا وملاءمة.  ',
      icon: Icons.speed_rounded,
    );
  }

  void _showTimingPacingInfo(BuildContext context) {
    _showTaleeqModal(
      context,
      title: 'الإيقاع والتوقيت (${_data.timingPacing.toStringAsFixed(0)}%)',
      category: 'مؤشرات الجلسة',
      description: 'يقيس مدى استقرار وطبيعية توقيت الكلام وإيقاعه، مع مراعاة الوقفات والانقطاعات وتدفق الكلام. النسبة الأعلى تعني إيقاعًا وتوقيتًا أكثر استقرارًا وطبيعية.',
      icon: Icons.graphic_eq_rounded,
    );
  }

  void _showPatternDetailModal(
    BuildContext context,
    String patternName,
    String description,
  ) {
    _showTaleeqModal(
      context,
      title: patternName,
      category: 'نمط عدم الطلاقة',
      description: description,
      icon: Icons.hearing_rounded,
    );
  }

  void _showScreenOverviewInfo(BuildContext context) {
    _showTaleeqModal(
      context,
      title: 'دليل شاشة "طلاقتي"',
      category: 'عن تطبيق طليق',
      description: 'تجمع شاشة "طلاقتي" مؤشرات الجلسة في مكان واحد، وتشمل النسبة الكلية للتأتأة، توزيع الأنماط، معدل التحدث، والإيقاع والتوقيت.',
      icon: Icons.auto_awesome_rounded,
    );
  }

  void _showTaleeqModal(
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
                'ما هو هذا المقياس؟',
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
}

// =============================================================================
// 4. البطاقة الرئيسية: مؤشر التأتأة والطلاقة الدائري
// =============================================================================

class _OverallFluencyCard extends StatelessWidget {
  final FluencyProfileData data;
  final VoidCallback onInfoTap;

  const _OverallFluencyCard({required this.data, required this.onInfoTap});

  @override
  Widget build(BuildContext context) {
    final stutteringPercent = data.overallStutteringPercent;
    final progressFraction = (stutteringPercent / 100.0).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: TaleeqTheme.cardShadow,
        border: Border.all(color: TaleeqTheme.borderSubtle, width: 1.2),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            left: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TaleeqTheme.softTeal.withValues(alpha: 0.35),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: TaleeqTheme.softTeal.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.insights_rounded,
                        color: TaleeqTheme.primaryTeal,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مؤشر التأتأة الكلي',
                            style: GoogleFonts.cairo(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: TaleeqTheme.darkSlate,
                            ),
                          ),
                          Text(
                            'ملخص المؤشرات المسجلة في الجلسة الصوتية',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: TaleeqTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onInfoTap,
                      icon: const Icon(Icons.info_outline_rounded),
                      color: TaleeqTheme.mediumTeal,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularPercentIndicator(
                      radius: 68.0,
                      lineWidth: 12.0,
                      animation: true,
                      animationDuration: 1300,
                      percent: progressFraction,
                      circularStrokeCap: CircularStrokeCap.round,
                      backgroundColor: TaleeqTheme.softTeal.withValues(
                        alpha: 0.4,
                      ),
                      progressColor: TaleeqTheme.primaryTeal,
                      center: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${stutteringPercent.toStringAsFixed(0)}%',
                            style: GoogleFonts.cairo(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: TaleeqTheme.primaryTeal,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            'نسبة التأتأة',
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: TaleeqTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: TaleeqTheme.softPeach.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: TaleeqTheme.softPeach,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.waves_rounded,
                          color: TaleeqTheme.primaryTeal,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'النمط الصوتي السائد',
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: TaleeqTheme.textMuted,
                              ),
                            ),
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: data.primaryPatternArabic,
                                    style: GoogleFonts.cairo(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: TaleeqTheme.darkSlate,
                                    ),
                                  ),
                                  TextSpan(
                                    text:
                                        ' (${_primaryPatternPercent(data).toStringAsFixed(0)}%) ',
                                    style: GoogleFonts.cairo(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: const Color.fromARGB(
                                        255,
                                        31,
                                        54,
                                        52,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 5. بطاقة الرسم البياني لمقارنة الأنماط (BarChart - fl_chart)
// =============================================================================

class _StutteringPatternsChart extends StatefulWidget {
  final FluencyProfileData data;
  final Function(String name, String desc) onPatternInfoTap;

  const _StutteringPatternsChart({
    required this.data,
    required this.onPatternInfoTap,
  });

  @override
  State<_StutteringPatternsChart> createState() =>
      _StutteringPatternsChartState();
}

class _StutteringPatternsChartState extends State<_StutteringPatternsChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final highestPattern = math.max(
      widget.data.repetitionPercent,
      math.max(widget.data.prolongationPercent, widget.data.blockPercent),
    );
    final chartMaxY = math.max(20.0, ((highestPattern + 4) / 5).ceil() * 5.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: TaleeqTheme.cardShadow,
        border: Border.all(color: TaleeqTheme.borderSubtle, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: TaleeqTheme.warmCream.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: TaleeqTheme.primaryTeal,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مقارنة أنماط عدم الطلاقة',
                      style: GoogleFonts.cairo(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: TaleeqTheme.darkSlate,
                      ),
                    ),
                    Text(
                      'توزيع النسب المئوية لأنماط التأتأة الثلاثة',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: TaleeqTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: chartMaxY,
                minY: 0,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => TaleeqTheme.darkSlate,
                    tooltipBorderRadius: BorderRadius.circular(10),
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      String patternName;
                      switch (group.x) {
                        case 0:
                          patternName = 'التكرار';
                          break;
                        case 1:
                          patternName = 'الإطالة';
                          break;
                        case 2:
                          patternName = 'التوقف';
                          break;
                        default:
                          patternName = '';
                      }
                      return BarTooltipItem(
                        '$patternName\n',
                        GoogleFonts.cairo(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        children: [
                          TextSpan(
                            text: '${rod.toY.toStringAsFixed(0)}%',
                            style: GoogleFonts.cairo(
                              color: TaleeqTheme.softPeach,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  touchCallback: (FlTouchEvent event, barTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          barTouchResponse == null ||
                          barTouchResponse.spot == null) {
                        touchedIndex = -1;
                        return;
                      }
                      touchedIndex =
                          barTouchResponse.spot!.touchedBarGroupIndex;
                    });
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 5,
                      getTitlesWidget: (value, meta) {
                        if (value % 5 != 0) return const SizedBox.shrink();
                        return Text(
                          '${value.toInt()}%',
                          style: GoogleFonts.cairo(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: TaleeqTheme.textMuted,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        String title;
                        switch (value.toInt()) {
                          case 0:
                            title = 'التكرار';
                            break;
                          case 1:
                            title = 'الإطالة';
                            break;
                          case 2:
                            title = 'التوقف';
                            break;
                          default:
                            title = '';
                        }
                        final isSelected = touchedIndex == value.toInt();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            title,
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isSelected
                                  ? TaleeqTheme.primaryTeal
                                  : TaleeqTheme.darkSlate,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 5,
                  getDrawingHorizontalLine: (value) => const FlLine(
                    color: TaleeqTheme.borderSubtle,
                    strokeWidth: 1.0,
                    dashArray: [5, 5],
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  // التكرار: 15%
                  _buildBarGroup(
                    0,
                    widget.data.repetitionPercent,
                    TaleeqTheme.primaryTeal,
                    touchedIndex == 0,
                    chartMaxY,
                  ),
                  // الإطالة: 6%
                  _buildBarGroup(
                    1,
                    widget.data.prolongationPercent,
                    TaleeqTheme.mediumTeal,
                    touchedIndex == 1,
                    chartMaxY,
                  ),
                  // التوقف: 3%
                  _buildBarGroup(
                    2,
                    widget.data.blockPercent,
                    const Color(0xFFD67D65),
                    touchedIndex == 2,
                    chartMaxY,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(color: TaleeqTheme.borderSubtle, height: 1),
          const SizedBox(height: 18),

          _buildPatternItem(
            name: 'التكرار (Repetition)',
            percent: widget.data.repetitionPercent,
            accentColor: TaleeqTheme.primaryTeal,
            bgColor: TaleeqTheme.softTeal.withValues(alpha: 0.3),
            icon: Icons.repeat_rounded,
            description: 'تكرار لا إرادي للأصوات أو المقاطع اللفظية الأولى للكلمات (مثل: قـ-قـ-قال).',
          ),
          const SizedBox(height: 10),
          _buildPatternItem(
            name: 'الإطالة (Prolongation)',
            percent: widget.data.prolongationPercent,
            accentColor: TaleeqTheme.mediumTeal,
            bgColor: TaleeqTheme.softTeal.withValues(alpha: 0.18),
            icon: Icons.linear_scale_rounded,
            description: 'مد الصوت الصامت أو الصائت بشكل غير مقصود أثناء نطق الكلمة (مثل: سسسـارة).',
          ),
          const SizedBox(height: 10),
          _buildPatternItem(
            name: 'التوقف (Block)',
            percent: widget.data.blockPercent,
            accentColor: const Color(0xFFD67D65),
            bgColor: TaleeqTheme.softPeach.withValues(alpha: 0.4),
            icon: Icons.pause_circle_outline_rounded,
            description:
                'انحباس مؤقت لتدفق الهواء والصوت مما يعيق خروج الكلمة لحظياً.',
          ),
        ],
      ),
    );
  }

  BarChartGroupData _buildBarGroup(
    int x,
    double y,
    Color color,
    bool isSelected,
    double chartMaxY,
  ) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: isSelected ? 28 : 22,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(8),
          ),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: chartMaxY,
            color: TaleeqTheme.softTeal.withValues(alpha: 0.15),
          ),
        ),
      ],
    );
  }

  Widget _buildPatternItem({
    required String name,
    required double percent,
    required Color accentColor,
    required Color bgColor,
    required IconData icon,
    required String description,
  }) {
    return InkWell(
      onTap: () => widget.onPatternInfoTap(name, description),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: accentColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: TaleeqTheme.darkSlate,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: TaleeqTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${percent.toStringAsFixed(0)}%',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: accentColor,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_left_rounded,
              color: TaleeqTheme.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 6. مقاييس ديناميكيات وسرعة النطق (معدل التحدث + الإيقاع)
// =============================================================================

class _SimpleSpeechMetricsCard extends StatelessWidget {
  final FluencyProfileData data;
  final VoidCallback onSpeakingRateInfoTap;
  final VoidCallback onTimingPacingInfoTap;

  const _SimpleSpeechMetricsCard({
    required this.data,
    required this.onSpeakingRateInfoTap,
    required this.onTimingPacingInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TaleeqTheme.borderSubtle),
        boxShadow: TaleeqTheme.cardShadow,
      ),
      child: Column(
        children: [
          _buildMetricRow(
            title: 'معدل سرعة التحدث',
            value: data.speakingRate,
            onInfoTap: onSpeakingRateInfoTap,
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: TaleeqTheme.borderSubtle),
          ),

          _buildMetricRow(
            title: 'الإيقاع والتوقيت الصوتي',
            value: data.timingPacing,
            onInfoTap: onTimingPacingInfoTap,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow({
    required String title,
    required double value,
    required VoidCallback onInfoTap,
  }) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: TaleeqTheme.darkSlate,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onInfoTap,
                child: const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: TaleeqTheme.mediumTeal,
                ),
              ),
            ],
          ),
        ),

        Text(
          '${value.toStringAsFixed(0)}%',
          style: GoogleFonts.cairo(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: TaleeqTheme.primaryTeal,
          ),
        ),
      ],
    );
  }
}

class _TaskResultsCard extends StatelessWidget {
  const _TaskResultsCard();

  @override
  Widget build(BuildContext context) {
    // مؤقتًا للتصميم فقط
    // بعدين نربطها بالـ API الحقيقي
    final tasks = [
      {'task': 'القراءة', 'pattern': 'التكرار', 'percent': 14.0},
      {'task': 'وصف الصورة', 'pattern': 'الإطالة', 'percent': 9.0},
      {'task': 'الكلام العفوي', 'pattern': 'التوقف', 'percent': 11.0},
    ];

    final highestPercent = tasks
        .map((task) => task['percent'] as double)
        .reduce(math.max);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: TaleeqTheme.cardShadow,
        border: Border.all(color: TaleeqTheme.borderSubtle, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: TaleeqTheme.softTeal.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  color: TaleeqTheme.primaryTeal,
                  size: 22,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'نتائج التقييم حسب المهمة',
                      style: GoogleFonts.cairo(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: TaleeqTheme.darkSlate,
                      ),
                    ),
                    Text(
                      'مقارنة أبرز نمط بين مهام التقييم',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: TaleeqTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          ...List.generate(tasks.length, (index) {
            final task = tasks[index];
            final percent = task['percent'] as double;

            return Padding(
              padding: EdgeInsets.only(
                bottom: index == tasks.length - 1 ? 0 : 16,
              ),
              child: _buildTaskResult(
                taskName: task['task'] as String,
                patternName: task['pattern'] as String,
                percent: percent,
                relativePercent: highestPercent == 0
                    ? 0
                    : percent / highestPercent,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTaskResult({
    required String taskName,
    required String patternName,
    required double percent,
    required double relativePercent,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TaleeqTheme.warmBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TaleeqTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  taskName,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: TaleeqTheme.darkSlate,
                  ),
                ),
              ),

              Text(
                '${percent.toStringAsFixed(0)}%',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: TaleeqTheme.primaryTeal,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          Text(
            'أبرز نمط: $patternName',
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: TaleeqTheme.textMuted,
            ),
          ),

          const SizedBox(height: 12),

          LinearPercentIndicator(
            lineHeight: 12.0,
            animation: true,
            animationDuration: 1400,
            isRTL: true,
            percent: relativePercent.clamp(0.0, 1.0),
            barRadius: const Radius.circular(8),
            backgroundColor: TaleeqTheme.softTeal.withValues(alpha: 0.35),
            linearGradient: const LinearGradient(
              colors: [TaleeqTheme.mediumTeal, TaleeqTheme.primaryTeal],
            ),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

class SlowBouncingScrollPhysics extends BouncingScrollPhysics {
  final double speedFactor;

  const SlowBouncingScrollPhysics({this.speedFactor = 0.55, super.parent});

  @override
  SlowBouncingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SlowBouncingScrollPhysics(
      speedFactor: speedFactor,
      parent: buildParent(ancestor),
    );
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    return super.applyPhysicsToUserOffset(position, offset) * speedFactor;
  }
}

class SlowClampingScrollPhysics extends ClampingScrollPhysics {
  final double speedFactor;

  const SlowClampingScrollPhysics({this.speedFactor = 0.35, super.parent});

  @override
  SlowClampingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SlowClampingScrollPhysics(
      speedFactor: speedFactor,
      parent: buildParent(ancestor),
    );
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    return super.applyPhysicsToUserOffset(position, offset) * speedFactor;
  }
}
