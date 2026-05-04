import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/project_model.dart';
import '../models/timesheet_entry.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_reveal.dart';
import 'project_detail_screen.dart';

class TimeSheetScreen extends StatefulWidget {
  const TimeSheetScreen({super.key});

  @override
  State<TimeSheetScreen> createState() => _TimeSheetScreenState();
}

class _TimeSheetScreenState extends State<TimeSheetScreen> {
  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final dataService = context.watch<DataService>();
    final user = authService.currentUser;
    final userId = user?.id ?? '';
    final visibleProjects = user == null
        ? <Project>[]
        : dataService.getProjectsVisibleForUser(user);
    final hasVacationProject =
        user != null && dataService.getVacationProjectForUser(user) != null;

    final todayEntries = dataService.getEntriesForDate(userId, _selectedDate)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final dailyTotal = dataService.getDailyHours(userId, _selectedDate);
    final canAddEntry =
        dailyTotal < 8.0 && (visibleProjects.isNotEmpty || hasVacationProject);

    final monthStart = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final monthEnd = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
    final perfectDays = dataService.getPerfectDaysCount(
      userId: userId,
      startDate: monthStart,
      endDate: monthEnd,
    );
    final workingDaysInMonth = dataService.getWorkingDaysInMonth(_selectedDate);
    final monthlyXp = dataService.getMonthlyExperience(userId, _selectedDate);
    final streak = dataService.getCurrentStreak(userId);
    final salaryDay = dataService.getLastWorkingDay(_selectedDate);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    final completionRate = workingDaysInMonth == 0
        ? 0.0
        : (perfectDays / workingDaysInMonth).clamp(0.0, 1.0);
    final isSalaryDay = DateUtils.isSameDay(_selectedDate, salaryDay);
    final isWorkingDay = dataService.isWorkingDay(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Consuntivazione Smart'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Scegli data',
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 90)),
                locale: const Locale('it'),
              );
              if (date != null) {
                setState(() {
                  _selectedDate = DateUtils.dateOnly(date);
                });
              }
            },
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
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    children: [
                      _HeroCard(
                        selectedDate: _selectedDate,
                        dailyTotal: dailyTotal,
                        isWorkingDay: isWorkingDay,
                        onPreviousDay: () {
                          setState(() {
                            _selectedDate = _selectedDate.subtract(
                              const Duration(days: 1),
                            );
                          });
                        },
                        onNextDay: () {
                          setState(() {
                            _selectedDate = _selectedDate.add(
                              const Duration(days: 1),
                            );
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      AnimatedReveal(
                        delay: const Duration(milliseconds: 70),
                        child: _PerformanceSnapshotCard(
                          completionRate: completionRate,
                          monthlyXp: monthlyXp,
                          streak: streak,
                          perfectDays: perfectDays,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              title: 'Streak',
                              value: '$streak giorni',
                              icon: Icons.local_fire_department,
                              gradient: AppTheme.sunriseGradient,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MetricCard(
                              title: 'XP mese',
                              value: '$monthlyXp pt',
                              icon: Icons.stars,
                              gradient: AppTheme.emeraldGradient,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _InfoTile(
                        title: 'Reward progresso',
                        subtitle:
                            '$perfectDays giorni perfetti su $workingDaysInMonth lavorativi',
                        icon: Icons.emoji_events_outlined,
                        trailing: '${(completionRate * 100).round()}%',
                        progress: completionRate,
                      ),
                      const SizedBox(height: 10),
                      _InfoTile(
                        title: isSalaryDay
                            ? 'Oggi e\' il giorno stipendio'
                            : 'Stipendio del mese',
                        subtitle:
                            'Ultimo lavorativo: ${DateFormat('EEEE d MMMM', 'it').format(salaryDay)}',
                        icon: Icons.account_balance_wallet_outlined,
                        trailing: isSalaryDay ? 'oggi' : 'in arrivo',
                        gradient: AppTheme.sunriseGradient,
                      ),
                      const SizedBox(height: 10),
                      const _InfoTile(
                        title: 'Notifiche attive',
                        subtitle:
                            'Promemoria automatico alle 18:00 nei giorni lavorativi',
                        icon: Icons.notifications_active_outlined,
                        trailing: 'ON',
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Timeline del giorno',
                            style: AppTheme.heading3,
                          ),
                          TextButton.icon(
                            onPressed: !canAddEntry
                                ? null
                                : () {
                                    _openEntrySheet(
                                      context: context,
                                      date: _selectedDate,
                                    );
                                  },
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Aggiungi'),
                          ),
                        ],
                      ),
                      if (visibleProjects.isEmpty && !hasVacationProject)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Nessun progetto assegnato: chiedi a TL/Manager di assegnarti un progetto.',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.warningColor,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
              if (todayEntries.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: _EmptyState(),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList.builder(
                    itemCount: todayEntries.length,
                    itemBuilder: (context, index) {
                      final entry = todayEntries[index];
                      final project = dataService.getProjectById(
                        entry.projectId,
                      );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AnimatedReveal(
                          delay: Duration(milliseconds: 70 + (index * 45)),
                          beginOffset: const Offset(0.08, 0),
                          child: _EntryCard(
                            entry: entry,
                            project: project,
                            ownerName: project?.ownerUserId == null
                                ? null
                                : dataService
                                      .getUserById(project!.ownerUserId!)
                                      ?.fullName,
                            onDelete: () async {
                              await dataService.deleteTimesheetEntry(entry.id);
                            },
                            onEdit: () {
                              _openEntrySheet(
                                context: context,
                                date: _selectedDate,
                                entry: entry,
                              );
                            },
                            onProjectTap: project == null
                                ? null
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ProjectDetailScreen(
                                          projectId: project.id,
                                        ),
                                      ),
                                    );
                                  },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              SliverToBoxAdapter(child: SizedBox(height: 24 + bottomInset)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEntrySheet({
    required BuildContext context,
    required DateTime date,
    TimesheetEntry? entry,
  }) async {
    final formKey = GlobalKey<FormState>();
    final dataService = context.read<DataService>();
    final authService = context.read<AuthService>();
    final currentUser = authService.currentUser;
    if (currentUser == null) {
      return;
    }
    final notesController = TextEditingController(text: entry?.notes);

    final availableProjects = dataService
        .getProjectsVisibleForUser(currentUser)
        .where((project) => project.isActive)
        .toList();
    final userVacationProject = dataService.getVacationProjectForUser(
      currentUser,
    );
    if (userVacationProject != null &&
        !availableProjects.any(
          (project) => project.id == userVacationProject.id,
        )) {
      availableProjects.add(userVacationProject);
    }
    Project? selectedProject = entry != null
        ? dataService.getProjectById(entry.projectId)
        : null;
    final availableCommesse = dataService.getActiveCommesse();
    String? selectedCommessaId =
        entry?.commessaId ?? selectedProject?.commessaId;
    if (selectedProject != null &&
        !availableProjects.any(
          (project) => project.id == selectedProject!.id,
        )) {
      availableProjects.add(selectedProject);
    }
    double selectedHours = entry?.hours ?? 0.5;

    final vacationProject = userVacationProject;
    final messenger = ScaffoldMessenger.of(context);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setLocalState) {
          final userId = currentUser.id;
          final media = MediaQuery.of(context);
          final currentDailyTotal = dataService.getDailyHours(userId, date);
          final alreadyUsedHours = entry != null
              ? currentDailyTotal - entry.hours
              : currentDailyTotal;
          final remainingHours = (8.0 - alreadyUsedHours).clamp(0.0, 8.0);

          return AnimatedPadding(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
            child: Container(
              constraints: BoxConstraints(maxHeight: media.size.height * 0.92),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppTheme.textLightColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                        child: Form(
                          key: formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry == null
                                    ? 'Nuova consuntivazione'
                                    : 'Modifica consuntivazione',
                                style: AppTheme.heading2.copyWith(fontSize: 26),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat(
                                  'EEEE d MMMM yyyy',
                                  'it',
                                ).format(date),
                                style: AppTheme.bodyMedium,
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<Project>(
                                initialValue: selectedProject,
                                decoration: const InputDecoration(
                                  labelText: 'Progetto',
                                  prefixIcon: Icon(Icons.folder_open),
                                ),
                                items: availableProjects
                                    .map(
                                      (project) => DropdownMenuItem(
                                        value: project,
                                        child: _ProjectDropdownLabel(
                                          project: project,
                                          ownerName: project.ownerUserId == null
                                              ? null
                                              : dataService
                                                    .getUserById(
                                                      project.ownerUserId!,
                                                    )
                                                    ?.fullName,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setLocalState(() {
                                    selectedProject = value;
                                    if (value?.commessaId != null &&
                                        value!.commessaId!.trim().isNotEmpty) {
                                      selectedCommessaId = value.commessaId;
                                    } else if (!(value?.isBillable ?? false)) {
                                      selectedCommessaId = null;
                                    }
                                  });
                                },
                                validator: (value) => value == null
                                    ? 'Seleziona un progetto'
                                    : null,
                              ),
                              if (selectedProject?.isBillable ?? false) ...[
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  initialValue: selectedCommessaId,
                                  decoration: const InputDecoration(
                                    labelText: 'Commessa GECO',
                                    prefixIcon: Icon(
                                      Icons.business_center_outlined,
                                    ),
                                  ),
                                  items: availableCommesse
                                      .map(
                                        (commessa) => DropdownMenuItem<String>(
                                          value: commessa.id,
                                          child: Text(
                                            '${commessa.codice} • ${commessa.cliente}',
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setLocalState(() {
                                      selectedCommessaId = value;
                                    });
                                  },
                                  validator: (value) {
                                    if (!(selectedProject?.isBillable ??
                                        false)) {
                                      return null;
                                    }
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Commessa obbligatoria';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                              if (vacationProject != null) ...[
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: OutlinedButton.icon(
                                    onPressed: remainingHours < 8.0
                                        ? null
                                        : () {
                                            setLocalState(() {
                                              selectedProject = vacationProject;
                                              selectedCommessaId =
                                                  vacationProject.commessaId;
                                              selectedHours = 8.0;
                                              if (notesController.text
                                                  .trim()
                                                  .isEmpty) {
                                                notesController.text = 'Ferie';
                                              }
                                            });
                                          },
                                    icon: const Icon(
                                      Icons.beach_access_outlined,
                                    ),
                                    label: const Text('Segna Ferie (8h)'),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              Text(
                                'Ore lavorate (disponibili: ${remainingHours.toStringAsFixed(1)}h)',
                                style: AppTheme.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _hourOptions.map((hours) {
                                  final isSelected = selectedHours == hours;
                                  final isEnabled =
                                      hours <= remainingHours + 0.001 ||
                                      isSelected;

                                  return GestureDetector(
                                    onTap: isEnabled
                                        ? () {
                                            setLocalState(() {
                                              selectedHours = hours;
                                            });
                                          }
                                        : null,
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: !isEnabled
                                            ? Colors.grey.shade200
                                            : isSelected
                                            ? AppTheme.primaryColor
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppTheme.primaryColor
                                              : Colors.grey.shade300,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: AppTheme.primaryColor
                                                      .withValues(alpha: 0.2),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Text(
                                        '${hours.toStringAsFixed(1)}h',
                                        style: TextStyle(
                                          color: !isEnabled
                                              ? Colors.grey.shade500
                                              : isSelected
                                              ? Colors.white
                                              : AppTheme.textPrimaryColor,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: notesController,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  labelText: 'Note (opzionale)',
                                  prefixIcon: Icon(Icons.edit_note),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(
                            color: AppTheme.surfaceMutedColor,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              child: const Text('Annulla'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                if (!formKey.currentState!.validate() ||
                                    selectedProject == null) {
                                  return;
                                }

                                if (!dataService.canTrackProject(
                                  user: currentUser,
                                  project: selectedProject!,
                                )) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Non puoi consuntivare su questo progetto.',
                                      ),
                                      backgroundColor: AppTheme.errorColor,
                                    ),
                                  );
                                  return;
                                }

                                final userId = currentUser.id;
                                final currentDailyTotal = dataService
                                    .getDailyHours(userId, date);
                                final otherHours = entry != null
                                    ? currentDailyTotal - entry.hours
                                    : currentDailyTotal;

                                if (otherHours + selectedHours > 8.0) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Limite giornaliero superato: massimo 8 ore.',
                                      ),
                                      backgroundColor: AppTheme.errorColor,
                                    ),
                                  );
                                  return;
                                }

                                bool success;
                                if (entry == null) {
                                  final newEntry = TimesheetEntry(
                                    id: 'entry_${DateTime.now().millisecondsSinceEpoch}',
                                    userId: userId,
                                    projectId: selectedProject!.id,
                                    commessaId: selectedCommessaId,
                                    date: date,
                                    hours: selectedHours,
                                    notes: notesController.text.trim().isEmpty
                                        ? null
                                        : notesController.text.trim(),
                                    createdAt: DateTime.now(),
                                  );
                                  success = await dataService.addTimesheetEntry(
                                    newEntry,
                                    actor: currentUser,
                                  );
                                } else {
                                  final updatedEntry = entry.copyWith(
                                    projectId: selectedProject!.id,
                                    commessaId: selectedCommessaId,
                                    hours: selectedHours,
                                    notes: notesController.text.trim().isEmpty
                                        ? null
                                        : notesController.text.trim(),
                                    updatedAt: DateTime.now(),
                                  );
                                  success = await dataService
                                      .updateTimesheetEntry(
                                        updatedEntry,
                                        actor: currentUser,
                                      );
                                }

                                if (!sheetContext.mounted) {
                                  return;
                                }

                                Navigator.of(sheetContext).pop();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      success
                                          ? (entry == null
                                                ? 'Consuntivazione salvata.'
                                                : 'Consuntivazione aggiornata.')
                                          : 'Operazione non riuscita.',
                                    ),
                                    backgroundColor: success
                                        ? AppTheme.successColor
                                        : AppTheme.errorColor,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.check_circle_outline),
                              label: Text(entry == null ? 'Salva' : 'Aggiorna'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    // Let the sheet close animation finish before disposing.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    notesController.dispose();
  }
}

class _ProjectDropdownLabel extends StatelessWidget {
  final Project project;
  final String? ownerName;

  const _ProjectDropdownLabel({required this.project, required this.ownerName});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            project.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            ownerName == null ? 'TL non assegnato' : 'TL: $ownerName',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.caption,
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final DateTime selectedDate;
  final double dailyTotal;
  final bool isWorkingDay;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;

  const _HeroCard({
    required this.selectedDate,
    required this.dailyTotal,
    required this.isWorkingDay,
    required this.onPreviousDay,
    required this.onNextDay,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (dailyTotal / 8.0).clamp(0.0, 1.0);
    final status = !isWorkingDay
        ? 'Weekend'
        : dailyTotal >= 8
        ? 'Giornata completata'
        : 'Ancora ${(8 - dailyTotal).toStringAsFixed(1)}h';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(26),
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
          Row(
            children: [
              IconButton(
                onPressed: onPreviousDay,
                icon: const Icon(Icons.chevron_left, color: Colors.white),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      DateFormat('EEEE', 'it').format(selectedDate),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      DateFormat('d MMMM yyyy', 'it').format(selectedDate),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onNextDay,
                icon: const Icon(Icons.chevron_right, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Obiettivo 8h',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${dailyTotal.toStringAsFixed(1)} / 8.0h',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            status,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PerformanceSnapshotCard extends StatelessWidget {
  final double completionRate;
  final int monthlyXp;
  final int streak;
  final int perfectDays;

  const _PerformanceSnapshotCard({
    required this.completionRate,
    required this.monthlyXp,
    required this.streak,
    required this.perfectDays,
  });

  @override
  Widget build(BuildContext context) {
    final completion = (completionRate * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: AppTheme.sunriseGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentColor.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Performance del mese',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                    SizedBox(width: 5),
                    Text(
                      'Live',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$completion%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 56,
              fontWeight: FontWeight.w900,
              height: 0.92,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SnapshotMetric(label: 'XP', value: '$monthlyXp'),
              ),
              Expanded(
                child: _SnapshotMetric(label: 'Streak', value: '$streak gg'),
              ),
              Expanded(
                child: _SnapshotMetric(
                  label: 'Perfetti',
                  value: '$perfectDays',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SnapshotMetric extends StatelessWidget {
  final String label;
  final String value;

  const _SnapshotMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Gradient gradient;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
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

class _InfoTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String trailing;
  final Gradient? gradient;
  final double? progress;

  const _InfoTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.trailing,
    this.gradient,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final isGradient = gradient != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: gradient,
        color: isGradient ? null : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isGradient
            ? null
            : Border.all(color: const Color(0xFFDBE8FA), width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isGradient
                      ? Colors.white.withValues(alpha: 0.2)
                      : AppTheme.surfaceMutedColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isGradient ? Colors.white : AppTheme.primaryColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isGradient
                            ? Colors.white
                            : AppTheme.textPrimaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isGradient
                            ? Colors.white70
                            : AppTheme.textSecondaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                trailing,
                style: TextStyle(
                  color: isGradient ? Colors.white : AppTheme.primaryColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: progress,
                backgroundColor: const Color(0xFFDCE8F9),
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDBE8FA)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.surfaceMutedColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.assignment_outlined,
              color: AppTheme.primaryColor,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Nessuna voce per questa giornata',
            style: AppTheme.heading3,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'Aggiungi progetto, ore e note per completare il consuntivo.',
            style: AppTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final TimesheetEntry entry;
  final Project? project;
  final String? ownerName;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback? onProjectTap;

  const _EntryCard({
    required this.entry,
    required this.project,
    required this.ownerName,
    required this.onDelete,
    required this.onEdit,
    this.onProjectTap,
  });

  @override
  Widget build(BuildContext context) {
    final projectColor = _projectColor();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onProjectTap ?? onEdit,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: projectColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.folder_open, color: projectColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project?.name ?? 'Progetto',
                        style: AppTheme.heading3.copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${entry.hours.toStringAsFixed(1)}h',
                        style: AppTheme.bodyMedium.copyWith(
                          color: projectColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (ownerName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'TL: $ownerName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.caption,
                        ),
                      ],
                      if ((entry.notes ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          entry.notes!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    }
                    if (value == 'delete') {
                      _openDeleteSheet(context);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Text('Modifica'),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Elimina'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openDeleteSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppTheme.textLightColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Elimina voce?', style: AppTheme.heading3),
              const SizedBox(height: 6),
              const Text(
                'Questa consuntivazione verra rimossa definitivamente.',
                style: AppTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('Annulla'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        onDelete();
                        Navigator.of(sheetContext).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorColor,
                      ),
                      child: const Text('Elimina'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _projectColor() {
    if (project == null) {
      return Colors.grey;
    }

    try {
      return Color(int.parse(project!.color.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }
}

const List<double> _hourOptions = [
  0.5,
  1.0,
  1.5,
  2.0,
  2.5,
  3.0,
  3.5,
  4.0,
  4.5,
  5.0,
  5.5,
  6.0,
  6.5,
  7.0,
  7.5,
  8.0,
];
