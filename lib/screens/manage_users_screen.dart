import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_reveal.dart';
import 'person_detail_screen.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  String _searchQuery = '';

  Future<void> _openUserSheet({User? user}) async {
    final dataService = context.read<DataService>();
    final authService = context.read<AuthService>();
    final actor = authService.currentUser;
    if (actor == null) {
      return;
    }

    final canEditFullProfile = actor.role == UserRole.admin;
    if (!canEditFullProfile && user == null) {
      return;
    }

    final canDelegateProjectCreation =
        user != null && _canDelegateProjectCreation(actor, user, dataService);
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: user?.name ?? '');
    final surnameController = TextEditingController(text: user?.surname ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');

    UserRole selectedRole = user?.role ?? UserRole.employee;
    DeveloperType? selectedType = user?.developerType;
    String? selectedManagerId = user?.managerId;
    String? selectedTeamLeadId = user?.teamLeadId;
    bool isAdminContributor =
        user?.role == UserRole.admin &&
        user?.teamLeadId != null &&
        user!.teamLeadId!.trim().isNotEmpty;
    bool canCreateProjects = user?.canCreateProjects ?? false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final media = MediaQuery.of(context);
          final managers = dataService.getUsersByRole(UserRole.manager);
          final teamLeads = dataService.getUsersByRole(UserRole.teamLead);
          final canShowProjectCreationSwitch =
              canEditFullProfile &&
                  (selectedRole == UserRole.employee ||
                      (selectedRole == UserRole.admin && isAdminContributor)) ||
              canDelegateProjectCreation;

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
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                        child: Form(
                          key: formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user == null
                                    ? 'Nuova persona'
                                    : canEditFullProfile
                                    ? 'Modifica persona'
                                    : 'Permessi progetto',
                                style: AppTheme.heading2.copyWith(fontSize: 26),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                canEditFullProfile
                                    ? 'Gestisci ruolo e gerarchia team (Manager -> TL -> Developer).'
                                    : 'Abilita i developer del tuo team a creare progetti in autonomia.',
                                style: AppTheme.bodyMedium,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: nameController,
                                enabled: canEditFullProfile,
                                decoration: const InputDecoration(
                                  labelText: 'Nome',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Nome richiesto';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: surnameController,
                                enabled: canEditFullProfile,
                                decoration: const InputDecoration(
                                  labelText: 'Cognome',
                                  prefixIcon: Icon(Icons.badge_outlined),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Cognome richiesto';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: emailController,
                                enabled: canEditFullProfile,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.email_outlined),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Email richiesta';
                                  }
                                  if (!value.contains('@')) {
                                    return 'Email non valida';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<UserRole>(
                                initialValue: selectedRole,
                                decoration: const InputDecoration(
                                  labelText: 'Ruolo',
                                  prefixIcon: Icon(
                                    Icons.workspace_premium_outlined,
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: UserRole.admin,
                                    child: Text('Admin'),
                                  ),
                                  DropdownMenuItem(
                                    value: UserRole.employee,
                                    child: Text('Developer'),
                                  ),
                                  DropdownMenuItem(
                                    value: UserRole.teamLead,
                                    child: Text('Team Lead'),
                                  ),
                                  DropdownMenuItem(
                                    value: UserRole.manager,
                                    child: Text('Manager'),
                                  ),
                                ],
                                onChanged: canEditFullProfile
                                    ? (value) {
                                        if (value == null) return;
                                        setSheetState(() {
                                          selectedRole = value;
                                          if (value == UserRole.manager ||
                                              value == UserRole.admin) {
                                            if (value == UserRole.manager) {
                                              selectedManagerId = null;
                                              selectedTeamLeadId = null;
                                              isAdminContributor = false;
                                            }
                                          } else if (value ==
                                              UserRole.teamLead) {
                                            selectedTeamLeadId = null;
                                            isAdminContributor = false;
                                          } else if (value ==
                                              UserRole.employee) {
                                            selectedManagerId = null;
                                            isAdminContributor = false;
                                          }
                                          if (value != UserRole.employee &&
                                              !(value == UserRole.admin &&
                                                  isAdminContributor)) {
                                            canCreateProjects = false;
                                          }
                                        });
                                      }
                                    : null,
                              ),
                              if (selectedRole == UserRole.admin) ...[
                                const SizedBox(height: 12),
                                SwitchListTile.adaptive(
                                  value: isAdminContributor,
                                  onChanged: canEditFullProfile
                                      ? (value) {
                                          setSheetState(() {
                                            isAdminContributor = value;
                                            if (!isAdminContributor) {
                                              selectedTeamLeadId = null;
                                              selectedManagerId = null;
                                              canCreateProjects = false;
                                            }
                                          });
                                        }
                                      : null,
                                  title: const Text(
                                    'Admin contributor sotto Team Lead',
                                  ),
                                  subtitle: const Text(
                                    'Permette di tracciare l\'admin come risorsa team.',
                                    style: AppTheme.bodySmall,
                                  ),
                                ),
                                if (isAdminContributor) ...[
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String?>(
                                    initialValue: selectedTeamLeadId,
                                    decoration: const InputDecoration(
                                      labelText: 'Team Lead di riferimento',
                                      prefixIcon: Icon(Icons.groups_outlined),
                                    ),
                                    items: [
                                      const DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text('Nessuno'),
                                      ),
                                      ...teamLeads.map(
                                        (tl) => DropdownMenuItem<String?>(
                                          value: tl.id,
                                          child: Text(tl.fullName),
                                        ),
                                      ),
                                    ],
                                    onChanged: canEditFullProfile
                                        ? (value) {
                                            setSheetState(() {
                                              selectedTeamLeadId = value;
                                              User? selectedTl;
                                              for (final tl in teamLeads) {
                                                if (tl.id == value) {
                                                  selectedTl = tl;
                                                  break;
                                                }
                                              }
                                              selectedManagerId =
                                                  selectedTl?.managerId;
                                            });
                                          }
                                        : null,
                                  ),
                                ],
                              ],
                              if (selectedRole == UserRole.teamLead) ...[
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String?>(
                                  initialValue: selectedManagerId,
                                  decoration: const InputDecoration(
                                    labelText: 'Manager di riferimento',
                                    prefixIcon: Icon(
                                      Icons.account_tree_outlined,
                                    ),
                                  ),
                                  items: [
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('Nessuno'),
                                    ),
                                    ...managers.map(
                                      (m) => DropdownMenuItem<String?>(
                                        value: m.id,
                                        child: Text(m.fullName),
                                      ),
                                    ),
                                  ],
                                  onChanged: canEditFullProfile
                                      ? (value) {
                                          setSheetState(() {
                                            selectedManagerId = value;
                                          });
                                        }
                                      : null,
                                ),
                              ],
                              if (selectedRole == UserRole.employee) ...[
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String?>(
                                  initialValue: selectedTeamLeadId,
                                  decoration: const InputDecoration(
                                    labelText: 'Team Lead di riferimento',
                                    prefixIcon: Icon(Icons.groups_outlined),
                                  ),
                                  items: [
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('Nessuno'),
                                    ),
                                    ...teamLeads.map(
                                      (tl) => DropdownMenuItem<String?>(
                                        value: tl.id,
                                        child: Text(tl.fullName),
                                      ),
                                    ),
                                  ],
                                  onChanged: canEditFullProfile
                                      ? (value) {
                                          setSheetState(() {
                                            selectedTeamLeadId = value;
                                            User? selectedTl;
                                            for (final tl in teamLeads) {
                                              if (tl.id == value) {
                                                selectedTl = tl;
                                                break;
                                              }
                                            }
                                            selectedManagerId =
                                                selectedTl?.managerId;
                                          });
                                        }
                                      : null,
                                ),
                              ],
                              const SizedBox(height: 12),
                              DropdownButtonFormField<DeveloperType>(
                                initialValue: selectedType,
                                decoration: const InputDecoration(
                                  labelText: 'Specializzazione (opzionale)',
                                  prefixIcon: Icon(Icons.code),
                                ),
                                items: DeveloperType.values
                                    .map(
                                      (type) => DropdownMenuItem(
                                        value: type,
                                        child: Text(type.displayName),
                                      ),
                                    )
                                    .toList(),
                                onChanged: canEditFullProfile
                                    ? (value) {
                                        setSheetState(() {
                                          selectedType = value;
                                        });
                                      }
                                    : null,
                              ),
                              if (canShowProjectCreationSwitch) ...[
                                const SizedBox(height: 12),
                                SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  value: canCreateProjects,
                                  title: const Text(
                                    'Può creare progetti in autonomia',
                                  ),
                                  subtitle: const Text(
                                    'Il developer potrà aggiungere progetti e assegnarli a se stesso sotto il TL di riferimento.',
                                    style: AppTheme.bodySmall,
                                  ),
                                  onChanged: (value) {
                                    setSheetState(() {
                                      canCreateProjects = value;
                                    });
                                  },
                                ),
                              ],
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

                                if (!canEditFullProfile) {
                                  if (user != null &&
                                      canDelegateProjectCreation) {
                                    await context
                                        .read<DataService>()
                                        .updateUser(
                                          user.copyWith(
                                            canCreateProjects:
                                                canCreateProjects,
                                          ),
                                        );
                                  }

                                  if (sheetContext.mounted) {
                                    Navigator.of(sheetContext).pop();
                                  }
                                  return;
                                }

                                if (user == null) {
                                  final newUser = User(
                                    id: 'user_${DateTime.now().millisecondsSinceEpoch}',
                                    email: emailController.text
                                        .trim()
                                        .toLowerCase(),
                                    name: nameController.text.trim(),
                                    surname: surnameController.text.trim(),
                                    role: selectedRole,
                                    developerType: selectedType,
                                    managerId: selectedRole == UserRole.teamLead
                                        ? selectedManagerId
                                        : selectedRole == UserRole.admin &&
                                              isAdminContributor
                                        ? selectedManagerId
                                        : null,
                                    teamLeadId:
                                        selectedRole == UserRole.employee
                                        ? selectedTeamLeadId
                                        : selectedRole == UserRole.admin &&
                                              isAdminContributor
                                        ? selectedTeamLeadId
                                        : null,
                                    canCreateProjects: canCreateProjects,
                                    createdAt: DateTime.now(),
                                  );

                                  await context.read<DataService>().addUser(
                                    newUser,
                                  );
                                } else {
                                  final updated = user.copyWith(
                                    email: emailController.text
                                        .trim()
                                        .toLowerCase(),
                                    name: nameController.text.trim(),
                                    surname: surnameController.text.trim(),
                                    role: selectedRole,
                                    developerType: selectedType,
                                    managerId: selectedRole == UserRole.teamLead
                                        ? selectedManagerId
                                        : selectedRole == UserRole.admin &&
                                              isAdminContributor
                                        ? selectedManagerId
                                        : null,
                                    teamLeadId:
                                        selectedRole == UserRole.employee
                                        ? selectedTeamLeadId
                                        : selectedRole == UserRole.admin &&
                                              isAdminContributor
                                        ? selectedTeamLeadId
                                        : null,
                                    canCreateProjects: canCreateProjects,
                                  );
                                  await context.read<DataService>().updateUser(
                                    updated,
                                  );
                                }

                                if (sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
                                }
                              },
                              icon: const Icon(Icons.check_circle_outline),
                              label: Text(user == null ? 'Crea' : 'Salva'),
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
    surnameController.dispose();
    emailController.dispose();
  }

  Future<void> _openDeleteUserSheet(User user) async {
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
              const Text('Eliminare utente?', style: AppTheme.heading3),
              const SizedBox(height: 6),
              Text(
                'Rimuovere ${user.fullName} dal team?',
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
                        await context.read<DataService>().deleteUser(user.id);
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final dataService = context.watch<DataService>();
    final currentActor = authService.currentUser;

    if (currentActor == null ||
        (currentActor.role != UserRole.admin &&
            currentActor.role != UserRole.manager &&
            currentActor.role != UserRole.teamLead)) {
      return Scaffold(
        appBar: AppBar(title: const Text('People Studio')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Accesso consentito solo a Admin, Manager e Team Lead.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final canEditFullProfile = currentActor.role == UserRole.admin;
    final users = dataService.getManageableUsersForUser(currentActor)
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
    final adminCount = users.where((u) => u.role == UserRole.admin).length;
    final managerCount = users.where((u) => u.role == UserRole.manager).length;
    final teamLeadCount = users
        .where((u) => u.role == UserRole.teamLead)
        .length;
    final developerCount = users
        .where((u) => u.role == UserRole.employee)
        .length;

    final query = _searchQuery.trim().toLowerCase();
    final filteredUsers = query.isEmpty
        ? users
        : users.where((user) {
            final fullName = user.fullName.toLowerCase();
            final email = user.email.toLowerCase();
            final role = user.role.displayName.toLowerCase();
            return fullName.contains(query) ||
                email.contains(query) ||
                role.contains(query);
          }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('People Studio')),
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
                child: _PeopleHeroCard(
                  totalPeople: users.length,
                  admins: adminCount,
                  managers: managerCount,
                  teamLeads: teamLeadCount,
                  developers: developerCount,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: AnimatedReveal(
                delay: const Duration(milliseconds: 110),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: 'Cerca persona, ruolo o email',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
            ),
            if (authService.isFirebaseMode)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    canEditFullProfile
                        ? 'Con FirebaseAuth attivo, i nuovi utenti si registrano dall’app. Qui puoi assegnare ruoli, gerarchie e permessi.'
                        : 'Qui puoi designare quali developer del tuo perimetro possono creare progetti in autonomia.',
                    style: AppTheme.bodySmall,
                  ),
                ),
              ),
            Expanded(
              child: users.isEmpty
                  ? const _UsersEmptyState()
                  : filteredUsers.isEmpty
                  ? const _UsersNoResultState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
                      itemCount: filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = filteredUsers[index];
                        return AnimatedReveal(
                          delay: Duration(milliseconds: 140 + (index * 35)),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFDCE8F9),
                              ),
                            ),
                            child: ListTile(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        PersonDetailScreen(userId: user.id),
                                  ),
                                );
                              },
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primaryColor
                                    .withValues(alpha: 0.1),
                                child: Text(
                                  user.name.isNotEmpty
                                      ? user.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(user.fullName),
                              subtitle: Text(
                                '${user.role.displayName}${user.developerType != null ? ' • ${user.developerType!.displayName}' : ''}${user.canCreateProjects ? ' • Progetti autonomi' : ''}\n${_relationshipLabel(user, dataService)}\n${user.email}',
                              ),
                              isThreeLine: true,
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _openUserSheet(user: user);
                                  }
                                  if (value == 'delete') {
                                    if (currentActor.id == user.id) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Non puoi eliminare il tuo utente.',
                                          ),
                                        ),
                                      );
                                    } else {
                                      _openDeleteUserSheet(user);
                                    }
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem<String>(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.edit_outlined),
                                        const SizedBox(width: 8),
                                        Text(
                                          canEditFullProfile
                                              ? 'Modifica'
                                              : 'Permessi progetto',
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (canEditFullProfile)
                                    const PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.delete,
                                            color: AppTheme.errorColor,
                                          ),
                                          SizedBox(width: 8),
                                          Text('Elimina'),
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
            ),
          ],
        ),
      ),
      floatingActionButton: authService.isFirebaseMode
          ? null
          : canEditFullProfile
          ? FloatingActionButton.extended(
              onPressed: () => _openUserSheet(),
              icon: const Icon(Icons.add),
              label: const Text('Aggiungi Utente'),
            )
          : null,
    );
  }

  bool _canDelegateProjectCreation(
    User actor,
    User target,
    DataService dataService,
  ) {
    if (!dataService.isTeamContributor(target)) {
      return false;
    }
    if (actor.role != UserRole.admin && target.role != UserRole.employee) {
      return false;
    }

    switch (actor.role) {
      case UserRole.admin:
        return true;
      case UserRole.manager:
        return dataService
            .getDevelopersForManager(actor.id)
            .any((developer) => developer.id == target.id);
      case UserRole.teamLead:
        return dataService
            .getDevelopersForTeamLead(actor.id)
            .any((developer) => developer.id == target.id);
      case UserRole.employee:
        return false;
    }
  }

  String _relationshipLabel(User user, DataService dataService) {
    if (user.role == UserRole.teamLead) {
      final managerName = user.managerId == null
          ? 'Manager: non assegnato'
          : 'Manager: ${dataService.getUserById(user.managerId!)?.fullName ?? 'non trovato'}';
      return managerName;
    }

    if (user.role == UserRole.employee) {
      final tl = user.teamLeadId == null
          ? null
          : dataService.getUserById(user.teamLeadId!);
      if (tl == null) {
        return 'TL: non assegnato';
      }
      final manager = tl.managerId == null
          ? null
          : dataService.getUserById(tl.managerId!);
      if (manager == null) {
        return 'TL: ${tl.fullName}';
      }
      return 'TL: ${tl.fullName} • Manager: ${manager.fullName}';
    }

    return 'Ruolo amministrativo';
  }
}

class _PeopleHeroCard extends StatelessWidget {
  final int totalPeople;
  final int admins;
  final int managers;
  final int teamLeads;
  final int developers;

  const _PeopleHeroCard({
    required this.totalPeople,
    required this.admins,
    required this.managers,
    required this.teamLeads,
    required this.developers,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'People Pulse',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$totalPeople persone attive',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _RoleMetric(label: 'Admin', value: admins.toString()),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RoleMetric(
                  label: 'Manager',
                  value: managers.toString(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RoleMetric(
                  label: 'Team Lead',
                  value: teamLeads.toString(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RoleMetric(
                  label: 'Developer',
                  value: developers.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleMetric extends StatelessWidget {
  final String label;
  final String value;

  const _RoleMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
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
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _UsersEmptyState extends StatelessWidget {
  const _UsersEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.group_outlined,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(height: 14),
          const Text('Nessun utente', style: AppTheme.heading3),
          const SizedBox(height: 6),
          const Text(
            'Aggiungi il primo membro del team.',
            style: AppTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _UsersNoResultState extends StatelessWidget {
  const _UsersNoResultState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Nessun risultato per questa ricerca.',
        style: AppTheme.bodyMedium,
      ),
    );
  }
}
