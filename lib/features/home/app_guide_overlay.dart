import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/theme/app_theme.dart';

class GuideStepItem {
  final String stepTag;
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final Color darkIconBgColor;
  final Color lightIconBgColor;
  final List<String> tags;

  const GuideStepItem({
    required this.stepTag,
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.darkIconBgColor,
    required this.lightIconBgColor,
    required this.tags,
  });
}

class AppGuideOverlay extends StatefulWidget {
  final VoidCallback onDismiss;

  const AppGuideOverlay({super.key, required this.onDismiss});

  static const String _flagFileName = 'hardcorez_guide_seen.flag';

  /// Mengecek apakah panduan perlu ditampilkan (hanya saat belum pernah dilihat)
  static Future<bool> shouldShowGuide() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final flagFile = File('${dir.path}/$_flagFileName');
      return !(await flagFile.exists());
    } catch (_) {
      return false;
    }
  }

  /// Menandai panduan sudah pernah dilihat
  static Future<void> markGuideSeen() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final flagFile = File('${dir.path}/$_flagFileName');
      await flagFile.writeAsString('seen');
    } catch (_) {}
  }

  /// Reset panduan (berguna untuk pengujian atau manual reset)
  static Future<void> resetGuide() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final flagFile = File('${dir.path}/$_flagFileName');
      if (await flagFile.exists()) {
        await flagFile.delete();
      }
    } catch (_) {}
  }

  @override
  State<AppGuideOverlay> createState() => _AppGuideOverlayState();
}

class _AppGuideOverlayState extends State<AppGuideOverlay>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final List<GuideStepItem> _steps = const [
    GuideStepItem(
      stepTag: 'LANGKAH 1 DARI 3',
      title: 'Modul Office Cepat',
      description:
          'Buat dan olah berkas secara 100% offline. Ketuk kartu Word untuk dokumen teks, Spreadsheet untuk tabel & formula Excel, Presentasi untuk slide deck, atau PDF Tools untuk baca & konversi berkas.',
      icon: Icons.dashboard_customize_rounded,
      iconColor: AppTheme.docBlue,
      darkIconBgColor: Color(0xFF1E293B),
      lightIconBgColor: Color(0xFFEEF2FF),
      tags: ['Word (.docx)', 'Excel (.xlsx)', 'Slide PPT', 'PDF Tools'],
    ),
    GuideStepItem(
      stepTag: 'LANGKAH 2 DARI 3',
      title: 'Pindai & Impor Berkas HP',
      description:
          'Gunakan kotak pencarian instan untuk menyaring dokumen, atau ketuk tombol folder untuk mengimpor berkas langsung dari memori internal HP. Filter dokumen berdasarkan kategori untuk kemudahan akses.',
      icon: Icons.folder_open_rounded,
      iconColor: Color(0xFF0284C7),
      darkIconBgColor: Color(0xFF0C4A6E),
      lightIconBgColor: Color(0xFFE0F2FE),
      tags: ['Pencarian Cepat', 'Pindai Berkas', 'Impor dari HP'],
    ),
    GuideStepItem(
      stepTag: 'LANGKAH 3 DARI 3',
      title: 'Tanda Tangan & Stempel Resmi',
      description:
          'Bubuhkan paraf digital dan stempel legalitas langsung pada dokumen tanpa perlu mencetak kertas. Cukup ketuk ikon menu opsi (⋮) pada kartu berkas apa pun lalu pilih "Tanda Tangan & Stempel".',
      icon: Icons.draw_rounded,
      iconColor: AppTheme.brandCrimson,
      darkIconBgColor: Color(0xFF450A0A),
      lightIconBgColor: Color(0xFFFEF2F2),
      tags: ['Paraf & TTD', 'Stempel Resmi', 'Ekspor & Bagikan'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _finishGuide() {
    widget.onDismiss();
    AppGuideOverlay.markGuideSeen();
  }

  void _nextPage() {
    if (_currentPage < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    } else {
      _finishGuide();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Material(
        color: Colors.black.withValues(alpha: isDark ? 0.75 : 0.50),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131B2E) : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF2E3D5C)
                          : const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.6)
                            : const Color(0xFF0F172A).withValues(alpha: 0.12),
                        blurRadius: 28,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: AppTheme.brandCrimson.withValues(
                          alpha: isDark ? 0.12 : 0.08,
                        ),
                        blurRadius: isDark ? 40 : 20,
                        spreadRadius: isDark ? 4 : 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Bar: Tag Badge & Skip Button
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 14, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.brandCrimson.withValues(
                                  alpha: isDark ? 0.18 : 0.10,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppTheme.brandCrimson.withValues(
                                    alpha: isDark ? 0.4 : 0.25,
                                  ),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 13,
                                    color: isDark
                                        ? const Color(0xFFF87171)
                                        : AppTheme.brandCrimson,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _steps[_currentPage].stepTag,
                                    style: TextStyle(
                                      color: isDark
                                          ? const Color(0xFFFCA5A5)
                                          : AppTheme.brandCrimson,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Skip/Close Button
                            IconButton(
                              onPressed: _finishGuide,
                              tooltip: 'Lewati Panduan',
                              icon: Icon(
                                Icons.close_rounded,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Swipeable PageView content
                      SizedBox(
                        height: 290,
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: _steps.length,
                          onPageChanged: (index) {
                            setState(() => _currentPage = index);
                          },
                          itemBuilder: (context, index) {
                            final step = _steps[index];
                            return SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Icon Badge with Glow
                                  Container(
                                    width: 58,
                                    height: 58,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? step.darkIconBgColor
                                          : step.lightIconBgColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: step.iconColor.withValues(
                                          alpha: isDark ? 0.5 : 0.35,
                                        ),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: step.iconColor.withValues(
                                            alpha: isDark ? 0.3 : 0.15,
                                          ),
                                          blurRadius: 14,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      step.icon,
                                      size: 28,
                                      color: step.iconColor,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Step Title
                                  Text(
                                    step.title,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Step Description
                                  Text(
                                    step.description,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF475569),
                                      fontSize: 12.5,
                                      height: 1.4,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Tags Chips
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    alignment: WrapAlignment.center,
                                    children: step.tags.map((tag) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF1E293B)
                                              : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: isDark
                                                ? const Color(0xFF334155)
                                                : const Color(0xFFE2E8F0),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          tag,
                                          style: TextStyle(
                                            color: isDark
                                                ? const Color(0xFFCBD5E1)
                                                : const Color(0xFF334155),
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Indicators & Navigation Action Buttons
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          children: [
                            // Dots Indicator
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(_steps.length, (index) {
                                final isActive = index == _currentPage;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 240),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  width: isActive ? 22 : 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? AppTheme.brandCrimson
                                        : (isDark
                                              ? const Color(0xFF334155)
                                              : const Color(0xFFCBD5E1)),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 18),

                            // Action Buttons Row
                            Row(
                              children: [
                                if (_currentPage > 0)
                                  Expanded(
                                    flex: 1,
                                    child: OutlinedButton(
                                      onPressed: _prevPage,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: isDark
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFF475569),
                                        side: BorderSide(
                                          color: isDark
                                              ? const Color(0xFF334155)
                                              : const Color(0xFFCBD5E1),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                      child: const Text(
                                        'Kembali',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Expanded(
                                    flex: 1,
                                    child: TextButton(
                                      onPressed: _finishGuide,
                                      child: Text(
                                        'Lewati',
                                        style: TextStyle(
                                          color: isDark
                                              ? const Color(0xFF94A3B8)
                                              : const Color(0xFF64748B),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFDC2626),
                                          Color(0xFF991B1B),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFDC2626)
                                              .withValues(
                                                alpha: isDark ? 0.35 : 0.25,
                                              ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: _nextPage,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            _currentPage == _steps.length - 1
                                                ? 'Mulai Bekerja'
                                                : 'Lanjut',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Icon(
                                            _currentPage == _steps.length - 1
                                                ? Icons.check_rounded
                                                : Icons.arrow_forward_rounded,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
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
