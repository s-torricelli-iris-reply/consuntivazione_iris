import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

import '../models/project_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../utils/web_download.dart';
import '../widgets/animated_reveal.dart';
import '../widgets/project_card.dart';
import '../widgets/stat_card.dart';
import 'manage_commesse_screen.dart';
import 'manage_projects_screen.dart';
import 'manage_users_screen.dart';
import 'person_detail_screen.dart';
import 'project_detail_screen.dart';
import 'team_overview_screen.dart';
import 'vacation_requests_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late DateTime _selectedMonth;
  String? _selectedTeamLeadFilterId;
  String? _selectedUserFilterId;
  String? _selectedProjectFilterId;
  DeveloperType? _selectedDeveloperTypeFilter;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + offset,
        1,
      );
    });
  }

  Future<void> _pickMonth(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      locale: const Locale('it'),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _selectedMonth = DateTime(picked.year, picked.month, 1);
    });
  }

  Future<void> _exportMonthlyReportCsv({
    required User viewer,
    required DateTime monthReference,
    required List<_UserMonthStat> userStats,
    required List<Project> projects,
    required DataService dataService,
  }) async {
    final monthLabel = DateFormat('yyyy-MM', 'it').format(monthReference);
    final buffer = StringBuffer()
      ..writeln(
        'mese;viewer;utente_id;utente_nome;utente_email;ruolo;progetto_id;progetto_nome;ore_totali_utente;ore_progetto_utente;giorni_perfetti;completion_pct',
      );

    final projectById = {for (final p in projects) p.id: p};
    final monthStart = DateTime(monthReference.year, monthReference.month, 1);
    final monthEnd = DateTime(monthReference.year, monthReference.month + 1, 0);

    for (final stat in userStats) {
      final byProject = dataService.getHoursByProjectForUser(
        stat.user.id,
        startDate: monthStart,
        endDate: monthEnd,
      );

      if (byProject.isEmpty) {
        buffer.writeln(
          '$monthLabel;${viewer.email};${stat.user.id};${_escapeCsv(stat.user.fullName)};${stat.user.email};${stat.user.role.displayName};;;'
          '${stat.totalHours.toStringAsFixed(1)};0.0;${stat.perfectDays};${(stat.completionRate * 100).round()}',
        );
        continue;
      }

      for (final entry in byProject.entries) {
        final project = projectById[entry.key];
        buffer.writeln(
          '$monthLabel;${viewer.email};${stat.user.id};${_escapeCsv(stat.user.fullName)};${stat.user.email};${stat.user.role.displayName};${entry.key};${_escapeCsv(project?.name ?? 'N/D')};${stat.totalHours.toStringAsFixed(1)};${entry.value.toStringAsFixed(1)};${stat.perfectDays};${(stat.completionRate * 100).round()}',
        );
      }
    }

    final fileName =
        'iris_report_${viewer.role.displayName.toLowerCase()}_${monthReference.year}_${monthReference.month.toString().padLeft(2, '0')}.csv';
    final content = buffer.toString();
    final downloaded = downloadTextFile(
      fileName: fileName,
      content: utf8.decode([0xEF, 0xBB, 0xBF]) + content,
      mimeType: 'text/csv;charset=utf-8',
    );

    if (!mounted) {
      return;
    }

    if (downloaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Export CSV avviato. Apribile con Excel.'),
        ),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: content));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'CSV copiato negli appunti (su questa piattaforma download non disponibile).',
        ),
      ),
    );
  }

  String _escapeCsv(String input) {
    if (!input.contains(';') && !input.contains('"') && !input.contains('\n')) {
      return input;
    }
    return '"${input.replaceAll('"', '""')}"';
  }

  Future<void> _exportMonthlyReportXlsx({
    required User viewer,
    required DateTime monthReference,
    required List<_UserMonthStat> userStats,
    required List<Project> projects,
    required DataService dataService,
  }) async {
    final workbook = xlsio.Workbook(4);
    final usersSheet = workbook.worksheets[0];
    usersSheet.name = 'Utenti';
    final projectsSheet = workbook.worksheets[1];
    projectsSheet.name = 'Progetti';
    final economicsSheet = workbook.worksheets[2];
    economicsSheet.name = 'Economico';
    final tlSummarySheet = workbook.worksheets[3];
    tlSummarySheet.name = 'Riepilogo TL';

    final monthStart = DateTime(monthReference.year, monthReference.month, 1);
    final monthEnd = DateTime(monthReference.year, monthReference.month + 1, 0);
    final monthLabel = DateFormat('yyyy-MM', 'it').format(monthReference);

    usersSheet.getRangeByName('A1').setText('Mese');
    usersSheet.getRangeByName('B1').setText('Utente');
    usersSheet.getRangeByName('C1').setText('Email');
    usersSheet.getRangeByName('D1').setText('Ruolo');
    usersSheet.getRangeByName('E1').setText('Ore Totali');
    usersSheet.getRangeByName('F1').setText('Giorni Perfetti');
    usersSheet.getRangeByName('G1').setText('Completion %');

    var userRow = 2;
    for (final stat in userStats) {
      usersSheet.getRangeByIndex(userRow, 1).setText(monthLabel);
      usersSheet.getRangeByIndex(userRow, 2).setText(stat.user.fullName);
      usersSheet.getRangeByIndex(userRow, 3).setText(stat.user.email);
      usersSheet
          .getRangeByIndex(userRow, 4)
          .setText(stat.user.role.displayName);
      usersSheet
          .getRangeByIndex(userRow, 5)
          .setNumber(stat.totalHours.toDouble());
      usersSheet
          .getRangeByIndex(userRow, 6)
          .setNumber(stat.perfectDays.toDouble());
      usersSheet
          .getRangeByIndex(userRow, 7)
          .setNumber((stat.completionRate * 100).toDouble());
      userRow++;
    }

    projectsSheet.getRangeByName('A1').setText('Mese');
    projectsSheet.getRangeByName('B1').setText('Progetto');
    projectsSheet.getRangeByName('C1').setText('Commessa');
    projectsSheet.getRangeByName('D1').setText('Ore Mese');
    projectsSheet.getRangeByName('E1').setText('Owner');
    projectsSheet.getRangeByName('F1').setText('TL');
    projectsSheet.getRangeByName('G1').setText('Contributors');

    var projectRow = 2;
    for (final project in projects) {
      final hours = dataService.getProjectTotalHours(
        project.id,
        startDate: monthStart,
        endDate: monthEnd,
      );
      final commessa = project.commessaId == null
          ? null
          : dataService.getCommessaById(project.commessaId!);
      final owner = project.ownerUserId == null
          ? null
          : dataService.getUserById(project.ownerUserId!);
      projectsSheet.getRangeByIndex(projectRow, 1).setText(monthLabel);
      projectsSheet.getRangeByIndex(projectRow, 2).setText(project.name);
      projectsSheet
          .getRangeByIndex(projectRow, 3)
          .setText(commessa?.codice ?? '');
      projectsSheet.getRangeByIndex(projectRow, 4).setNumber(hours);
      projectsSheet
          .getRangeByIndex(projectRow, 5)
          .setText(owner?.fullName ?? '');
      projectsSheet
          .getRangeByIndex(projectRow, 6)
          .setText(owner?.surname ?? '');
      projectsSheet
          .getRangeByIndex(projectRow, 7)
          .setNumber(project.assignedUserIds.length.toDouble());
      projectRow++;
    }

    tlSummarySheet.getRangeByName('A1').setText('Mese');
    tlSummarySheet.getRangeByName('B1').setText('TL');
    tlSummarySheet.getRangeByName('C1').setText('Progetto');
    tlSummarySheet.getRangeByName('D1').setText('Ore progetto');
    tlSummarySheet.getRangeByName('E1').setText('Membro team');
    tlSummarySheet.getRangeByName('F1').setText('Email membro');
    tlSummarySheet.getRangeByName('G1').setText('Ore membro su progetto');
    tlSummarySheet.getRangeByName('H1').setText('Ore totali membro mese');

    var summaryRow = 2;
    var grandTotal = 0.0;
    final projectsOrdered = projects.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    for (final project in projectsOrdered) {
      final projectEntries = dataService.getEntriesForProject(
        project.id,
        startDate: monthStart,
        endDate: monthEnd,
      );
      final projectTotal = projectEntries.fold<double>(
        0,
        (sum, entry) => sum + entry.hours,
      );
      if (projectTotal <= 0) {
        continue;
      }
      grandTotal += projectTotal;

      final owner = project.ownerUserId == null
          ? null
          : dataService.getUserById(project.ownerUserId!);
      final byUser = <String, double>{};
      for (final entry in projectEntries) {
        byUser[entry.userId] = (byUser[entry.userId] ?? 0) + entry.hours;
      }
      final rows = byUser.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (final userEntry in rows) {
        final member = dataService.getUserById(userEntry.key);
        final memberMonthTotal = dataService
            .getEntriesForUser(userEntry.key, monthStart, monthEnd)
            .fold<double>(0, (sum, entry) => sum + entry.hours);
        tlSummarySheet.getRangeByIndex(summaryRow, 1).setText(monthLabel);
        tlSummarySheet
            .getRangeByIndex(summaryRow, 2)
            .setText(owner?.fullName ?? 'TL non assegnato');
        tlSummarySheet.getRangeByIndex(summaryRow, 3).setText(project.name);
        tlSummarySheet.getRangeByIndex(summaryRow, 4).setNumber(projectTotal);
        tlSummarySheet
            .getRangeByIndex(summaryRow, 5)
            .setText(member?.fullName ?? userEntry.key);
        tlSummarySheet
            .getRangeByIndex(summaryRow, 6)
            .setText(member?.email ?? '');
        tlSummarySheet
            .getRangeByIndex(summaryRow, 7)
            .setNumber(userEntry.value);
        tlSummarySheet
            .getRangeByIndex(summaryRow, 8)
            .setNumber(memberMonthTotal);
        summaryRow++;
      }
    }
    tlSummarySheet.getRangeByIndex(summaryRow + 1, 3).setText('Totale ore');
    tlSummarySheet.getRangeByIndex(summaryRow + 1, 4).setNumber(grandTotal);

    economicsSheet.getRangeByName('A1').setText('Mese');
    economicsSheet.getRangeByName('B1').setText('Progetto');
    economicsSheet.getRangeByName('C1').setText('Costo Consuntivato');
    economicsSheet.getRangeByName('D1').setText('Ricavo Stimato');
    economicsSheet.getRangeByName('E1').setText('Margine Lordo');
    economicsSheet.getRangeByName('F1').setText('Burn Rate %');
    economicsSheet.getRangeByName('G1').setText('Forecast Costo Mese');

    var ecoRow = 2;
    for (final project in projects.where((p) => p.isBillable)) {
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
      final burnRate = dataService.getProjectBudgetBurnRate(
        project.id,
        startDate: monthStart,
        endDate: monthEnd,
      );
      final forecast = dataService.getProjectForecastMonthlyCost(
        project.id,
        monthReference,
      );

      economicsSheet.getRangeByIndex(ecoRow, 1).setText(monthLabel);
      economicsSheet.getRangeByIndex(ecoRow, 2).setText(project.name);
      economicsSheet.getRangeByIndex(ecoRow, 3).setNumber(cost);
      economicsSheet.getRangeByIndex(ecoRow, 4).setNumber(revenue);
      economicsSheet.getRangeByIndex(ecoRow, 5).setNumber(margin);
      economicsSheet.getRangeByIndex(ecoRow, 6).setNumber(burnRate * 100);
      economicsSheet.getRangeByIndex(ecoRow, 7).setNumber(forecast);
      ecoRow++;
    }

    final bytes = workbook.saveAsStream();
    workbook.dispose();

    final fileName =
        'iris_report_${viewer.role.displayName.toLowerCase()}_${monthReference.year}_${monthReference.month.toString().padLeft(2, '0')}.xlsx';
    final downloaded = downloadBinaryFile(fileName: fileName, bytes: bytes);

    if (!mounted) {
      return;
    }

    if (downloaded) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Export XLSX avviato.')));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Download XLSX non disponibile su questa piattaforma. Usa export CSV.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final dataService = context.watch<DataService>();
    final currentUser = authService.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final users = switch (currentUser.role) {
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
      UserRole.employee => <User>[],
    };
    final visibleTeamLeads = switch (currentUser.role) {
      UserRole.admin => dataService.getUsersByRole(UserRole.teamLead),
      UserRole.manager => dataService.getUsersByRole(UserRole.teamLead),
      UserRole.teamLead => <User>[],
      UserRole.employee => <User>[],
    };
    final allVisibleProjects = dataService.getProjectsVisibleForUser(
      currentUser,
    );

    final filterProjectOptions = allVisibleProjects.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final developerFilterOptions =
        users.where(dataService.isTeamContributor).toList()
          ..sort((a, b) => a.fullName.compareTo(b.fullName));

    String? effectiveTeamLeadFilterId = _selectedTeamLeadFilterId;
    if (effectiveTeamLeadFilterId != null &&
        !visibleTeamLeads.any((u) => u.id == effectiveTeamLeadFilterId)) {
      effectiveTeamLeadFilterId = null;
    }

    String? effectiveUserFilterId = _selectedUserFilterId;
    if (effectiveUserFilterId != null &&
        !developerFilterOptions.any((u) => u.id == effectiveUserFilterId)) {
      effectiveUserFilterId = null;
    }

    String? effectiveProjectFilterId = _selectedProjectFilterId;
    if (effectiveProjectFilterId != null &&
        !filterProjectOptions.any((p) => p.id == effectiveProjectFilterId)) {
      effectiveProjectFilterId = null;
    }

    if (effectiveTeamLeadFilterId != _selectedTeamLeadFilterId ||
        effectiveUserFilterId != _selectedUserFilterId ||
        effectiveProjectFilterId != _selectedProjectFilterId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _selectedTeamLeadFilterId = effectiveTeamLeadFilterId;
          _selectedUserFilterId = effectiveUserFilterId;
          _selectedProjectFilterId = effectiveProjectFilterId;
        });
      });
    }

    final now = DateTime.now();
    final monthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final monthEnd = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final isCurrentMonth =
        _selectedMonth.year == now.year && _selectedMonth.month == now.month;
    final trackedEnd = isCurrentMonth && now.isBefore(monthEnd)
        ? now
        : monthEnd;

    final elapsedWorkingDays = dataService.getWorkingDaysInRange(
      monthStart,
      trackedEnd,
    );
    final targetHoursPerUser = elapsedWorkingDays * 8.0;

    var filteredUsers = users.where((user) => user.isActive).toList();
    if (effectiveTeamLeadFilterId != null &&
        effectiveTeamLeadFilterId.trim().isNotEmpty) {
      final selectedTeamLeadId = effectiveTeamLeadFilterId;
      filteredUsers = filteredUsers
          .where(
            (user) =>
                dataService.isUserAssignedToTeamLead(user, selectedTeamLeadId),
          )
          .toList();
    }
    if (effectiveUserFilterId != null) {
      filteredUsers = filteredUsers
          .where((u) => u.id == effectiveUserFilterId)
          .toList();
    }
    if (_selectedDeveloperTypeFilter != null) {
      filteredUsers = filteredUsers
          .where((u) => u.developerType == _selectedDeveloperTypeFilter)
          .toList();
    }

    if (effectiveProjectFilterId != null) {
      final selectedProject = allVisibleProjects.firstWhere(
        (project) => project.id == effectiveProjectFilterId,
      );
      filteredUsers = filteredUsers.where((user) {
        if (selectedProject.assignedUserIds.contains(user.id)) {
          return true;
        }
        return dataService.hasUserWorkedOnProject(user.id, selectedProject.id);
      }).toList();
    }

    final teamMembers = filteredUsers;
    final projects = effectiveProjectFilterId == null
        ? allVisibleProjects
        : allVisibleProjects
              .where((project) => project.id == effectiveProjectFilterId)
              .toList();

    final userStats = filteredUsers.map((user) {
      var entries = dataService.getEntriesForUser(
        user.id,
        monthStart,
        monthEnd,
      );
      if (effectiveProjectFilterId != null) {
        entries = entries
            .where((entry) => entry.projectId == effectiveProjectFilterId)
            .toList();
      }
      final totalHours = entries.fold<double>(
        0,
        (sum, entry) => sum + entry.hours,
      );
      final perfectDays = dataService.getPerfectDaysCount(
        userId: user.id,
        startDate: monthStart,
        endDate: monthEnd,
      );
      final completionRate = targetHoursPerUser == 0
          ? 0.0
          : (totalHours / targetHoursPerUser).clamp(0.0, 1.5);

      return _UserMonthStat(
        user: user,
        totalHours: totalHours,
        perfectDays: perfectDays,
        completionRate: completionRate,
      );
    }).toList()..sort((a, b) => b.totalHours.compareTo(a.totalHours));

    final teamHours = userStats.fold<double>(
      0,
      (sum, stat) => sum + stat.totalHours,
    );
    final avgCompletion = userStats.isEmpty
        ? 0.0
        : userStats.fold<double>(0, (sum, stat) => sum + stat.completionRate) /
              userStats.length;
    final alertCount = userStats
        .where((stat) => stat.totalHours < (targetHoursPerUser * 0.75))
        .length;
    final topContributor = userStats.isEmpty ? null : userStats.first;
    final monthlyKpi = dataService.getMonthlyKpiForUsers(
      users: filteredUsers,
      monthReference: _selectedMonth,
    );

    final title = switch (currentUser.role) {
      UserRole.admin => 'Console Admin',
      UserRole.manager => 'Dashboard Manager',
      UserRole.teamLead => 'Dashboard Team Lead',
      UserRole.employee => 'Dashboard',
    };

    final visibleProjectIds = projects.map((project) => project.id).toSet();
    final filteredUserIds = filteredUsers.map((u) => u.id).toSet();
    final projectHours = <String, double>{};
    final projectHoursByUser = <String, Map<String, double>>{};
    final last7DaysDailyHours = <DateTime, double>{};
    final trendStart = DateUtils.dateOnly(
      now.subtract(const Duration(days: 6)),
    );

    for (final project in projects) {
      projectHours[project.id] = 0;
      projectHoursByUser[project.id] = <String, double>{};
    }

    for (final entry in dataService.timesheetEntries) {
      if (!visibleProjectIds.contains(entry.projectId)) {
        continue;
      }
      if (!filteredUserIds.contains(entry.userId)) {
        continue;
      }

      if (!entry.date.isBefore(monthStart) && !entry.date.isAfter(monthEnd)) {
        projectHours[entry.projectId] =
            (projectHours[entry.projectId] ?? 0) + entry.hours;
        final byUser =
            projectHoursByUser[entry.projectId] ?? <String, double>{};
        byUser[entry.userId] = (byUser[entry.userId] ?? 0) + entry.hours;
        projectHoursByUser[entry.projectId] = byUser;
      }

      final day = DateUtils.dateOnly(entry.date);
      if (!day.isBefore(trendStart) && !day.isAfter(DateUtils.dateOnly(now))) {
        last7DaysDailyHours[day] =
            (last7DaysDailyHours[day] ?? 0) + entry.hours;
      }
    }

    final economicRows =
        projects
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
              final burnRate = dataService.getProjectBudgetBurnRate(
                project.id,
                startDate: monthStart,
                endDate: monthEnd,
              );
              return _ProjectEconomicRow(
                project: project,
                consumedCost: cost,
                estimatedRevenue: revenue,
                grossMargin: margin,
                burnRate: burnRate,
              );
            })
            .where(
              (row) =>
                  row.project.isBillable ||
                  row.consumedCost > 0 ||
                  row.estimatedRevenue > 0,
            )
            .toList()
          ..sort((a, b) => b.consumedCost.compareTo(a.consumedCost));

    final totalConsumedCost = economicRows.fold<double>(
      0,
      (sum, row) => sum + row.consumedCost,
    );
    final totalEstimatedRevenue = economicRows.fold<double>(
      0,
      (sum, row) => sum + row.estimatedRevenue,
    );
    final totalGrossMargin = economicRows.fold<double>(
      0,
      (sum, row) => sum + row.grossMargin,
    );
    final quickActions = <_QuickActionConfig>[
      if (currentUser.role != UserRole.employee)
        _QuickActionConfig(
          title: authService.isAdmin ? 'Console utenti' : 'Permessi team',
          subtitle: authService.isAdmin
              ? 'Assegna ruoli, TL e membri team'
              : 'Designa chi può creare progetti',
          icon: Icons.admin_panel_settings_outlined,
          color: AppTheme.primaryColor,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManageUsersScreen()),
            );
          },
        ),
      _QuickActionConfig(
        title: 'Gestisci Progetti',
        subtitle: 'Aggiorna backlog progetti e assegnazioni',
        icon: Icons.folder_copy_outlined,
        color: AppTheme.secondaryColor,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ManageProjectsScreen()),
          );
        },
      ),
      if (currentUser.role != UserRole.employee)
        _QuickActionConfig(
          title: 'Commesse GECO',
          subtitle: 'Anagrafica commesse e stato',
          icon: Icons.business_center_outlined,
          color: AppTheme.accentColor,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManageCommesseScreen()),
            );
          },
        ),
      if (currentUser.role == UserRole.manager ||
          currentUser.role == UserRole.teamLead)
        _QuickActionConfig(
          title: 'Il mio team',
          subtitle: 'Vedi struttura e persone assegnate',
          icon: Icons.groups_outlined,
          color: AppTheme.successColor,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TeamOverviewScreen()),
            );
          },
        ),
      _QuickActionConfig(
        title: 'Richieste ferie',
        subtitle: 'Invia, approva e monitora assenze',
        icon: Icons.beach_access_outlined,
        color: AppTheme.successColor,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const VacationRequestsScreen()),
          );
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (currentUser.role != UserRole.employee)
            IconButton(
              tooltip: 'Gestisci commesse',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ManageCommesseScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.business_center_outlined),
            ),
          PopupMenuButton<String>(
            tooltip: 'Export report',
            onSelected: (value) {
              if (value == 'csv') {
                _exportMonthlyReportCsv(
                  viewer: currentUser,
                  monthReference: _selectedMonth,
                  userStats: userStats,
                  projects: projects,
                  dataService: dataService,
                );
              } else if (value == 'xlsx') {
                _exportMonthlyReportXlsx(
                  viewer: currentUser,
                  monthReference: _selectedMonth,
                  userStats: userStats,
                  projects: projects,
                  dataService: dataService,
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'xlsx', child: Text('Export XLSX')),
              PopupMenuItem(value: 'csv', child: Text('Export CSV')),
            ],
            icon: const Icon(Icons.download_outlined),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppTheme.appBackgroundGradient,
        ),
        child: RefreshIndicator(
          onRefresh: () async {
            final auth = context.read<AuthService>();
            final data = context.read<DataService>();
            await auth.refreshCurrentUserFromRemote();
            await data.refreshFromRemote();
          },
          child: StreamBuilder<int>(
            stream: dataService.realtimeTickStream,
            initialData: dataService.realtimeTick,
            builder: (context, _) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedReveal(
                    delay: const Duration(milliseconds: 40),
                    child: _MonthSelectorBar(
                      selectedMonth: _selectedMonth,
                      onPrevious: () => _changeMonth(-1),
                      onNext: () => _changeMonth(1),
                      onPickMonth: () => _pickMonth(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  AnimatedReveal(
                    delay: const Duration(milliseconds: 52),
                    child: _DashboardFilters(
                      visibleTeamLeads: visibleTeamLeads,
                      visibleUsers: developerFilterOptions,
                      visibleProjects: filterProjectOptions,
                      selectedTeamLeadId: effectiveTeamLeadFilterId,
                      selectedUserId: effectiveUserFilterId,
                      selectedProjectId: effectiveProjectFilterId,
                      selectedDeveloperType: _selectedDeveloperTypeFilter,
                      onTeamLeadChanged: (value) {
                        setState(() {
                          _selectedTeamLeadFilterId = value;
                          _selectedUserFilterId = null;
                        });
                      },
                      onUserChanged: (value) {
                        setState(() {
                          _selectedUserFilterId = value;
                        });
                      },
                      onProjectChanged: (value) {
                        setState(() {
                          _selectedProjectFilterId = value;
                        });
                      },
                      onDeveloperTypeChanged: (value) {
                        setState(() {
                          _selectedDeveloperTypeFilter = value;
                        });
                      },
                      onReset: () {
                        setState(() {
                          _selectedTeamLeadFilterId = null;
                          _selectedUserFilterId = null;
                          _selectedProjectFilterId = null;
                          _selectedDeveloperTypeFilter = null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  AnimatedReveal(
                    delay: const Duration(milliseconds: 60),
                    child: _HeroOverview(
                      now: monthStart,
                      elapsedWorkingDays: elapsedWorkingDays,
                      targetHoursPerUser: targetHoursPerUser,
                      alertCount: alertCount,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedReveal(
                    delay: const Duration(milliseconds: 90),
                    child: _OfficialKpiPanel(kpi: monthlyKpi),
                  ),
                  const SizedBox(height: 16),
                  AnimatedReveal(
                    delay: const Duration(milliseconds: 120),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final crossAxisCount = width >= 1450
                            ? 4
                            : width >= 1100
                            ? 3
                            : 2;
                        final aspectRatio = width >= 1450
                            ? 2.15
                            : width >= 1100
                            ? 1.75
                            : 1.32;
                        return GridView.count(
                          crossAxisCount: crossAxisCount,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: aspectRatio,
                          children: [
                            StatCard(
                              title: 'Membri Team',
                              value: teamMembers.length.toString(),
                              icon: Icons.people_alt_outlined,
                              color: AppTheme.primaryColor,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ManageUsersScreen(),
                                  ),
                                );
                              },
                            ),
                            StatCard(
                              title: 'Ore Team Mese',
                              value: teamHours.toStringAsFixed(1),
                              icon: Icons.timer_outlined,
                              color: AppTheme.secondaryColor,
                            ),
                            StatCard(
                              title: 'Completion Medio',
                              value: '${(avgCompletion * 100).round()}%',
                              icon: Icons.speed,
                              color: AppTheme.successColor,
                            ),
                            StatCard(
                              title: 'Progetti Attivi',
                              value: projects.length.toString(),
                              icon: Icons.folder_open,
                              color: AppTheme.accentColor,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ManageProjectsScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  if (topContributor != null) ...[
                    const SizedBox(height: 20),
                    AnimatedReveal(
                      delay: const Duration(milliseconds: 170),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PersonDetailScreen(
                                userId: topContributor.user.id,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: AppTheme.emeraldGradient,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.emoji_events_outlined,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Top Contributor',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      topContributor.user.fullName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${topContributor.totalHours.toStringAsFixed(1)}h',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.chevron_right,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  if ((currentUser.role == UserRole.teamLead ||
                          currentUser.role == UserRole.manager ||
                          currentUser.role == UserRole.admin) &&
                      projects.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    AnimatedReveal(
                      delay: const Duration(milliseconds: 205),
                      child: _ProjectAnalyticsPanel(
                        projects: projects,
                        projectHours: projectHours,
                        last7DaysDailyHours: last7DaysDailyHours,
                        parseColor: _parseColor,
                      ),
                    ),
                  ],
                  if ((currentUser.role == UserRole.manager ||
                          currentUser.role == UserRole.teamLead ||
                          currentUser.role == UserRole.admin) &&
                      projects.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    AnimatedReveal(
                      delay: const Duration(milliseconds: 210),
                      child: _ProjectUserBreakdownPanel(
                        projects: projects,
                        projectHours: projectHours,
                        projectHoursByUser: projectHoursByUser,
                        getUserById: dataService.getUserById,
                        parseColor: _parseColor,
                      ),
                    ),
                  ],
                  if (economicRows.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    AnimatedReveal(
                      delay: const Duration(milliseconds: 215),
                      child: _EconomicOverviewPanel(
                        rows: economicRows,
                        totalConsumedCost: totalConsumedCost,
                        totalEstimatedRevenue: totalEstimatedRevenue,
                        totalGrossMargin: totalGrossMargin,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text('Andamento persone', style: AppTheme.heading3),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFDCE8F9)),
                    ),
                    child: userStats.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              'Nessun membro team disponibile.',
                              style: AppTheme.bodyMedium,
                            ),
                          )
                        : Column(
                            children: userStats.asMap().entries.map((indexed) {
                              final idx = indexed.key;
                              final stat = indexed.value;
                              final isAlert =
                                  stat.totalHours < (targetHoursPerUser * 0.75);

                              return AnimatedReveal(
                                delay: Duration(milliseconds: 220 + (idx * 35)),
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PersonDetailScreen(
                                          userId: stat.user.id,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                stat.user.fullName,
                                                style: AppTheme.bodyLarge,
                                              ),
                                            ),
                                            Text(
                                              '${stat.totalHours.toStringAsFixed(1)}h',
                                              style: AppTheme.bodyMedium
                                                  .copyWith(
                                                    color: isAlert
                                                        ? AppTheme.errorColor
                                                        : AppTheme
                                                              .textPrimaryColor,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Perfetti: ${stat.perfectDays}',
                                              style: AppTheme.caption,
                                            ),
                                            const SizedBox(width: 2),
                                            const Icon(
                                              Icons.chevron_right,
                                              size: 16,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: LinearProgressIndicator(
                                            value: stat.completionRate.clamp(
                                              0.0,
                                              1.0,
                                            ),
                                            minHeight: 8,
                                            backgroundColor:
                                                AppTheme.surfaceMutedColor,
                                            color: isAlert
                                                ? AppTheme.errorColor
                                                : AppTheme.primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Azioni rapide', style: AppTheme.heading3),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final maxCardWidth = constraints.maxWidth >= 1200
                          ? 420.0
                          : constraints.maxWidth >= 900
                          ? 360.0
                          : constraints.maxWidth;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: quickActions
                            .map(
                              (action) => SizedBox(
                                width: maxCardWidth,
                                child: _QuickActionCard(
                                  title: action.title,
                                  subtitle: action.subtitle,
                                  icon: action.icon,
                                  color: action.color,
                                  onTap: action.onTap,
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                  if (projects.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Progetti in evidenza',
                          style: AppTheme.heading3,
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ManageProjectsScreen(),
                              ),
                            );
                          },
                          child: const Text('Vedi tutti'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...projects.take(4).toList().asMap().entries.map((indexed) {
                      final idx = indexed.key;
                      final project = indexed.value;
                      return AnimatedReveal(
                        delay: Duration(milliseconds: 280 + (idx * 40)),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ProjectCard(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProjectDetailScreen(
                                    projectId: project.id,
                                  ),
                                ),
                              );
                            },
                            name: project.name,
                            description: _projectDescriptionWithOwner(
                              project,
                              dataService,
                            ),
                            color: _parseColor(project.color),
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _parseColor(String hexColor) {
    try {
      return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }

  String _projectDescriptionWithOwner(
    Project project,
    DataService dataService,
  ) {
    final owner = project.ownerUserId == null
        ? null
        : dataService.getUserById(project.ownerUserId!);
    final ownerLabel = owner == null
        ? 'TL non assegnato'
        : 'TL: ${owner.fullName}';
    return '${project.description}\n$ownerLabel';
  }
}

class _ProjectAnalyticsPanel extends StatelessWidget {
  final List<Project> projects;
  final Map<String, double> projectHours;
  final Map<DateTime, double> last7DaysDailyHours;
  final Color Function(String) parseColor;

  const _ProjectAnalyticsPanel({
    required this.projects,
    required this.projectHours,
    required this.last7DaysDailyHours,
    required this.parseColor,
  });

  @override
  Widget build(BuildContext context) {
    final totalHours = projectHours.values.fold<double>(0, (sum, h) => sum + h);
    final sortedProjectHours = projectHours.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topProjects = sortedProjectHours
        .where((entry) => entry.value > 0)
        .take(5);

    final now = DateTime.now();
    final start = DateUtils.dateOnly(now.subtract(const Duration(days: 6)));
    final trendDays = List<DateTime>.generate(
      7,
      (index) => start.add(Duration(days: index)),
    );
    final maxTrend = trendDays.fold<double>(
      8,
      (maxValue, day) => (last7DaysDailyHours[day] ?? 0) > maxValue
          ? (last7DaysDailyHours[day] ?? 0) + 2
          : maxValue,
    );
    final avgTrend =
        trendDays.fold<double>(
          0,
          (sum, day) => sum + (last7DaysDailyHours[day] ?? 0),
        ) /
        trendDays.length;

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
          const Text('Analytics Progetti', style: AppTheme.heading3),
          const SizedBox(height: 4),
          Text(
            'Andamento ore ultimi 7 giorni + distribuzione ore per progetto.',
            style: AppTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _LegendPill(
                color: AppTheme.primaryColor,
                text: 'Ore giornaliere',
              ),
              Text(
                'Media ${avgTrend.toStringAsFixed(1)}h',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 170,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxTrend,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxTrend / 4).clamp(2, 20),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        if (value <= 0) {
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
                        if (index < 0 || index >= trendDays.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            DateFormat('E', 'it').format(trendDays[index]),
                            style: AppTheme.caption,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: trendDays.asMap().entries.map((indexed) {
                  final day = indexed.value;
                  final hours = last7DaysDailyHours[day] ?? 0;
                  return BarChartGroupData(
                    x: indexed.key,
                    barRods: [
                      BarChartRodData(
                        toY: hours,
                        width: 18,
                        borderRadius: BorderRadius.circular(6),
                        gradient: AppTheme.primaryGradient,
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (totalHours <= 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Nessuna ora registrata sui tuoi progetti nel mese corrente.',
                style: AppTheme.bodySmall,
              ),
            )
          else
            Column(
              children: [
                SizedBox(
                  height: 190,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 34,
                      sections: topProjects.map((entry) {
                        final project = projects.firstWhere(
                          (p) => p.id == entry.key,
                        );
                        final pct = (entry.value / totalHours) * 100;
                        return PieChartSectionData(
                          value: entry.value,
                          title: '${pct.toStringAsFixed(0)}%',
                          radius: 56,
                          color: parseColor(project.color),
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: topProjects.map((entry) {
                    final project = projects.firstWhere(
                      (p) => p.id == entry.key,
                    );
                    final color = parseColor(project.color);
                    return _LegendPill(
                      color: color,
                      text:
                          '${project.name} ${((entry.value / totalHours) * 100).toStringAsFixed(0)}%',
                    );
                  }).toList(),
                ),
              ],
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

class _DashboardFilters extends StatelessWidget {
  final List<User> visibleTeamLeads;
  final List<User> visibleUsers;
  final List<Project> visibleProjects;
  final String? selectedTeamLeadId;
  final String? selectedUserId;
  final String? selectedProjectId;
  final DeveloperType? selectedDeveloperType;
  final ValueChanged<String?> onTeamLeadChanged;
  final ValueChanged<String?> onUserChanged;
  final ValueChanged<String?> onProjectChanged;
  final ValueChanged<DeveloperType?> onDeveloperTypeChanged;
  final VoidCallback onReset;

  const _DashboardFilters({
    required this.visibleTeamLeads,
    required this.visibleUsers,
    required this.visibleProjects,
    required this.selectedTeamLeadId,
    required this.selectedUserId,
    required this.selectedProjectId,
    required this.selectedDeveloperType,
    required this.onTeamLeadChanged,
    required this.onUserChanged,
    required this.onProjectChanged,
    required this.onDeveloperTypeChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE8F9)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (visibleTeamLeads.isNotEmpty)
            SizedBox(
              width: 240,
              child: DropdownButtonFormField<String?>(
                initialValue: selectedTeamLeadId,
                decoration: const InputDecoration(
                  labelText: 'Filtro Team Lead',
                  prefixIcon: Icon(Icons.groups_outlined),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Tutti i Team Lead'),
                  ),
                  ...visibleTeamLeads.map(
                    (tl) => DropdownMenuItem<String?>(
                      value: tl.id,
                      child: Text(tl.fullName),
                    ),
                  ),
                ],
                onChanged: onTeamLeadChanged,
              ),
            ),
          if (visibleUsers.isNotEmpty)
            SizedBox(
              width: 240,
              child: DropdownButtonFormField<String?>(
                initialValue: selectedUserId,
                decoration: const InputDecoration(
                  labelText: 'Filtro Developer',
                  prefixIcon: Icon(Icons.person_search_outlined),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Tutti i Developer'),
                  ),
                  ...visibleUsers.map(
                    (user) => DropdownMenuItem<String?>(
                      value: user.id,
                      child: Text(user.fullName),
                    ),
                  ),
                ],
                onChanged: onUserChanged,
              ),
            ),
          SizedBox(
            width: 240,
            child: DropdownButtonFormField<String?>(
              initialValue: selectedProjectId,
              decoration: const InputDecoration(
                labelText: 'Filtro Progetto',
                prefixIcon: Icon(Icons.folder_outlined),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Tutti i Progetti'),
                ),
                ...visibleProjects.map(
                  (project) => DropdownMenuItem<String?>(
                    value: project.id,
                    child: Text(project.name),
                  ),
                ),
              ],
              onChanged: onProjectChanged,
            ),
          ),
          SizedBox(
            width: 240,
            child: DropdownButtonFormField<DeveloperType?>(
              initialValue: selectedDeveloperType,
              decoration: const InputDecoration(
                labelText: 'Filtro Specializzazione',
                prefixIcon: Icon(Icons.code_outlined),
              ),
              items: [
                const DropdownMenuItem<DeveloperType?>(
                  value: null,
                  child: Text('Tutte le specializzazioni'),
                ),
                ...DeveloperType.values.map(
                  (type) => DropdownMenuItem<DeveloperType?>(
                    value: type,
                    child: Text(type.displayName),
                  ),
                ),
              ],
              onChanged: onDeveloperTypeChanged,
            ),
          ),
          TextButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset filtri'),
          ),
        ],
      ),
    );
  }
}

class _OfficialKpiPanel extends StatelessWidget {
  final TeamMonthlyKpi kpi;

  const _OfficialKpiPanel({required this.kpi});

  @override
  Widget build(BuildContext context) {
    final completion = (kpi.completionRate * 100)
        .clamp(0, 999)
        .toStringAsFixed(0);
    final saturation = (kpi.saturationRate * 100)
        .clamp(0, 999)
        .toStringAsFixed(0);
    final quality = (kpi.qualityScore * 100).clamp(0, 999).toStringAsFixed(0);
    final completionAlert = kpi.completionRate < 0.85;
    final overload = kpi.saturationRate > 1.10;
    final underload = kpi.saturationRate < 0.70;

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
          const Text('KPI Ufficiali Mensili', style: AppTheme.heading3),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _KpiBadge(
                label: 'Completion',
                value: '$completion%',
                alert: completionAlert,
              ),
              _KpiBadge(
                label: 'Over/Under',
                value: '${kpi.overtimeUnderTimeHours.toStringAsFixed(1)}h',
                alert: false,
              ),
              _KpiBadge(
                label: 'Saturazione',
                value: '$saturation%',
                alert: overload || underload,
              ),
              _KpiBadge(
                label: 'DSO',
                value: '${kpi.dsoAverageDays.toStringAsFixed(2)} gg',
                alert: kpi.dsoAverageDays > 1.0,
              ),
              _KpiBadge(
                label: 'Quality',
                value: '$quality%',
                alert: kpi.qualityScore < 0.70,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiBadge extends StatelessWidget {
  final String label;
  final String value;
  final bool alert;

  const _KpiBadge({
    required this.label,
    required this.value,
    required this.alert,
  });

  @override
  Widget build(BuildContext context) {
    final color = alert ? AppTheme.errorColor : AppTheme.primaryColor;
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTheme.bodySmall),
          Text(
            value,
            style: AppTheme.bodyLarge.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectEconomicRow {
  final Project project;
  final double consumedCost;
  final double estimatedRevenue;
  final double grossMargin;
  final double burnRate;

  const _ProjectEconomicRow({
    required this.project,
    required this.consumedCost,
    required this.estimatedRevenue,
    required this.grossMargin,
    required this.burnRate,
  });
}

class _EconomicOverviewPanel extends StatelessWidget {
  final List<_ProjectEconomicRow> rows;
  final double totalConsumedCost;
  final double totalEstimatedRevenue;
  final double totalGrossMargin;

  const _EconomicOverviewPanel({
    required this.rows,
    required this.totalConsumedCost,
    required this.totalEstimatedRevenue,
    required this.totalGrossMargin,
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
          const Text('KPI Economici Progetto', style: AppTheme.heading3),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _MoneyChip(label: 'Costo', value: totalConsumedCost),
              _MoneyChip(label: 'Ricavo', value: totalEstimatedRevenue),
              _MoneyChip(label: 'Margine', value: totalGrossMargin),
            ],
          ),
          const SizedBox(height: 10),
          ...rows.take(6).map((row) {
            final burnPct = (row.burnRate * 100)
                .clamp(0, 999)
                .toStringAsFixed(0);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE9EFFA)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(row.project.name, style: AppTheme.bodyMedium),
                  ),
                  Text(
                    'Costo ${row.consumedCost.toStringAsFixed(0)}€',
                    style: AppTheme.bodySmall,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Burn $burnPct%',
                    style: AppTheme.bodySmall.copyWith(
                      color: row.burnRate > 1.0
                          ? AppTheme.errorColor
                          : AppTheme.textSecondaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MoneyChip extends StatelessWidget {
  final String label;
  final double value;

  const _MoneyChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$label: ${value.toStringAsFixed(0)}€',
        style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _MonthSelectorBar extends StatelessWidget {
  final DateTime selectedMonth;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPickMonth;

  const _MonthSelectorBar({
    required this.selectedMonth,
    required this.onPrevious,
    required this.onNext,
    required this.onPickMonth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE8F9)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Mese precedente',
          ),
          Expanded(
            child: TextButton.icon(
              onPressed: onPickMonth,
              icon: const Icon(Icons.calendar_month_outlined, size: 18),
              label: Text(
                DateFormat('MMMM yyyy', 'it').format(selectedMonth),
                style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Mese successivo',
          ),
        ],
      ),
    );
  }
}

class _ProjectUserBreakdownPanel extends StatelessWidget {
  final List<Project> projects;
  final Map<String, double> projectHours;
  final Map<String, Map<String, double>> projectHoursByUser;
  final User? Function(String) getUserById;
  final Color Function(String) parseColor;

  const _ProjectUserBreakdownPanel({
    required this.projects,
    required this.projectHours,
    required this.projectHoursByUser,
    required this.getUserById,
    required this.parseColor,
  });

  @override
  Widget build(BuildContext context) {
    final ordered =
        projects
            .where((project) => (projectHours[project.id] ?? 0) > 0)
            .toList()
          ..sort(
            (a, b) =>
                (projectHours[b.id] ?? 0).compareTo(projectHours[a.id] ?? 0),
          );

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
          const Text(
            'Complessivo mese per progetto e utente',
            style: AppTheme.heading3,
          ),
          const SizedBox(height: 6),
          Text(
            'Ore totali progetto con dettaglio contributor.',
            style: AppTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          if (ordered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Nessuna consuntivazione sui progetti nel mese selezionato.',
                style: AppTheme.bodyMedium,
              ),
            )
          else
            ...ordered.take(8).map((project) {
              final total = projectHours[project.id] ?? 0;
              final contributors =
                  (projectHoursByUser[project.id] ?? {}).entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));
              final color = parseColor(project.color);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE7EEF9)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                          child: Text(project.name, style: AppTheme.bodyLarge),
                        ),
                        Text(
                          '${total.toStringAsFixed(1)}h',
                          style: AppTheme.bodyLarge.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    if (contributors.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: contributors.take(6).map((entry) {
                          final user = getUserById(entry.key);
                          final name = user?.fullName ?? 'Utente';
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$name • ${entry.value.toStringAsFixed(1)}h',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.textPrimaryColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _HeroOverview extends StatelessWidget {
  final DateTime now;
  final int elapsedWorkingDays;
  final double targetHoursPerUser;
  final int alertCount;

  const _HeroOverview({
    required this.now,
    required this.elapsedWorkingDays,
    required this.targetHoursPerUser,
    required this.alertCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Panoramica ${DateFormat('MMMM yyyy', 'it').format(now)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Monitora consuntivi, produttivita e segnali critici del team.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _HighlightChip(
                label: 'Giorni lavorativi',
                value: '$elapsedWorkingDays',
                icon: Icons.calendar_month,
              ),
              _HighlightChip(
                label: 'Target per persona',
                value: '${targetHoursPerUser.toStringAsFixed(0)}h',
                icon: Icons.flag_outlined,
              ),
              _HighlightChip(
                label: 'Alert',
                value: '$alertCount',
                icon: Icons.warning_amber_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HighlightChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _HighlightChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionConfig {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionConfig({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE8F9)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: AppTheme.bodyLarge),
        subtitle: Text(subtitle, style: AppTheme.bodySmall),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _UserMonthStat {
  final User user;
  final double totalHours;
  final int perfectDays;
  final double completionRate;

  const _UserMonthStat({
    required this.user,
    required this.totalHours,
    required this.perfectDays,
    required this.completionRate,
  });
}
