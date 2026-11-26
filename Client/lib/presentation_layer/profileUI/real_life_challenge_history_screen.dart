import 'package:flutter/material.dart';

import '../../services/real_life_challenge_service.dart';

class RealLifeChallengeHistoryScreen extends StatefulWidget {
  const RealLifeChallengeHistoryScreen({super.key});

  @override
  State<RealLifeChallengeHistoryScreen> createState() =>
      _RealLifeChallengeHistoryScreenState();
}

class _RealLifeChallengeHistoryScreenState
    extends State<RealLifeChallengeHistoryScreen> {
  static const _teal = Color(0xFF1F5F5A);
  static const _text = Color(0xFF2E3A38);
  static const _muted = Color(0xFF526B68);

  final _service = RealLifeChallengeService();
  final List<Map<String, dynamic>> _items = [];

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _errorMessage(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  String _completionDate(String value) {
    final date = DateTime.parse(value).toUtc().add(const Duration(hours: 3));

    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];

    final formatted = '${date.day} ${months[date.month - 1]} ${date.year}';

    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';

    return formatted.replaceAllMapped(
      RegExp(r'[0-9]'),
      (match) => arabicDigits[int.parse(match.group(0)!)],
    );
  }

  Future<void> _load() async {
    if (_loadingMore) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _service.getHistory();

      if (!mounted) return;

      setState(() {
        _items
          ..clear()
          ..addAll((result['items'] as List).cast<Map<String, dynamic>>());
        _hasMore = result['has_more'] as bool;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = _errorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;

    setState(() {
      _loadingMore = true;
    });

    try {
      final result = await _service.getHistory(offset: _items.length);

      if (!mounted) return;

      setState(() {
        _items.addAll((result['items'] as List).cast<Map<String, dynamic>>());
        _hasMore = result['has_more'] as bool;
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    } finally {
      if (mounted) {
        setState(() {
          _loadingMore = false;
        });
      }
    }
  }

  Widget _buildEntry(Map<String, dynamic> item) {
    final reflection = (item['reflection'] as String? ?? '').trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F3EC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDE4D8)),
      ),
      child: ExpansionTile(
        key: ValueKey(item['id']),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: _teal,
        collapsedIconColor: _teal,
        leading: const Icon(Icons.check_circle_outline, color: _teal),
        title: Text(
          item['title'] as String,
          style: const TextStyle(
            color: _text,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'أُكمل في ${_completionDate(item['completed_at'] as String)}',
            style: const TextStyle(color: _muted, fontSize: 13),
          ),
        ),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Divider(color: Color(0xFFE5DED3)),
              const SizedBox(height: 8),
              Text(
                item['instructions'] as String,
                style: const TextStyle(color: _muted, height: 1.7),
              ),
              const SizedBox(height: 18),
              const Text(
                'تجربتي',
                style: TextStyle(
                  color: _teal,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFCF7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SelectableText(
                  reflection.isEmpty
                      ? 'لم تُضف تجربة لهذا التحدّي.'
                      : reflection,
                  style: TextStyle(
                    color: reflection.isEmpty ? _muted : _text,
                    height: 1.8,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _teal));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: _load, child: const Text('إعادة المحاولة')),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: _teal,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
        children: [
          const Text(
            'خطواتك وتجاربك في ممارسة الكلام خارج التطبيق.',
            style: TextStyle(color: _muted, height: 1.7),
          ),
          const SizedBox(height: 20),
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  Icon(Icons.auto_stories_outlined, color: _teal, size: 44),
                  SizedBox(height: 16),
                  Text(
                    'تجربتك الأولى بانتظارك',
                    style: TextStyle(
                      color: _teal,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'بعد إكمال تحدّيك الواقعي، '
                    'ستجده هنا مع تجربتك إن أضفتها.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, height: 1.7),
                  ),
                ],
              ),
            )
          else
            ..._items.map(_buildEntry),
          if (_hasMore)
            TextButton(
              onPressed: _loadingMore ? null : _loadMore,
              child: _loadingMore
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: _teal,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('عرض المزيد', style: TextStyle(color: _teal)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFCFAF6),
        appBar: AppBar(
          title: const Text('تجاربي مع التحديات'),
          centerTitle: true,
          backgroundColor: const Color(0xFFFCFAF6),
          foregroundColor: _teal,
          surfaceTintColor: Colors.transparent,
        ),
        body: SafeArea(child: _buildBody()),
      ),
    );
  }
}
