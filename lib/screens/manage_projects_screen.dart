import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_reveal.dart';
import '../widgets/project_card.dart';
import 'manage_commesse_screen.dart';
import 'project_detail_screen.dart';

class ManageProjectsScreen extends StatefulWidget {
  const ManageProjectsScreen({super.key});

  @override
  State<ManageProjectsScreen> createState() => _ManageProjectsScreenState();
}

class _ManageProjectsScreenState extends State<ManageProjectsScreen> {
  final List<Color> _projectColors = const [
    Color(0xFF1D4ED8),
    Color(0xFF06B6D4),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFFF43F5E),
    Color(0xFF8B5CF6),
    Color(0xFF0F766E),
    Color(0xFF111827),
  ];

  Future<void> _openProjectSheet({Project? project}) async {
    final dataService = context.read<DataService>();
    final authService = context.read<AuthService>();
    final currentUser = authService.currentUser;
    if (currentUser == null) {
      return;
    }
    final canCreateProjects = dataService.canCreateProjectsForUser(currentUser);
    if (!canCreateProjects) {
      return;
    }

    final canSetTeamLeadOwner =
        currentUser.role == UserRole.admin ||
        currentUser.role == UserRole.manager;
    final isDelegatedDeveloper =
        currentUser.role == UserRole.employee && currentUser.canCreateProjects;
    final teamLeads = dataService.getUsersByRole(UserRole.teamLead)
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
    final developers = isDelegatedDeveloper
        ? <User>[currentUser]
        : (dataService.users
              .where(
                (u) =>
                    u.isActive &&
                    (u.role == UserRole.employee || u.role == UserRole.admin),
              )
              .toList()
            ..sort((a, b) => a.fullName.compareTo(b.fullName)));
    final commesse = dataService.getActiveCommesse()
      ..sort((a, b) => a.codice.compareTo(b.codice));

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: project?.name ?? '');
    final descController = TextEditingController(
      text: project?.description ?? '',
    );
    final hourlyCostController = TextEditingController(
      text: project?.hourlyCost?.toStringAsFixed(2) ?? '',
    );
    final hourlyRateController = TextEditingController(
      text: project?.hourlyRate?.toStringAsFixed(2) ?? '',
    );
    final estimatedHoursController = TextEditingController(
      text: project?.estimatedHours?.toStringAsFixed(1) ?? '',
    );
    final estimatedBudgetController = TextEditingController(
      text: project?.estimatedBudget?.toStringAsFixed(2) ?? '',
    );
    Color selectedColor = project != null
        ? Color(int.parse(project.color.replaceFirst('#', '0xFF')))
        : _projectColors[0];
    String? selectedOwnerUserId = project?.ownerUserId;
    String? selectedCommessaId = project?.commessaId;
    bool isBillable = project?.isBillable ?? false;
    final selectedDeveloperIds = <String>{...project?.assignedUserIds ?? []};

    if (currentUser.role == UserRole.teamLead) {
      selectedOwnerUserId = currentUser.id;
    } else if (isDelegatedDeveloper) {
      selectedOwnerUserId = currentUser.teamLeadId ?? project?.ownerUserId;
      selectedDeveloperIds
        ..clear()
        ..add(currentUser.id);
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final media = MediaQuery.of(context);

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
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                        child: Form(
                          key: formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                project == null
                                    ? 'Nuovo progetto'
                                    : 'Modifica progetto',
                                style: AppTheme.heading2.copyWith(fontSize: 26),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Definisci owner TL, persone assegnate, nome e descrizione.',
                                style: AppTheme.bodyMedium,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Nome Progetto',
                                  prefixIcon: Icon(Icons.folder_open),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Nome richiesto';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: descController,
                                decoration: const InputDecoration(
                                  labelText: 'Descrizione',
                                  prefixIcon: Icon(Icons.description_outlined),
                                ),
                                maxLines: 4,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Descrizione richiesta';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              if (canSetTeamLeadOwner) ...[
                                DropdownButtonFormField<String>(
                                  initialValue: selectedOwnerUserId,
                                  decoration: const InputDecoration(
                                    labelText: 'Team Lead owner',
                                    prefixIcon: Icon(Icons.groups_outlined),
                                  ),
                                  items: teamLeads
                                      .map(
                                        (tl) => DropdownMenuItem<String>(
                                          value: tl.id,
                                          child: Text(tl.fullName),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setSheetState(() {
                                      selectedOwnerUserId = value;
                                    });
                                  },
                                ),
                              ] else if (currentUser.role == UserRole.teamLead)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Owner progetto: Team Lead corrente',
                                    style: AppTheme.bodySmall,
                                  ),
                                )
                              else if (isDelegatedDeveloper)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    selectedOwnerUserId == null
                                        ? 'Owner TL non assegnato: il progetto resta visibile a te.'
                                        : 'Owner progetto: ${dataService.getUserById(selectedOwnerUserId!)?.fullName ?? 'TL di riferimento'}',
                                    style: AppTheme.bodySmall,
                                  ),
                                ),
                              const SizedBox(height: 12),
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                value: isBillable,
                                title: const Text('Progetto fatturabile'),
                                subtitle: const Text(
                                  'Richiede commessa GECO e abilita KPI economici.',
                                  style: AppTheme.bodySmall,
                                ),
                                onChanged: (value) {
                                  setSheetState(() {
                                    isBillable = value;
                                    if (!isBillable) {
                                      selectedCommessaId = null;
                                    }
                                  });
                                },
                              ),
                              if (isBillable) ...[
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  initialValue: selectedCommessaId,
                                  decoration: const InputDecoration(
                                    labelText: 'Commessa GECO',
                                    prefixIcon: Icon(
                                      Icons.business_center_outlined,
                                    ),
                                  ),
                                  items: commesse
                                      .map(
                                        (c) => DropdownMenuItem<String>(
                                          value: c.id,
                                          child: Text(
                                            '${c.codice} • ${c.cliente}',
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setSheetState(() {
                                      selectedCommessaId = value;
                                    });
                                  },
                                  validator: (value) {
                                    if (!isBillable) {
                                      return null;
                                    }
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Commessa obbligatoria per progetto fatturabile';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: hourlyCostController,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: const InputDecoration(
                                          labelText: 'Costo/h',
                                          prefixIcon: Icon(Icons.euro_outlined),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextFormField(
                                        controller: hourlyRateController,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: const InputDecoration(
                                          labelText: 'Tariffa/h',
                                          prefixIcon: Icon(
                                            Icons.trending_up_outlined,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: estimatedHoursController,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: const InputDecoration(
                                          labelText: 'Ore stimate',
                                          prefixIcon: Icon(
                                            Icons.timer_outlined,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextFormField(
                                        controller: estimatedBudgetController,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: const InputDecoration(
                                          labelText: 'Budget stimato',
                                          prefixIcon: Icon(
                                            Icons.savings_outlined,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Persone assegnate',
                                    style: AppTheme.bodyMedium,
                                  ),
                                  Text(
                                    '${selectedDeveloperIds.length} selezionati',
                                    style: AppTheme.bodySmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (developers.isEmpty)
                                const Text(
                                  'Nessun developer disponibile.',
                                  style: AppTheme.bodySmall,
                                )
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: developers.map((developer) {
                                    final isSelected = selectedDeveloperIds
                                        .contains(developer.id);
                                    return FilterChip(
                                      selected: isSelected,
                                      label: Text(developer.fullName),
                                      onSelected: isDelegatedDeveloper
                                          ? null
                                          : (value) {
                                              setSheetState(() {
                                                if (value) {
                                                  selectedDeveloperIds.add(
                                                    developer.id,
                                                  );
                                                } else {
                                                  selectedDeveloperIds.remove(
                                                    developer.id,
                                                  );
                                                }
                                              });
                                            },
                                    );
                                  }).toList(),
                                ),
                              const SizedBox(height: 16),
                              const Text(
                                'Colore progetto',
                                style: AppTheme.bodyMedium,
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: _projectColors.map((color) {
                                  final isSelected =
                                      color.toARGB32() ==
                                      selectedColor.toARGB32();
                                  return GestureDetector(
                                    onTap: () {
                                      setSheetState(() {
                                        selectedColor = color;
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected
                                              ? AppTheme.textPrimaryColor
                                              : Colors.white,
                                          width: isSelected ? 3 : 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: color.withValues(
                                              alpha: 0.35,
                                            ),
                                            blurRadius: isSelected ? 12 : 6,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: isSelected
                                          ? const Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 20,
                                            )
                                          : null,
                                    ),
                                  );
                                }).toList(),
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
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                if (!formKey.currentState!.validate()) {
                                  return;
                                }

                                final colorHex =
                                    '#${selectedColor.toARGB32().toRadixString(16).substring(2)}';
                                final assignedUserIds = isDelegatedDeveloper
                                    ? <String>[currentUser.id]
                                    : (selectedDeveloperIds.toList()..sort());
                                final hourlyCost = _parseNullableDouble(
                                  hourlyCostController.text,
                                );
                                final hourlyRate = _parseNullableDouble(
                                  hourlyRateController.text,
                                );
                                final estimatedHours = _parseNullableDouble(
                                  estimatedHoursController.text,
                                );
                                final estimatedBudget = _parseNullableDouble(
                                  estimatedBudgetController.text,
                                );
                                final ownerUserId = canSetTeamLeadOwner
                                    ? selectedOwnerUserId
                                    : currentUser.role == UserRole.teamLead
                                    ? currentUser.id
                                    : isDelegatedDeveloper
                                    ? currentUser.teamLeadId
                                    : project?.ownerUserId;

                                if (project == null) {
                                  final newProject = Project(
                                    id: 'proj_${DateTime.now().millisecondsSinceEpoch}',
                                    name: nameController.text.trim(),
                                    description: descController.text.trim(),
                                    color: colorHex,
                                    commessaId: isBillable
                                        ? selectedCommessaId
                                        : null,
                                    isBillable: isBillable,
                                    hourlyCost: isBillable ? hourlyCost : null,
                                    hourlyRate: isBillable ? hourlyRate : null,
                                    estimatedHours: isBillable
                                        ? estimatedHours
                                        : null,
                                    estimatedBudget: isBillable
                                        ? estimatedBudget
                                        : null,
                                    ownerUserId: ownerUserId,
                                    createdByUserId: currentUser.id,
                                    assignedUserIds: assignedUserIds,
                                    createdAt: DateTime.now(),
                                  );
                                  await context.read<DataService>().addProject(
                                    newProject,
                                  );
                                } else {
                                  final updated = project.copyWith(
                                    name: nameController.text.trim(),
                                    description: descController.text.trim(),
                                    color: colorHex,
                                    commessaId: isBillable
                                        ? selectedCommessaId
                                        : null,
                                    isBillable: isBillable,
                                    hourlyCost: isBillable ? hourlyCost : null,
                                    hourlyRate: isBillable ? hourlyRate : null,
                                    estimatedHours: isBillable
                                        ? estimatedHours
                                        : null,
                                    estimatedBudget: isBillable
                                        ? estimatedBudget
                                        : null,
                                    ownerUserId: ownerUserId,
                                    assignedUserIds: assignedUserIds,
                                  );
                                  await context
                                      .read<DataService>()
                                      .updateProject(updated);
                                }

                                if (!sheetContext.mounted) {
                                  return;
                                }

                                Navigator.of(sheetContext).pop();
                              },
                              icon: const Icon(Icons.check_circle_outline),
                              label: Text(project == null ? 'Crea' : 'Salva'),
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

    await Future<void>.delayed(const Duration(milliseconds: 400));
    nameController.dispose();
    descController.dispose();
    hourlyCostController.dispose();
    hourlyRateController.dispose();
    estimatedHoursController.dispose();
    estimatedBudgetController.dispose();
  }

  Future<void> _openDeleteProjectSheet(Project project) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
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
                const Text('Eliminare progetto?', style: AppTheme.heading3),
                const SizedBox(height: 6),
                Text(
                  'Il progetto "${project.name}" non sara piu disponibile nei consuntivi.',
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
                        onPressed: () async {
                          await context.read<DataService>().deleteProject(
                            project.id,
                          );
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final dataService = context.watch<DataService>();
    final currentUser = authService.currentUser;
    final canCreateProjects =
        currentUser != null &&
        dataService.canCreateProjectsForUser(currentUser);
    final projects = currentUser == null
        ? dataService.projects.where((p) => p.isActive).toList()
        : dataService.getProjectsVisibleForUser(currentUser);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects Studio'),
        actions: [
          IconButton(
            tooltip: 'Gestisci commesse GECO',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageCommesseScreen()),
              );
            },
            icon: const Icon(Icons.business_center_outlined),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppTheme.appBackgroundGradient,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: AnimatedReveal(
                delay: const Duration(milliseconds: 60),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_outlined,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${projects.length} progetti attivi',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!canCreateProjects)
              AnimatedReveal(
                delay: const Duration(milliseconds: 100),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Accesso in sola lettura: Admin, Manager, Team Lead e developer designati possono creare o modificare progetti.',
                    style: AppTheme.bodySmall,
                  ),
                ),
              ),
            if (currentUser?.role == UserRole.teamLead)
              AnimatedReveal(
                delay: const Duration(milliseconds: 110),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Vista Team Lead: qui trovi solo i progetti di tua ownership.',
                    style: AppTheme.bodySmall,
                  ),
                ),
              ),
            Expanded(
              child: projects.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Icon(
                              Icons.folder_open_rounded,
                              color: Colors.white,
                              size: 34,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Nessun progetto',
                            style: AppTheme.heading3,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Inizia creando il primo progetto del team.',
                            style: AppTheme.bodyMedium,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                      itemCount: projects.length,
                      itemBuilder: (context, index) {
                        final project = projects[index];
                        final owner = project.ownerUserId == null
                            ? null
                            : dataService.getUserById(project.ownerUserId!);
                        final ownerLabel = owner == null
                            ? 'TL non assegnato'
                            : 'TL: ${owner.fullName}';
                        final workersCount = project.assignedUserIds.length;
                        final workersLabel = workersCount == 1
                            ? '1 persona assegnata'
                            : '$workersCount persone assegnate';
                        final commessa = project.commessaId == null
                            ? null
                            : dataService.getCommessaById(project.commessaId!);
                        final commessaLabel = project.isBillable
                            ? 'Commessa: ${commessa?.codice ?? 'non assegnata'}'
                            : 'Non fatturabile';
                        final description =
                            '${project.description}\n$ownerLabel • $workersLabel • $commessaLabel';
                        final canModifyProject =
                            currentUser != null &&
                            _canModifyProject(currentUser, project);

                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: Duration(milliseconds: 260 + (index * 40)),
                          curve: Curves.easeOutCubic,
                          builder: (context, t, child) {
                            return Transform.translate(
                              offset: Offset((1 - t) * 24, 0),
                              child: Opacity(opacity: t, child: child),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
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
                              description: description,
                              color: Color(
                                int.parse(
                                  project.color.replaceFirst('#', '0xFF'),
                                ),
                              ),
                              onEdit: canModifyProject
                                  ? () => _openProjectSheet(project: project)
                                  : null,
                              onDelete: canModifyProject
                                  ? () => _openDeleteProjectSheet(project)
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: canCreateProjects
          ? FloatingActionButton.extended(
              onPressed: () => _openProjectSheet(),
              icon: const Icon(Icons.add),
              label: const Text('Nuovo Progetto'),
            )
          : null,
    );
  }

  double? _parseNullableDouble(String raw) {
    final value = raw.trim().replaceAll(',', '.');
    if (value.isEmpty) {
      return null;
    }
    return double.tryParse(value);
  }

  bool _canModifyProject(User currentUser, Project project) {
    if (currentUser.role == UserRole.admin ||
        currentUser.role == UserRole.manager) {
      return true;
    }

    if (currentUser.role == UserRole.teamLead) {
      return project.ownerUserId == currentUser.id;
    }

    if (currentUser.role == UserRole.employee &&
        currentUser.canCreateProjects) {
      return project.createdByUserId == currentUser.id &&
          project.assignedUserIds.contains(currentUser.id);
    }

    return false;
  }
}
