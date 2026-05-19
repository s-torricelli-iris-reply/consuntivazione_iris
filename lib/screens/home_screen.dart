import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import 'admin_dashboard_screen.dart';
import 'calendar_screen.dart';
import 'manage_projects_screen.dart';
import 'profile_screen.dart';
import 'timesheet_screen.dart';
import 'vacation_requests_screen.dart';
import 'web_dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  int _webSelectedIndex = 0;
  late AnimationController _confettiController;
  bool _showConfetti = false;
  bool _confettiChecked = false;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _checkAndShowConfetti(bool isSalaryDay) {
    if (_confettiChecked) return;
    _confettiChecked = true;

    if (isSalaryDay && !_showConfetti) {
      setState(() {
        _showConfetti = true;
      });
      _confettiController.forward().then((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _showConfetti = false;
            });
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final dataService = context.watch<DataService>();
    final currentUser = authService.currentUser;
    final canViewTeamDashboard = authService.canViewTeamDashboard;
    final showProjectsTab =
        currentUser != null &&
        currentUser.role == UserRole.employee &&
        dataService.canCreateProjectsForUser(currentUser);
    final now = DateTime.now();
    final salaryDay = dataService.getLastWorkingDay(now);
    final isSalaryDay = DateUtils.isSameDay(DateUtils.dateOnly(now), salaryDay);
    final isWideLayout = MediaQuery.sizeOf(context).width >= 1100;

    // Mostra confetti solo al primo build se è il giorno dello stipendio
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowConfetti(isSalaryDay);
    });

    final mobileScreens = <Widget>[
      const TimeSheetScreen(),
      const CalendarScreen(),
      const VacationRequestsScreen(),
      if (showProjectsTab) const ManageProjectsScreen(),
      if (canViewTeamDashboard) const AdminDashboardScreen(),
      const ProfileScreen(),
    ];

    final mobileNavItems = <_DockNavItemData>[
      const _DockNavItemData(
        icon: Icons.bolt_rounded,
        activeIcon: Icons.bolt,
        gradient: LinearGradient(
          colors: [Color(0xFF1757FF), Color(0xFF07C5C9)],
        ),
      ),
      const _DockNavItemData(
        icon: Icons.calendar_month_outlined,
        activeIcon: Icons.calendar_month,
        gradient: LinearGradient(
          colors: [Color(0xFF00A6FB), Color(0xFF05D5E8)],
        ),
      ),
      const _DockNavItemData(
        icon: Icons.beach_access_outlined,
        activeIcon: Icons.beach_access,
        gradient: LinearGradient(
          colors: [Color(0xFF16A34A), Color(0xFF06B6D4)],
        ),
      ),
      if (canViewTeamDashboard)
        const _DockNavItemData(
          icon: Icons.insights_outlined,
          activeIcon: Icons.insights,
          gradient: LinearGradient(
            colors: [Color(0xFFFF7A18), Color(0xFFFFB703)],
          ),
        ),
      if (showProjectsTab)
        const _DockNavItemData(
          icon: Icons.folder_open_outlined,
          activeIcon: Icons.folder_open,
          gradient: LinearGradient(
            colors: [Color(0xFF1958FF), Color(0xFF06B6D4)],
          ),
        ),
      const _DockNavItemData(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person,
        gradient: LinearGradient(
          colors: [Color(0xFF7B61FF), Color(0xFFB06CFF)],
        ),
      ),
    ];

    if (isWideLayout) {
      final teamTabIndex = showProjectsTab ? 5 : 4;
      final profileTabIndex = showProjectsTab || canViewTeamDashboard ? 5 : 4;

      final webScreens = <Widget>[
        WebDashboardScreen(
          onOpenTimesheet: () {
            setState(() {
              _webSelectedIndex = 1;
            });
          },
          onOpenCalendar: () {
            setState(() {
              _webSelectedIndex = 2;
            });
          },
          onOpenTeam: canViewTeamDashboard
              ? () {
                  setState(() {
                    _webSelectedIndex = teamTabIndex;
                  });
                }
              : null,
          onOpenProfile: () {
            setState(() {
              _webSelectedIndex = profileTabIndex;
            });
          },
        ),
        const TimeSheetScreen(),
        const CalendarScreen(),
        const VacationRequestsScreen(),
        if (showProjectsTab) const ManageProjectsScreen(),
        if (canViewTeamDashboard) const AdminDashboardScreen(),
        const ProfileScreen(),
      ];

      final webNavItems = <_WebNavItemData>[
        const _WebNavItemData(
          icon: Icons.grid_view_rounded,
          activeIcon: Icons.grid_view,
          label: 'Dashboard',
          gradient: LinearGradient(
            colors: [Color(0xFF1757FF), Color(0xFF07C5C9)],
          ),
        ),
        const _WebNavItemData(
          icon: Icons.bolt_outlined,
          activeIcon: Icons.bolt,
          label: 'Consuntivi',
          gradient: LinearGradient(
            colors: [Color(0xFF00A6FB), Color(0xFF05D5E8)],
          ),
        ),
        const _WebNavItemData(
          icon: Icons.calendar_month_outlined,
          activeIcon: Icons.calendar_month,
          label: 'Calendario',
          gradient: LinearGradient(
            colors: [Color(0xFF42A5F5), Color(0xFF26C6DA)],
          ),
        ),
        const _WebNavItemData(
          icon: Icons.beach_access_outlined,
          activeIcon: Icons.beach_access,
          label: 'Ferie',
          gradient: LinearGradient(
            colors: [Color(0xFF16A34A), Color(0xFF06B6D4)],
          ),
        ),
        if (canViewTeamDashboard)
          const _WebNavItemData(
            icon: Icons.insights_outlined,
            activeIcon: Icons.insights,
            label: 'Team',
            gradient: LinearGradient(
              colors: [Color(0xFFFF7A18), Color(0xFFFFB703)],
            ),
          ),
        if (showProjectsTab)
          const _WebNavItemData(
            icon: Icons.folder_open_outlined,
            activeIcon: Icons.folder_open,
            label: 'Progetti',
            gradient: LinearGradient(
              colors: [Color(0xFF1958FF), Color(0xFF06B6D4)],
            ),
          ),
        const _WebNavItemData(
          icon: Icons.person_outline,
          activeIcon: Icons.person,
          label: 'Profilo',
          gradient: LinearGradient(
            colors: [Color(0xFF7B61FF), Color(0xFFB06CFF)],
          ),
        ),
      ];

      final effectiveWebIndex = _webSelectedIndex >= webScreens.length
          ? webScreens.length - 1
          : _webSelectedIndex;
      if (effectiveWebIndex != _webSelectedIndex) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          setState(() {
            _webSelectedIndex = effectiveWebIndex;
          });
        });
      }

      return Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: AppTheme.appBackgroundGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Row(
                children: [
                  _WebSidebarNav(
                    items: webNavItems,
                    selectedIndex: effectiveWebIndex,
                    onTap: (index) {
                      setState(() {
                        _webSelectedIndex = index;
                      });
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: const Color(0xFFDCE8F9)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(26),
                        child: Stack(
                          children: [
                            StreamBuilder<int>(
                              stream: dataService.realtimeTickStream,
                              initialData: dataService.realtimeTick,
                              builder: (context, _) {
                                return AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 420),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  transitionBuilder: (child, animation) {
                                    final slide = Tween<Offset>(
                                      begin: const Offset(0.04, 0),
                                      end: Offset.zero,
                                    ).animate(animation);
                                    return FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: slide,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: KeyedSubtree(
                                    key: ValueKey<int>(effectiveWebIndex),
                                    child: webScreens[effectiveWebIndex],
                                  ),
                                );
                              },
                            ),
                            if (_showConfetti)
                              _ConfettiOverlay(controller: _confettiController),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final effectiveIndex = _selectedIndex >= mobileScreens.length
        ? mobileScreens.length - 1
        : _selectedIndex;
    if (effectiveIndex != _selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _selectedIndex = effectiveIndex;
        });
      });
    }

    return Scaffold(
      body: Stack(
        children: [
          StreamBuilder<int>(
            stream: dataService.realtimeTickStream,
            initialData: dataService.realtimeTick,
            builder: (context, _) {
              return RefreshIndicator(
                onRefresh: () async {
                  final auth = context.read<AuthService>();
                  final data = context.read<DataService>();
                  await auth.refreshCurrentUserFromRemote();
                  await data.refreshFromRemote();
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 420),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final slide = Tween<Offset>(
                      begin: const Offset(0.06, 0),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: slide, child: child),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<int>(effectiveIndex),
                    child: mobileScreens[effectiveIndex],
                  ),
                ),
              );
            },
          ),
          if (_showConfetti) _ConfettiOverlay(controller: _confettiController),
        ],
      ),
      bottomNavigationBar: _AnimatedDockBar(
        items: mobileNavItems,
        selectedIndex: effectiveIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}

class _AnimatedDockBar extends StatelessWidget {
  final List<_DockNavItemData> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _AnimatedDockBar({
    required this.items,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const barHeight = 66.0;
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Container(
        height: barHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF101216),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth / items.length;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  left: selectedIndex * itemWidth,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: itemWidth,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: items[selectedIndex].gradient,
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: List.generate(items.length, (index) {
                    final isSelected = index == selectedIndex;
                    final item = items[index];

                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onTap(index),
                        child: Center(
                          child: AnimatedScale(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            scale: isSelected ? 1.12 : 1,
                            child: Icon(
                              isSelected ? item.activeIcon : item.icon,
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.7),
                              size: isSelected ? 25 : 22,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WebSidebarNav extends StatelessWidget {
  final List<_WebNavItemData> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _WebSidebarNav({
    required this.items,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      decoration: BoxDecoration(
        color: const Color(0xFF101216),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 14),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF7A18), Color(0xFFFFB703)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.query_stats_rounded, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: List.generate(items.length, (index) {
                  final item = items[index];
                  final isSelected = index == selectedIndex;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Tooltip(
                      message: item.label,
                      child: GestureDetector(
                        onTap: () => onTap(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          width: isSelected ? 64 : 52,
                          height: isSelected ? 64 : 52,
                          decoration: BoxDecoration(
                            gradient: isSelected ? item.gradient : null,
                            color: isSelected ? null : Colors.transparent,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.28)
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Icon(
                            isSelected ? item.activeIcon : item.icon,
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.76),
                            size: isSelected ? 26 : 23,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ConfettiOverlay extends StatelessWidget {
  final AnimationController controller;

  const _ConfettiOverlay({required this.controller});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _ConfettiPainter(animation: controller.value),
          );
        },
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double animation;
  final List<_Confetti> confetti;

  _ConfettiPainter({required this.animation})
    : confetti = List.generate(
        50,
        (i) => _Confetti(
          seed: i,
          colors: [
            const Color(0xFFFF7A18),
            const Color(0xFFFFB703),
            const Color(0xFF05D5E8),
            const Color(0xFF1757FF),
            const Color(0xFF7B61FF),
          ],
        ),
      );

  @override
  void paint(Canvas canvas, Size size) {
    for (final c in confetti) {
      c.paint(canvas, size, animation);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _Confetti {
  final int seed;
  final List<Color> colors;
  late final double x;
  late final double rotation;
  late final double rotationSpeed;
  late final Color color;
  late final double size;
  late final double speed;

  _Confetti({required this.seed, required this.colors}) {
    final random = math.Random(seed);
    x = random.nextDouble();
    rotation = random.nextDouble() * math.pi * 2;
    rotationSpeed = (random.nextDouble() - 0.5) * 4;
    color = colors[random.nextInt(colors.length)];
    size = 8 + random.nextDouble() * 6;
    speed = 0.6 + random.nextDouble() * 0.4;
  }

  void paint(Canvas canvas, Size size, double t) {
    final y = t * speed;
    if (y > 1.0) return;

    final xPos = x * size.width;
    final yPos = y * size.height;
    final angle = rotation + t * rotationSpeed * math.pi * 2;

    canvas.save();
    canvas.translate(xPos, yPos);
    canvas.rotate(angle);

    final paint = Paint()..color = color;
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: this.size,
      height: this.size * 0.6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      paint,
    );

    canvas.restore();
  }
}

class _DockNavItemData {
  final IconData icon;
  final IconData activeIcon;
  final Gradient gradient;

  const _DockNavItemData({
    required this.icon,
    required this.activeIcon,
    required this.gradient,
  });
}

class _WebNavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Gradient gradient;

  const _WebNavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.gradient,
  });
}
