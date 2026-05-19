import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/project_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_reveal.dart';
import 'person_detail_screen.dart';
import 'project_detail_screen.dart';

class WebDashboardScreen extends StatelessWidget {
  final VoidCallback? onOpenTimesheet;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenTeam;
  final VoidCallback? onOpenProfile;

  const WebDashboardScreen({
    super.key,
    this.onOpenTimesheet,
    this.onOpenCalendar,
    this.onOpenTeam,
    this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final dataService = context.watch<DataService>();
    final currentUser = authService.currentUser;

    if (currentUser == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    final salaryDay = dataService.getLastWorkingDay(now);
    final isSalaryDay = DateUtils.isSameDay(DateUtils.dateOnly(now), salaryDay);

    final visibleProjects = dataService.getProjectsVisibleForUser(currentUser);
    final projectIds = visibleProjects.map((project) => project.id).toSet();
    final teamMembers = (switch (currentUser.role) {
      UserRole.admin =>
        dataService.users
            .where(
              (u) =>
                  u.isActive &&
                  (u.role != UserRole.admin ||
                      dataService.isTeamContributor(u)),
            )
            .toList(),
      UserRole.manager =>
        dataService.users
            .where((u) => u.isActive && u.role != UserRole.admin)
            .toList(),
      UserRole.teamLead => dataService.getDevelopersForTeamLead(currentUser.id),
      UserRole.employee => <User>[currentUser],
    })..sort((a, b) => a.fullName.compareTo(b.fullName));

    final currentUserHours = dataService
        .getEntriesForUser(currentUser.id, monthStart, monthEnd)
        .fold<double>(0, (sum, entry) => sum + entry.hours);
    final currentUserPerfectDays = dataService.getPerfectDaysCount(
      userId: currentUser.id,
      startDate: monthStart,
      endDate: monthEnd,
    );
    final currentUserStreak = dataService.getCurrentStreak(currentUser.id);
    final monthlyXp = dataService.getMonthlyExperience(currentUser.id, now);

    final trackedEnd = now.isBefore(monthEnd) ? now : monthEnd;
    final targetHoursPerMember =
        dataService.getWorkingDaysInRange(monthStart, trackedEnd) * 8.0;

    final projectHours = <String, double>{};
    final last7Days = <DateTime, double>{};
    final trendStart = DateUtils.dateOnly(
      now.subtract(const Duration(days: 6)),
    );
    final trendEnd = DateUtils.dateOnly(now);

    for (final project in visibleProjects) {
      projectHours[project.id] = 0;
    }

    for (final entry in dataService.timesheetEntries) {
      if (!projectIds.contains(entry.projectId)) {
        continue;
      }

      if (!entry.date.isBefore(monthStart) && !entry.date.isAfter(monthEnd)) {
        projectHours[entry.projectId] =
            (projectHours[entry.projectId] ?? 0) + entry.hours;
      }

      final entryDay = DateUtils.dateOnly(entry.date);
      if (!entryDay.isBefore(trendStart) && !entryDay.isAfter(trendEnd)) {
        last7Days[entryDay] = (last7Days[entryDay] ?? 0) + entry.hours;
      }
    }

    final topProjects = projectHours.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final teamRows = teamMembers.map((member) {
      final hours = dataService
          .getEntriesForUser(member.id, monthStart, monthEnd)
          .fold<double>(0, (sum, entry) => sum + entry.hours);
      return _TeamHourRow(user: member, hours: hours);
    }).toList()..sort((a, b) => b.hours.compareTo(a.hours));

    final totalVisibleHours = projectHours.values.fold<double>(
      0,
      (sum, value) => sum + value,
    );
    final monthReference = DateTime(now.year, now.month, 1);
    final kpiUsers = switch (currentUser.role) {
      UserRole.admin => teamMembers,
      UserRole.manager => teamMembers,
      UserRole.teamLead => dataService.getDevelopersForTeamLead(currentUser.id),
      UserRole.employee => <User>[currentUser],
    };
    final monthlyKpi = dataService.getMonthlyKpiForUsers(
      users: kpiUsers,
      monthReference: monthReference,
    );

    final economicRows =
        visibleProjects
            .map((project) {
              final cost = dataService.getProjectConsumedCost(
                project.id,
                startDate: monthStart,
                endDate: monthEnd,
              );
              final revenue = dataService.getProjectEstimatedRevenue(
                project.id,
                startDate: monthStart,
                endDate: monthEnd,
              );
              final margin = dataService.getProjectGrossMargin(
                project.id,
                startDate: monthStart,
                endDate: monthEnd,
              );
              return _WebProjectEconomicRow(
                projectName: project.name,
                consumedCost: cost,
                estimatedRevenue: revenue,
                grossMargin: margin,
              );
            })
            .where(
              (row) =>
                  row.consumedCost > 0 ||
                  row.estimatedRevenue > 0 ||
                  row.grossMargin != 0,
            )
            .toList()
          ..sort((a, b) => b.consumedCost.compareTo(a.consumedCost));

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppTheme.appBackgroundGradient),
      child: RefreshIndicator(
        onRefresh: () async {
          await authService.refreshCurrentUserFromRemote();
          await dataService.refreshFromRemote();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedReveal(
                    delay: const Duration(milliseconds: 50),
                    child: _WebHeroCard(
                      user: currentUser,
                      isSalaryDay: isSalaryDay,
                      salaryDay: salaryDay,
                      onOpenTimesheet: onOpenTimesheet,
                      onOpenCalendar: onOpenCalendar,
                      onOpenTeam: onOpenTeam,
                      onOpenProfile: onOpenProfile,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (currentUser.role != UserRole.employee) ...[
                    AnimatedReveal(
                      delay: const Duration(milliseconds: 85),
                      child: _WebOfficialKpiPanel(kpi: monthlyKpi),
                    ),
                    const SizedBox(height: 12),
                  ],
                  AnimatedReveal(
                    delay: const Duration(milliseconds: 100),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _MetricTile(
                          title: 'Ore mese',
                          value: currentUserHours.toStringAsFixed(1),
                          subtitle: 'Tuo totale',
                          icon: Icons.timer_outlined,
                          color: const Color(0xFF1958FF),
                        ),
                        _MetricTile(
                          title: 'Progetti visibili',
                          value: '${visibleProjects.length}',
                          subtitle: 'Attivi',
                          icon: Icons.folder_open_outlined,
                          color: const Color(0xFFFF7A18),
                        ),
                        _MetricTile(
                          title: 'Streak',
                          value: '$currentUserStreak',
                          subtitle: 'giorni perfetti',
                          icon: Icons.local_fire_department_outlined,
                          color: const Color(0xFF06A77D),
                        ),
                        _MetricTile(
                          title: 'XP mese',
                          value: '$monthlyXp',
                          subtitle: 'progressione',
                          icon: Icons.stars_outlined,
                          color: const Color(0xFF6A35FF),
                        ),
                        _MetricTile(
                          title: 'Membri team',
                          value: '${teamMembers.length}',
                          subtitle: currentUser.role.displayName,
                          icon: Icons.groups_2_outlined,
                          color: const Color(0xFF2E3440),
                        ),
                        _MetricTile(
                          title: 'Giorni perfetti',
                          value: '$currentUserPerfectDays',
                          subtitle: DateFormat('MMMM', 'it').format(now),
                          icon: Icons.verified_outlined,
                          color: const Color(0xFFB66A29),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final twoColumns = constraints.maxWidth >= 1120;
                      if (!twoColumns) {
                        return Column(
                          children: [
                            AnimatedReveal(
                              delay: const Duration(milliseconds: 140),
                              child: _ProjectDistributionCard(
                                projects: visibleProjects,
                                projectHours: projectHours,
                                totalHours: totalVisibleHours,
                                parseColor: _parseColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            AnimatedReveal(
                              delay: const Duration(milliseconds: 160),
                              child: _TrendCard(last7Days: last7Days, now: now),
                            ),
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: AnimatedReveal(
                              delay: const Duration(milliseconds: 140),
                              child: _ProjectDistributionCard(
                                projects: visibleProjects,
                                projectHours: projectHours,
                                totalHours: totalVisibleHours,
                                parseColor: _parseColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: AnimatedReveal(
                              delay: const Duration(milliseconds: 160),
                              child: _TrendCard(last7Days: last7Days, now: now),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  if (currentUser.role != UserRole.employee &&
                      economicRows.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    AnimatedReveal(
                      delay: const Duration(milliseconds: 180),
                      child: _WebEconomicPanel(rows: economicRows),
                    ),
                  ],
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final twoColumns = constraints.maxWidth >= 1120;
                      final projectPanel = _ProjectListCard(
                        projects: visibleProjects,
                        topProjects: topProjects,
                        parseColor: _parseColor,
                      );
                      final peoplePanel = _TeamFocusCard(
                        rows: teamRows,
                        targetHoursPerMember: targetHoursPerMember,
                      );

                      if (!twoColumns) {
                        return Column(
                          children: [
                            AnimatedReveal(
                              delay: const Duration(milliseconds: 200),
                              child: projectPanel,
                            ),
                            const SizedBox(height: 12),
                            AnimatedReveal(
                              delay: const Duration(milliseconds: 230),
                              child: peoplePanel,
                            ),
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: AnimatedReveal(
                              delay: const Duration(milliseconds: 200),
                              child: projectPanel,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: AnimatedReveal(
                              delay: const Duration(milliseconds: 230),
                              child: peoplePanel,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }
}

class _WebHeroCard extends StatelessWidget {
  final User user;
  final bool isSalaryDay;
  final DateTime salaryDay;
  final VoidCallback? onOpenTimesheet;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenTeam;
  final VoidCallback? onOpenProfile;

  const _WebHeroCard({
    required this.user,
    required this.isSalaryDay,
    required this.salaryDay,
    required this.onOpenTimesheet,
    required this.onOpenCalendar,
    required this.onOpenTeam,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy', 'it').format(DateTime.now());
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E1118), Color(0xFF2A3040), Color(0xFF1B6EF3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1958FF).withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Dashboard ${user.role.displayName} • $monthLabel',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isSalaryDay
                      ? 'Oggi stipendio'
                      : 'Stipendio ${DateFormat('d MMM', 'it').format(salaryDay)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Vista web ottimizzata con dati real-time, mantenendo stile e UX dell\'app.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroAction(
                icon: Icons.bolt_rounded,
                label: 'Consuntiva',
                onTap: onOpenTimesheet,
              ),
              _HeroAction(
                icon: Icons.calendar_month_outlined,
                label: 'Calendario',
                onTap: onOpenCalendar,
              ),
              _HeroAction(
                icon: Icons.groups_outlined,
                label: 'Team',
                onTap: onOpenTeam,
              ),
              _HeroAction(
                icon: Icons.person_outline,
                label: 'Profilo',
                onTap: onOpenProfile,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _HeroAction({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MetricTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 210),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFDCE8F9)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: AppTheme.heading3.copyWith(fontSize: 20)),
                  Text(title, style: AppTheme.bodySmall),
                  Text(
                    subtitle,
                    style: AppTheme.caption.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectDistributionCard extends StatelessWidget {
  final List<Project> projects;
  final Map<String, double> projectHours;
  final double totalHours;
  final Color Function(String) parseColor;

  const _ProjectDistributionCard({
    required this.projects,
    required this.projectHours,
    required this.totalHours,
    required this.parseColor,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = projectHours.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.where((entry) => entry.value > 0).take(5).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE8F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Distribuzione ore per progetto',
                  style: AppTheme.heading3,
                ),
              ),
              Text(
                'Totale ${totalHours.toStringAsFixed(1)}h',
                style: AppTheme.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (totalHours <= 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Nessuna ora disponibile per la distribuzione.',
                style: AppTheme.bodyMedium,
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 220,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: top.map((entry) {
                          final project = projects.firstWhere(
                            (item) => item.id == entry.key,
                          );
                          final pct = ((entry.value / totalHours) * 100)
                              .round()
                              .clamp(1, 100);
                          return PieChartSectionData(
                            value: math.max(entry.value, 0.1),
                            title: '$pct%',
                            radius: 60,
                            color: parseColor(project.color),
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: top.map((entry) {
                      final project = projects.firstWhere(
                        (item) => item.id == entry.key,
                      );
                      final color = parseColor(project.color);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                project.name,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${((entry.value / totalHours) * 100).toStringAsFixed(0)}% • ${entry.value.toStringAsFixed(1)}h',
                              style: AppTheme.caption,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  final Map<DateTime, double> last7Days;
  final DateTime now;

  const _TrendCard({required this.last7Days, required this.now});

  @override
  Widget build(BuildContext context) {
    final start = DateUtils.dateOnly(now.subtract(const Duration(days: 6)));
    final days = List<DateTime>.generate(
      7,
      (index) => start.add(Duration(days: index)),
    );
    final maxY = days.fold<double>(
      8.0,
      (maxValue, day) => math.max(maxValue, (last7Days[day] ?? 0) + 2),
    );
    final total = last7Days.values.fold<double>(0, (sum, value) => sum + value);
    final avg = total / days.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE8F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Trend ore ultimi 7 giorni', style: AppTheme.heading3),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _LegendPill(
                color: const Color(0xFF1958FF),
                text: 'Ore giornaliere',
              ),
              Text(
                'Media ${avg.toStringAsFixed(1)}h',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: math.max(2, (maxY / 4).ceilToDouble()),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          value.toStringAsFixed(0),
                          style: AppTheme.caption,
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= days.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            DateFormat('E', 'it').format(days[index]),
                            style: AppTheme.caption,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: days.asMap().entries.map((entry) {
                  final value = last7Days[entry.value] ?? 0;
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: value,
                        width: 16,
                        borderRadius: BorderRadius.circular(7),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1958FF), Color(0xFF05D5E8)],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectListCard extends StatelessWidget {
  final List<Project> projects;
  final List<MapEntry<String, double>> topProjects;
  final Color Function(String) parseColor;

  const _ProjectListCard({
    required this.projects,
    required this.topProjects,
    required this.parseColor,
  });

  @override
  Widget build(BuildContext context) {
    final shortlist = topProjects.take(5).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE8F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Progetti in focus', style: AppTheme.heading3),
          const SizedBox(height: 10),
          if (projects.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'Nessun progetto visibile con il ruolo corrente.',
                style: AppTheme.bodyMedium,
              ),
            )
          else ...[
            for (final item in shortlist)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Builder(
                  builder: (context) {
                    final project = projects.firstWhere(
                      (element) => element.id == item.key,
                    );
                    final color = parseColor(project.color);
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ProjectDetailScreen(projectId: project.id),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5EDF9)),
                          color: Colors.white,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                project.name,
                                style: AppTheme.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              '${item.value.toStringAsFixed(1)}h',
                              style: AppTheme.bodySmall.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right, size: 16),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _WebOfficialKpiPanel extends StatelessWidget {
  final TeamMonthlyKpi kpi;

  const _WebOfficialKpiPanel({required this.kpi});

  @override
  Widget build(BuildContext context) {
    final completion = (kpi.completionRate * 100).toStringAsFixed(0);
    final saturation = (kpi.saturationRate * 100).toStringAsFixed(0);
    final quality = (kpi.qualityScore * 100).toStringAsFixed(0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE8F9)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _KpiChip(
            label: 'Completion',
            value: '$completion%',
            alert: kpi.completionRate < 0.85,
          ),
          _KpiChip(
            label: 'Saturazione',
            value: '$saturation%',
            alert: kpi.saturationRate > 1.10 || kpi.saturationRate < 0.70,
          ),
          _KpiChip(
            label: 'Over/Under',
            value: '${kpi.overtimeUnderTimeHours.toStringAsFixed(1)}h',
            alert: false,
          ),
          _KpiChip(
            label: 'DSO',
            value: '${kpi.dsoAverageDays.toStringAsFixed(2)} gg',
            alert: kpi.dsoAverageDays > 1.0,
          ),
          _KpiChip(
            label: 'Quality',
            value: '$quality%',
            alert: kpi.qualityScore < 0.70,
          ),
        ],
      ),
    );
  }
}

class _KpiChip extends StatelessWidget {
  final String label;
  final String value;
  final bool alert;

  const _KpiChip({
    required this.label,
    required this.value,
    required this.alert,
  });

  @override
  Widget build(BuildContext context) {
    final color = alert ? AppTheme.errorColor : AppTheme.primaryColor;
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTheme.caption),
          Text(
            value,
            style: AppTheme.bodyLarge.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _WebProjectEconomicRow {
  final String projectName;
  final double consumedCost;
  final double estimatedRevenue;
  final double grossMargin;

  const _WebProjectEconomicRow({
    required this.projectName,
    required this.consumedCost,
    required this.estimatedRevenue,
    required this.grossMargin,
  });
}

class _WebEconomicPanel extends StatelessWidget {
  final List<_WebProjectEconomicRow> rows;

  const _WebEconomicPanel({required this.rows});

  @override
  Widget build(BuildContext context) {
    final totalCost = rows.fold<double>(
      0,
      (sum, row) => sum + row.consumedCost,
    );
    final totalRevenue = rows.fold<double>(
      0,
      (sum, row) => sum + row.estimatedRevenue,
    );
    final totalMargin = rows.fold<double>(
      0,
      (sum, row) => sum + row.grossMargin,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE8F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Economico mese (stima)', style: AppTheme.heading3),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _LegendPill(
                color: const Color(0xFF1958FF),
                text: 'Costo ${totalCost.toStringAsFixed(0)}€',
              ),
              _LegendPill(
                color: const Color(0xFF06A77D),
                text: 'Ricavo ${totalRevenue.toStringAsFixed(0)}€',
              ),
              _LegendPill(
                color: totalMargin >= 0
                    ? const Color(0xFF22C55E)
                    : AppTheme.errorColor,
                text: 'Margine ${totalMargin.toStringAsFixed(0)}€',
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...rows
              .take(5)
              .map(
                (row) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE7EEF9)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.projectName,
                          style: AppTheme.bodySmall.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        'C ${row.consumedCost.toStringAsFixed(0)}€',
                        style: AppTheme.caption,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'R ${row.estimatedRevenue.toStringAsFixed(0)}€',
                        style: AppTheme.caption,
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _LegendPill extends StatelessWidget {
  final Color color;
  final String text;

  const _LegendPill({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(text, style: AppTheme.caption),
        ],
      ),
    );
  }
}

class _TeamFocusCard extends StatelessWidget {
  final List<_TeamHourRow> rows;
  final double targetHoursPerMember;

  const _TeamFocusCard({
    required this.rows,
    required this.targetHoursPerMember,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE8F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Team snapshot', style: AppTheme.heading3),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'Nessuna persona nel perimetro attuale.',
                style: AppTheme.bodyMedium,
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktopTable = constraints.maxWidth >= 680;
                if (isDesktopTable) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Persona')),
                        DataColumn(label: Text('Ruolo')),
                        DataColumn(label: Text('Ore')),
                        DataColumn(label: Text('Completion')),
                      ],
                      rows: rows.take(10).map((row) {
                        final completion = targetHoursPerMember <= 0
                            ? 0.0
                            : (row.hours / targetHoursPerMember).clamp(
                                0.0,
                                1.0,
                              );
                        return DataRow(
                          onSelectChanged: (_) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    PersonDetailScreen(userId: row.user.id),
                              ),
                            );
                          },
                          cells: [
                            DataCell(Text(row.user.fullName)),
                            DataCell(Text(row.user.role.displayName)),
                            DataCell(Text('${row.hours.toStringAsFixed(1)}h')),
                            DataCell(
                              Text('${(completion * 100).toStringAsFixed(0)}%'),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  );
                }

                return Column(
                  children: rows.take(8).map((row) {
                    final completion = targetHoursPerMember <= 0
                        ? 0.0
                        : (row.hours / targetHoursPerMember).clamp(0.0, 1.0);
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PersonDetailScreen(userId: row.user.id),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    row.user.fullName,
                                    style: AppTheme.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimaryColor,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${row.hours.toStringAsFixed(1)}h',
                                  style: AppTheme.bodySmall.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: completion,
                                minHeight: 8,
                                backgroundColor: AppTheme.surfaceMutedColor,
                                color: completion >= 1
                                    ? AppTheme.successColor
                                    : AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _TeamHourRow {
  final User user;
  final double hours;

  const _TeamHourRow({required this.user, required this.hours});
}
