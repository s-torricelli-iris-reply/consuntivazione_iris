import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/commessa_model.dart';
import '../models/project_model.dart';
import '../models/timesheet_entry.dart';
import '../models/user_model.dart';
import '../models/vacation_request_model.dart';
import '../utils/work_calendar_utils.dart';
import 'firebase_sync_service.dart';

class DataService extends ChangeNotifier {
  List<User> _users = [];
  List<Project> _projects = [];
  List<Commessa> _commesse = [];
  List<TimesheetEntry> _timesheetEntries = [];
  List<VacationRequest> _vacationRequests = [];
  bool _isLoading = false;
  StreamSubscription<List<User>>? _usersSubscription;
  StreamSubscription<List<Project>>? _projectsSubscription;
  StreamSubscription<List<Commessa>>? _commesseSubscription;
  StreamSubscription<List<TimesheetEntry>>? _timesheetSubscription;
  StreamSubscription<List<VacationRequest>>? _vacationRequestsSubscription;
  final StreamController<int> _realtimeTickController =
      StreamController<int>.broadcast();
  int _realtimeTick = 0;

  final FirebaseSyncService _firebaseSync = FirebaseSyncService();

  List<User> get users => _users;
  List<Project> get projects => _projects;
  List<Commessa> get commesse => _commesse;
  List<TimesheetEntry> get timesheetEntries => _timesheetEntries;
  List<VacationRequest> get vacationRequests => _vacationRequests;
  bool get isLoading => _isLoading;
  Stream<int> get realtimeTickStream => _realtimeTickController.stream;
  int get realtimeTick => _realtimeTick;

  static const String _usersKey = 'users';
  static const String _projectsKey = 'projects';
  static const String _commesseKey = 'commesse';
  static const String _timesheetKey = 'timesheet_entries';
  static const String _vacationRequestsKey = 'vacation_requests';

  Future<void> initialize() async {
    _isLoading = true;
    _cancelRealtimeListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      var hasRemoteData = false;
      if (_firebaseSync.isEnabled) {
        hasRemoteData = await _loadFromFirebase();
        _startRealtimeListeners();
      }

      if (!hasRemoteData) {
        await _loadFromLocal(prefs);
      }

      if (!_firebaseSync.isEnabled && _projects.isEmpty) {
        await _createSampleProjects();
      }
      await _ensureSystemProjects();
      await _ensureVacationProjectsForTeamLeads();
      if (!_firebaseSync.isEnabled) {
        await _ensureDefaultAdminUser();
      }

      await _saveUsers(syncRemote: false);
      await _saveProjects(syncRemote: false);
      await _saveCommesse(syncRemote: false);
      await _saveTimesheetEntries(syncRemote: false);
      await _saveVacationRequests(syncRemote: false);
    } catch (e) {
      debugPrint('Error initializing data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshFromRemote() async {
    if (!_firebaseSync.isEnabled) {
      await initialize();
      return;
    }

    _isLoading = true;
    notifyListeners();
    try {
      await _loadFromFirebase();
      await _ensureSystemProjects();
      await _ensureVacationProjectsForTeamLeads();
      await _saveUsers(syncRemote: false);
      await _saveProjects(syncRemote: false);
      await _saveCommesse(syncRemote: false);
      await _saveTimesheetEntries(syncRemote: false);
      await _saveVacationRequests(syncRemote: false);
      _emitRealtimeTick();
    } catch (e) {
      debugPrint('Error refreshing Firebase data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startRealtimeListeners() {
    if (!_firebaseSync.isEnabled) {
      return;
    }

    _usersSubscription = _firebaseSync.watchUsers().listen(
      (users) async {
        _users = users;
        _emitRealtimeTick();
        await _saveUsers(syncRemote: false);
        await _ensureVacationProjectsForTeamLeads();
      },
      onError: (error) {
        debugPrint('Realtime users error: $error');
      },
    );

    _projectsSubscription = _firebaseSync.watchProjects().listen(
      (projects) async {
        _projects = projects;
        _emitRealtimeTick();
        await _saveProjects(syncRemote: false);
        await _ensureVacationProjectsForTeamLeads();
      },
      onError: (error) {
        debugPrint('Realtime projects error: $error');
      },
    );

    _commesseSubscription = _firebaseSync.watchCommesse().listen(
      (commesse) async {
        _commesse = commesse;
        _emitRealtimeTick();
        await _saveCommesse(syncRemote: false);
      },
      onError: (error) {
        debugPrint('Realtime commesse error: $error');
      },
    );

    _timesheetSubscription = _firebaseSync.watchTimesheetEntries().listen(
      (entries) async {
        _timesheetEntries = entries;
        _emitRealtimeTick();
        await _saveTimesheetEntries(syncRemote: false);
      },
      onError: (error) {
        debugPrint('Realtime timesheet error: $error');
      },
    );

    _vacationRequestsSubscription = _firebaseSync
        .watchVacationRequests()
        .listen(
          (requests) async {
            _vacationRequests = requests;
            _emitRealtimeTick();
            await _saveVacationRequests(syncRemote: false);
          },
          onError: (error) {
            debugPrint('Realtime vacation requests error: $error');
          },
        );
  }

  void _cancelRealtimeListeners() {
    _usersSubscription?.cancel();
    _projectsSubscription?.cancel();
    _commesseSubscription?.cancel();
    _timesheetSubscription?.cancel();
    _vacationRequestsSubscription?.cancel();
    _usersSubscription = null;
    _projectsSubscription = null;
    _commesseSubscription = null;
    _timesheetSubscription = null;
    _vacationRequestsSubscription = null;
  }

  void _emitRealtimeTick() {
    _realtimeTick++;
    if (!_realtimeTickController.isClosed) {
      _realtimeTickController.add(_realtimeTick);
    }
  }

  Future<bool> _loadFromFirebase() async {
    try {
      final remoteUsers = await _firebaseSync.fetchUsers();
      final remoteProjects = await _firebaseSync.fetchProjects();
      final remoteCommesse = await _firebaseSync.fetchCommesse();
      final remoteEntries = await _firebaseSync.fetchTimesheetEntries();
      final remoteVacationRequests = await _firebaseSync
          .fetchVacationRequests();

      _users = remoteUsers;
      _projects = remoteProjects;
      _commesse = remoteCommesse;
      _timesheetEntries = remoteEntries;
      _vacationRequests = remoteVacationRequests;

      return remoteUsers.isNotEmpty ||
          remoteProjects.isNotEmpty ||
          remoteCommesse.isNotEmpty ||
          remoteEntries.isNotEmpty ||
          remoteVacationRequests.isNotEmpty;
    } catch (e) {
      debugPrint('Error loading Firebase data: $e');
      return false;
    }
  }

  Future<void> _loadFromLocal(SharedPreferences prefs) async {
    final usersJson = prefs.getString(_usersKey);
    if (usersJson != null) {
      final List<dynamic> usersList = json.decode(usersJson);
      _users = usersList.map((u) => User.fromJson(u)).toList();
    }

    final projectsJson = prefs.getString(_projectsKey);
    if (projectsJson != null) {
      final List<dynamic> projectsList = json.decode(projectsJson);
      _projects = projectsList.map((p) => Project.fromJson(p)).toList();
    }

    final commesseJson = prefs.getString(_commesseKey);
    if (commesseJson != null) {
      final List<dynamic> commesseList = json.decode(commesseJson);
      _commesse = commesseList.map((c) => Commessa.fromJson(c)).toList();
    }

    final timesheetJson = prefs.getString(_timesheetKey);
    if (timesheetJson != null) {
      final List<dynamic> timesheetList = json.decode(timesheetJson);
      _timesheetEntries = timesheetList
          .map((t) => TimesheetEntry.fromJson(t))
          .toList();
    }

    final vacationRequestsJson = prefs.getString(_vacationRequestsKey);
    if (vacationRequestsJson != null) {
      final List<dynamic> requestsList = json.decode(vacationRequestsJson);
      _vacationRequests = requestsList
          .map((r) => VacationRequest.fromJson(r))
          .toList();
    }
  }

  Future<void> _createSampleProjects() async {
    _projects = [
      Project(
        id: 'proj_001',
        name: 'IRIS Mobile App',
        description: 'Sviluppo applicazione mobile',
        color: '#FF6B6B',
        createdAt: DateTime.now(),
      ),
      Project(
        id: 'proj_002',
        name: 'Dashboard Admin',
        description: 'Pannello di amministrazione',
        color: '#4ECDC4',
        createdAt: DateTime.now(),
      ),
      Project(
        id: 'proj_003',
        name: 'API Backend',
        description: 'Sviluppo API REST',
        color: '#FFE66D',
        createdAt: DateTime.now(),
      ),
      Project(
        id: 'proj_ferie',
        name: 'Ferie',
        description: 'Giornata di ferie o permesso',
        color: '#10B981',
        createdAt: DateTime.now(),
      ),
    ];
    await _saveProjects();
  }

  Future<void> _ensureSystemProjects() async {
    final hasVacationProject = _projects.any(
      (p) => p.name.toLowerCase().trim() == 'ferie',
    );

    if (!hasVacationProject) {
      _projects.add(
        Project(
          id: 'proj_ferie_${DateTime.now().millisecondsSinceEpoch}',
          name: 'Ferie',
          description: 'Giornata di ferie o permesso',
          color: '#10B981',
          createdAt: DateTime.now(),
        ),
      );
      await _saveProjects();
    }
  }

  Future<void> _ensureVacationProjectsForTeamLeads() async {
    if (_users.isEmpty) {
      return;
    }

    final now = DateTime.now();
    var changed = false;
    final teamLeads = _users
        .where((u) => u.role == UserRole.teamLead && u.isActive)
        .toList();

    for (final tl in teamLeads) {
      final expectedName = _vacationProjectNameForTeamLead(tl);
      final assignedUserIds = <String>{
        tl.id,
        ...getDevelopersForTeamLead(tl.id).map((u) => u.id),
      }.toList()..sort();
      final expectedId = _vacationProjectIdForTeamLead(tl);
      final existingIndex = _projects.indexWhere(
        (project) =>
            project.id == expectedId ||
            (project.ownerUserId == tl.id && isVacationProject(project)),
      );

      if (existingIndex == -1) {
        _projects.add(
          Project(
            id: expectedId,
            name: expectedName,
            description: 'Assenze, ferie e permessi del team ${tl.fullName}.',
            color: '#10B981',
            ownerUserId: tl.id,
            assignedUserIds: assignedUserIds,
            createdAt: now,
          ),
        );
        changed = true;
        continue;
      }

      final existing = _projects[existingIndex];
      final needsUpdate =
          existing.name != expectedName ||
          existing.ownerUserId != tl.id ||
          !_sameStringSet(existing.assignedUserIds, assignedUserIds) ||
          !existing.isActive;
      if (needsUpdate) {
        _projects[existingIndex] = existing.copyWith(
          name: expectedName,
          description: 'Assenze, ferie e permessi del team ${tl.fullName}.',
          ownerUserId: tl.id,
          assignedUserIds: assignedUserIds,
          isActive: true,
        );
        changed = true;
      }
    }

    if (changed) {
      await _saveProjects(syncRemote: false);
      if (_firebaseSync.isEnabled) {
        for (final project in _projects.where(isVacationProject)) {
          try {
            await _firebaseSync.upsertProject(project);
          } catch (e) {
            debugPrint('Firebase upsert vacation project error: $e');
          }
        }
      }
    }
  }

  String _vacationProjectNameForTeamLead(User teamLead) {
    final surname = teamLead.surname.trim().isEmpty
        ? teamLead.name.trim()
        : teamLead.surname.trim();
    return 'Assenze/Ferie_$surname';
  }

  String _vacationProjectIdForTeamLead(User teamLead) {
    final safeId = teamLead.id.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9_]+'),
      '_',
    );
    return 'proj_assenze_ferie_$safeId';
  }

  bool _sameStringSet(List<String> a, List<String> b) {
    final left = a.toSet();
    final right = b.toSet();
    return left.length == right.length && left.containsAll(right);
  }

  Future<void> _ensureDefaultAdminUser() async {
    if (_firebaseSync.isEnabled) {
      return;
    }

    final hasAdmin = _users.any((u) => u.role == UserRole.admin);
    if (hasAdmin) {
      return;
    }

    _users.add(
      User(
        id: 'admin_001',
        email: 'admin@iris.com',
        name: 'Admin',
        surname: 'IRIS',
        role: UserRole.admin,
        createdAt: DateTime.now(),
      ),
    );
    await _saveUsers();
  }

  Future<void> addUser(User user) async {
    _users.add(user);
    await _saveUsers(syncRemote: false);
    await _ensureVacationProjectsForTeamLeads();

    if (_firebaseSync.isEnabled) {
      try {
        await _firebaseSync.upsertUser(user);
      } catch (e) {
        debugPrint('Firebase upsertUser error: $e');
      }
    }
  }

  Future<void> updateUser(User user) async {
    final index = _users.indexWhere((u) => u.id == user.id);
    if (index != -1) {
      _users[index] = user;
      await _saveUsers(syncRemote: false);
      await _ensureVacationProjectsForTeamLeads();

      if (_firebaseSync.isEnabled) {
        try {
          await _firebaseSync.upsertUser(user);
        } catch (e) {
          debugPrint('Firebase upsertUser error: $e');
        }
      }
    }
  }

  Future<void> deleteUser(String userId) async {
    _users.removeWhere((u) => u.id == userId);
    await _saveUsers(syncRemote: false);
    await _ensureVacationProjectsForTeamLeads();

    if (_firebaseSync.isEnabled) {
      try {
        await _firebaseSync.deleteUser(userId);
      } catch (e) {
        debugPrint('Firebase deleteUser error: $e');
      }
    }
  }

  Future<void> addProject(Project project) async {
    if (project.isBillable &&
        (project.commessaId == null || project.commessaId!.trim().isEmpty)) {
      throw Exception('Per i progetti fatturabili la commessa e obbligatoria.');
    }
    _projects.add(project);
    await _saveProjects(syncRemote: false);

    if (_firebaseSync.isEnabled) {
      try {
        await _firebaseSync.upsertProject(project);
      } catch (e) {
        debugPrint('Firebase upsertProject error: $e');
      }
    }
  }

  Future<void> updateProject(Project project) async {
    if (project.isBillable &&
        (project.commessaId == null || project.commessaId!.trim().isEmpty)) {
      throw Exception('Per i progetti fatturabili la commessa e obbligatoria.');
    }
    final index = _projects.indexWhere((p) => p.id == project.id);
    if (index != -1) {
      _projects[index] = project;
      await _saveProjects(syncRemote: false);

      if (_firebaseSync.isEnabled) {
        try {
          await _firebaseSync.upsertProject(project);
        } catch (e) {
          debugPrint('Firebase upsertProject error: $e');
        }
      }
    }
  }

  Future<void> deleteProject(String projectId) async {
    _projects.removeWhere((p) => p.id == projectId);
    await _saveProjects(syncRemote: false);

    if (_firebaseSync.isEnabled) {
      try {
        await _firebaseSync.deleteProject(projectId);
      } catch (e) {
        debugPrint('Firebase deleteProject error: $e');
      }
    }
  }

  Future<void> addCommessa(Commessa commessa) async {
    _commesse.add(commessa);
    await _saveCommesse(syncRemote: false);

    if (_firebaseSync.isEnabled) {
      try {
        await _firebaseSync.upsertCommessa(commessa);
      } catch (e) {
        debugPrint('Firebase upsertCommessa error: $e');
      }
    }
  }

  Future<void> updateCommessa(Commessa commessa) async {
    final index = _commesse.indexWhere((c) => c.id == commessa.id);
    if (index == -1) {
      return;
    }

    _commesse[index] = commessa;
    await _saveCommesse(syncRemote: false);

    if (_firebaseSync.isEnabled) {
      try {
        await _firebaseSync.upsertCommessa(commessa);
      } catch (e) {
        debugPrint('Firebase upsertCommessa error: $e');
      }
    }
  }

  Future<void> deleteCommessa(String commessaId) async {
    _commesse.removeWhere((c) => c.id == commessaId);
    for (var i = 0; i < _projects.length; i++) {
      final project = _projects[i];
      if (project.commessaId == commessaId) {
        _projects[i] = project.copyWith(commessaId: null, isBillable: false);
      }
    }
    await _saveCommesse(syncRemote: false);
    await _saveProjects(syncRemote: false);

    if (_firebaseSync.isEnabled) {
      try {
        await _firebaseSync.deleteCommessa(commessaId);
      } catch (e) {
        debugPrint('Firebase deleteCommessa error: $e');
      }
    }
  }

  Future<bool> addTimesheetEntry(TimesheetEntry entry, {User? actor}) async {
    final dailyTotal = getDailyHours(entry.userId, entry.date);
    if (dailyTotal + entry.hours > 8.0) {
      return false;
    }

    if (actor != null) {
      if (actor.role == UserRole.employee && actor.id != entry.userId) {
        return false;
      }

      final project = getProjectById(entry.projectId);
      if (project == null || !canTrackProject(user: actor, project: project)) {
        return false;
      }
    }

    final linkedProject = getProjectById(entry.projectId);
    if (linkedProject != null &&
        linkedProject.isBillable &&
        (entry.commessaId == null || entry.commessaId!.trim().isEmpty)) {
      return false;
    }

    _timesheetEntries.add(entry);
    await _saveTimesheetEntries(syncRemote: false);

    if (_firebaseSync.isEnabled) {
      try {
        await _firebaseSync.upsertTimesheetEntry(entry);
      } catch (e) {
        debugPrint('Firebase upsertTimesheetEntry error: $e');
      }
    }
    return true;
  }

  Future<bool> updateTimesheetEntry(TimesheetEntry entry, {User? actor}) async {
    final index = _timesheetEntries.indexWhere((t) => t.id == entry.id);
    if (index != -1) {
      if (actor != null) {
        if (actor.role == UserRole.employee && actor.id != entry.userId) {
          return false;
        }

        final project = getProjectById(entry.projectId);
        if (project == null ||
            !canTrackProject(user: actor, project: project)) {
          return false;
        }
      }

      final linkedProject = getProjectById(entry.projectId);
      if (linkedProject != null &&
          linkedProject.isBillable &&
          (entry.commessaId == null || entry.commessaId!.trim().isEmpty)) {
        return false;
      }

      final otherEntries = _timesheetEntries.where(
        (t) =>
            t.userId == entry.userId &&
            t.date.year == entry.date.year &&
            t.date.month == entry.date.month &&
            t.date.day == entry.date.day &&
            t.id != entry.id,
      );

      final otherHours = otherEntries.fold<double>(
        0,
        (sum, t) => sum + t.hours,
      );
      if (otherHours + entry.hours > 8.0) {
        return false;
      }

      _timesheetEntries[index] = entry;
      await _saveTimesheetEntries(syncRemote: false);

      if (_firebaseSync.isEnabled) {
        try {
          await _firebaseSync.upsertTimesheetEntry(entry);
        } catch (e) {
          debugPrint('Firebase upsertTimesheetEntry error: $e');
        }
      }
      return true;
    }
    return false;
  }

  Future<void> deleteTimesheetEntry(String entryId) async {
    _timesheetEntries.removeWhere((t) => t.id == entryId);
    await _saveTimesheetEntries(syncRemote: false);

    if (_firebaseSync.isEnabled) {
      try {
        await _firebaseSync.deleteTimesheetEntry(entryId);
      } catch (e) {
        debugPrint('Firebase deleteTimesheetEntry error: $e');
      }
    }
  }

  Future<void> addVacationRequest(VacationRequest request) async {
    _vacationRequests.add(request);
    await _saveVacationRequests(syncRemote: false);

    if (_firebaseSync.isEnabled) {
      try {
        await _firebaseSync.upsertVacationRequest(request);
      } catch (e) {
        debugPrint('Firebase upsertVacationRequest error: $e');
      }
    }
  }

  Future<void> approveVacationRequest({
    required String requestId,
    required User reviewer,
    String? reviewerNote,
  }) async {
    final index = _vacationRequests.indexWhere((r) => r.id == requestId);
    if (index == -1) {
      return;
    }

    final request = _vacationRequests[index];
    if (request.approverUserId != reviewer.id &&
        reviewer.role != UserRole.admin &&
        reviewer.role != UserRole.manager) {
      return;
    }

    final updated = request.copyWith(
      status: VacationRequestStatus.approved,
      reviewerUserId: reviewer.id,
      reviewerNote: reviewerNote,
      reviewedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _vacationRequests[index] = updated;
    await _saveVacationRequests(syncRemote: false);

    if (_firebaseSync.isEnabled) {
      try {
        await _firebaseSync.upsertVacationRequest(updated);
      } catch (e) {
        debugPrint('Firebase upsertVacationRequest error: $e');
      }
    }

    await _createVacationTimesheetEntries(updated, actor: reviewer);
  }

  Future<void> rejectVacationRequest({
    required String requestId,
    required User reviewer,
    String? reviewerNote,
    DateTime? suggestedStartDate,
    DateTime? suggestedEndDate,
  }) async {
    final index = _vacationRequests.indexWhere((r) => r.id == requestId);
    if (index == -1) {
      return;
    }

    final request = _vacationRequests[index];
    if (request.approverUserId != reviewer.id &&
        reviewer.role != UserRole.admin &&
        reviewer.role != UserRole.manager) {
      return;
    }

    final updated = request.copyWith(
      status: VacationRequestStatus.rejected,
      reviewerUserId: reviewer.id,
      reviewerNote: reviewerNote,
      suggestedStartDate: suggestedStartDate,
      suggestedEndDate: suggestedEndDate,
      reviewedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _vacationRequests[index] = updated;
    await _saveVacationRequests(syncRemote: false);

    if (_firebaseSync.isEnabled) {
      try {
        await _firebaseSync.upsertVacationRequest(updated);
      } catch (e) {
        debugPrint('Firebase upsertVacationRequest error: $e');
      }
    }
  }

  Future<void> _createVacationTimesheetEntries(
    VacationRequest request, {
    required User actor,
  }) async {
    final requester = getUserById(request.requesterUserId);
    if (requester == null) {
      return;
    }

    final vacationProject = getVacationProjectForUser(requester);
    if (vacationProject == null) {
      return;
    }

    var cursor = DateUtils.dateOnly(request.startDate);
    final end = DateUtils.dateOnly(request.endDate);
    while (!cursor.isAfter(end)) {
      final hours = (request.dayFraction * 8.0).clamp(0.5, 8.0).toDouble();
      final availableHours = 8.0 - getDailyHours(requester.id, cursor);
      if (isWorkingDay(cursor) && availableHours >= hours) {
        await addTimesheetEntry(
          TimesheetEntry(
            id: 'entry_ferie_${request.id}_${cursor.millisecondsSinceEpoch}',
            userId: requester.id,
            projectId: vacationProject.id,
            date: cursor,
            hours: hours,
            notes: 'Ferie approvate',
            createdAt: DateTime.now(),
          ),
          actor: actor,
        );
      }
      cursor = cursor.add(const Duration(days: 1));
    }
  }

  double getDailyHours(String userId, DateTime date) {
    final entries = _timesheetEntries.where(
      (t) =>
          t.userId == userId &&
          t.date.year == date.year &&
          t.date.month == date.month &&
          t.date.day == date.day,
    );
    return entries.fold<double>(0, (sum, t) => sum + t.hours);
  }

  List<TimesheetEntry> getEntriesForUser(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) {
    return _timesheetEntries
        .where(
          (t) =>
              t.userId == userId &&
              t.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
              t.date.isBefore(endDate.add(const Duration(days: 1))),
        )
        .toList();
  }

  List<TimesheetEntry> getEntriesForDate(String userId, DateTime date) {
    return _timesheetEntries
        .where(
          (t) =>
              t.userId == userId &&
              t.date.year == date.year &&
              t.date.month == date.month &&
              t.date.day == date.day,
        )
        .toList();
  }

  List<TimesheetEntry> getEntriesForProject(
    String projectId, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final normalizedStart = startDate != null
        ? DateUtils.dateOnly(startDate)
        : null;
    final normalizedEnd = endDate != null ? DateUtils.dateOnly(endDate) : null;

    return _timesheetEntries.where((entry) {
      if (entry.projectId != projectId) {
        return false;
      }

      final entryDate = DateUtils.dateOnly(entry.date);
      final inStart =
          normalizedStart == null || !entryDate.isBefore(normalizedStart);
      final inEnd = normalizedEnd == null || !entryDate.isAfter(normalizedEnd);
      return inStart && inEnd;
    }).toList();
  }

  double getProjectTotalHours(
    String projectId, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final entries = getEntriesForProject(
      projectId,
      startDate: startDate,
      endDate: endDate,
    );
    return entries.fold<double>(0, (sum, entry) => sum + entry.hours);
  }

  Map<String, double> getHoursByUserForProject(
    String projectId, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final result = <String, double>{};
    final entries = getEntriesForProject(
      projectId,
      startDate: startDate,
      endDate: endDate,
    );

    for (final entry in entries) {
      result[entry.userId] = (result[entry.userId] ?? 0) + entry.hours;
    }
    return result;
  }

  Map<String, double> getHoursByProjectForUser(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final result = <String, double>{};
    final normalizedStart = startDate != null
        ? DateUtils.dateOnly(startDate)
        : null;
    final normalizedEnd = endDate != null ? DateUtils.dateOnly(endDate) : null;

    for (final entry in _timesheetEntries) {
      if (entry.userId != userId) {
        continue;
      }

      final entryDate = DateUtils.dateOnly(entry.date);
      if (normalizedStart != null && entryDate.isBefore(normalizedStart)) {
        continue;
      }
      if (normalizedEnd != null && entryDate.isAfter(normalizedEnd)) {
        continue;
      }

      result[entry.projectId] = (result[entry.projectId] ?? 0) + entry.hours;
    }
    return result;
  }

  Future<void> _saveUsers({bool syncRemote = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _usersKey,
      json.encode(_users.map((u) => u.toJson()).toList()),
    );

    if (syncRemote && _firebaseSync.isEnabled) {
      try {
        await _firebaseSync.syncUsers(_users);
      } catch (e) {
        debugPrint('Firebase syncUsers error: $e');
      }
    }

    notifyListeners();
  }

  Future<void> _saveProjects({bool syncRemote = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _projectsKey,
      json.encode(_projects.map((p) => p.toJson()).toList()),
    );

    if (syncRemote && _firebaseSync.isEnabled) {
      try {
        await _firebaseSync.syncProjects(_projects);
      } catch (e) {
        debugPrint('Firebase syncProjects error: $e');
      }
    }

    notifyListeners();
  }

  Future<void> _saveCommesse({bool syncRemote = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _commesseKey,
      json.encode(_commesse.map((c) => c.toJson()).toList()),
    );

    if (syncRemote && _firebaseSync.isEnabled) {
      try {
        await _firebaseSync.syncCommesse(_commesse);
      } catch (e) {
        debugPrint('Firebase syncCommesse error: $e');
      }
    }

    notifyListeners();
  }

  Future<void> _saveTimesheetEntries({bool syncRemote = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _timesheetKey,
      json.encode(_timesheetEntries.map((t) => t.toJson()).toList()),
    );

    if (syncRemote && _firebaseSync.isEnabled) {
      try {
        await _firebaseSync.syncTimesheetEntries(_timesheetEntries);
      } catch (e) {
        debugPrint('Firebase syncTimesheetEntries error: $e');
      }
    }

    notifyListeners();
  }

  Future<void> _saveVacationRequests({bool syncRemote = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _vacationRequestsKey,
      json.encode(_vacationRequests.map((r) => r.toJson()).toList()),
    );

    if (syncRemote && _firebaseSync.isEnabled) {
      try {
        await _firebaseSync.syncVacationRequests(_vacationRequests);
      } catch (e) {
        debugPrint('Firebase syncVacationRequests error: $e');
      }
    }

    notifyListeners();
  }

  Project? getProjectById(String projectId) {
    try {
      return _projects.firstWhere((p) => p.id == projectId);
    } catch (e) {
      return null;
    }
  }

  Commessa? getCommessaById(String commessaId) {
    try {
      return _commesse.firstWhere((c) => c.id == commessaId);
    } catch (e) {
      return null;
    }
  }

  List<Commessa> getActiveCommesse() {
    return _commesse.where((c) => c.isActive).toList()
      ..sort((a, b) => a.codice.compareTo(b.codice));
  }

  User? getUserById(String userId) {
    try {
      return _users.firstWhere((u) => u.id == userId);
    } catch (e) {
      return null;
    }
  }

  List<User> getUsersByRole(UserRole role) {
    return _users.where((u) => u.role == role && u.isActive).toList();
  }

  List<User> getTeamLeadsForManager(String managerId) {
    final manager = getUserById(managerId);
    return _users
        .where(
          (u) =>
              u.role == UserRole.teamLead &&
              _matchesUserReference(
                reference: u.managerId,
                userId: managerId,
                userEmail: manager?.email,
              ) &&
              u.isActive,
        )
        .toList();
  }

  List<User> getDevelopersForTeamLead(String teamLeadId) {
    final teamLead = getUserById(teamLeadId);
    return _users
        .where(
          (u) =>
              _isTeamContributor(u) &&
              _matchesUserReference(
                reference: u.teamLeadId,
                userId: teamLeadId,
                userEmail: teamLead?.email,
              ) &&
              u.isActive,
        )
        .toList();
  }

  List<User> getDevelopersForManager(String managerId) {
    final teamLeads = getTeamLeadsForManager(managerId);
    return _users
        .where(
          (u) =>
              _isTeamContributor(u) &&
              u.teamLeadId != null &&
              teamLeads.any(
                (tl) => _matchesUserReference(
                  reference: u.teamLeadId,
                  userId: tl.id,
                  userEmail: tl.email,
                ),
              ) &&
              u.isActive,
        )
        .toList();
  }

  bool _isTeamContributor(User user) {
    if (!user.isActive) {
      return false;
    }

    if (user.role == UserRole.employee) {
      return true;
    }

    // Optional mode: an admin can also be tracked as a team contributor
    // when explicitly assigned to a Team Lead.
    if (user.role == UserRole.admin) {
      return user.teamLeadId != null && user.teamLeadId!.trim().isNotEmpty;
    }

    return false;
  }

  List<User> getTeamMembersForUser(User user) {
    switch (user.role) {
      case UserRole.admin:
        return _users
            .where((u) => u.role != UserRole.admin && u.isActive)
            .toList();
      case UserRole.manager:
        return [
          ...getTeamLeadsForManager(user.id),
          ...getDevelopersForManager(user.id),
        ];
      case UserRole.teamLead:
        return getDevelopersForTeamLead(user.id);
      case UserRole.employee:
        return [user];
    }
  }

  List<User> getVacationApproversForUser(User user) {
    if (user.role == UserRole.teamLead) {
      final managers = getUsersByRole(UserRole.manager);
      final directManager = user.managerId == null
          ? null
          : getUserById(user.managerId!);
      return [
        if (directManager != null && directManager.isActive) directManager,
        ...managers.where((m) => m.id != directManager?.id),
      ];
    }

    if (user.teamLeadId != null && user.teamLeadId!.trim().isNotEmpty) {
      final teamLeads = getUsersByRole(UserRole.teamLead);
      final directTeamLead = _findUserByReference(
        reference: user.teamLeadId!,
        expectedRole: UserRole.teamLead,
      );
      final fallbackUsers = user.role == UserRole.admin
          ? _users.where((u) => u.isActive && u.id != user.id)
          : teamLeads.where((tl) => tl.id != directTeamLead?.id);
      return [
        if (directTeamLead != null && directTeamLead.isActive) directTeamLead,
        ...fallbackUsers.where((u) => u.id != directTeamLead?.id),
      ];
    }

    if (user.role == UserRole.admin) {
      return _users.where((u) => u.isActive && u.id != user.id).toList();
    }

    if (user.role == UserRole.manager) {
      return _users
          .where(
            (u) =>
                u.isActive &&
                u.id != user.id &&
                (u.role == UserRole.manager || u.role == UserRole.admin),
          )
          .toList();
    }

    final teamLeads = getUsersByRole(UserRole.teamLead);
    return teamLeads;
  }

  User? _findUserByReference({
    required String reference,
    UserRole? expectedRole,
  }) {
    final normalized = reference.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }

    for (final user in _users) {
      if (!user.isActive) {
        continue;
      }
      if (expectedRole != null && user.role != expectedRole) {
        continue;
      }
      if (user.id.trim().toLowerCase() == normalized ||
          user.email.trim().toLowerCase() == normalized) {
        return user;
      }
    }
    return null;
  }

  List<VacationRequest> getVacationRequestsForRequester(String userId) {
    return _vacationRequests.where((r) => r.requesterUserId == userId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<VacationRequest> getVacationRequestsForApprover(String userId) {
    return _vacationRequests.where((r) => r.approverUserId == userId).toList()
      ..sort((a, b) {
        final statusCompare = a.status.index.compareTo(b.status.index);
        if (statusCompare != 0) {
          return statusCompare;
        }
        return b.createdAt.compareTo(a.createdAt);
      });
  }

  List<VacationRequest> getVacationRequestsVisibleForReviewer(User reviewer) {
    final visibleApproverIds = <String>{reviewer.id};

    if (reviewer.role == UserRole.admin) {
      return _sortVacationRequests(_vacationRequests.toList());
    }

    if (reviewer.role == UserRole.manager) {
      visibleApproverIds.addAll(
        getTeamLeadsForManager(reviewer.id).map((tl) => tl.id),
      );
    }

    return _sortVacationRequests(
      _vacationRequests
          .where(
            (request) => visibleApproverIds.contains(request.approverUserId),
          )
          .toList(),
    );
  }

  List<VacationRequest> _sortVacationRequests(List<VacationRequest> requests) {
    return requests..sort((a, b) {
      final statusCompare = a.status.index.compareTo(b.status.index);
      if (statusCompare != 0) {
        return statusCompare;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  Project? getVacationProjectForUser(User user) {
    if (user.role == UserRole.teamLead) {
      return getVacationProjectForTeamLead(user.id);
    }
    if (user.teamLeadId != null && user.teamLeadId!.trim().isNotEmpty) {
      return getVacationProjectForTeamLead(user.teamLeadId!);
    }
    for (final project in _projects) {
      if (project.isActive &&
          isVacationProject(project) &&
          project.assignedUserIds.contains(user.id)) {
        return project;
      }
    }
    return null;
  }

  Project? getVacationProjectForTeamLead(String teamLeadId) {
    for (final project in _projects) {
      if (project.isActive &&
          project.ownerUserId == teamLeadId &&
          isVacationProject(project)) {
        return project;
      }
    }
    return null;
  }

  List<Project> getProjectsVisibleForUser(User user) {
    final activeProjects = _projects.where((p) => p.isActive).toList();

    switch (user.role) {
      case UserRole.admin:
      case UserRole.manager:
        return activeProjects;
      case UserRole.teamLead:
        return activeProjects.where((p) => p.ownerUserId == user.id).toList();
      case UserRole.employee:
        return activeProjects
            .where((p) => p.assignedUserIds.contains(user.id))
            .toList();
    }
  }

  bool canAccessProject({required User viewer, required Project project}) {
    switch (viewer.role) {
      case UserRole.admin:
      case UserRole.manager:
        return true;
      case UserRole.teamLead:
        return project.ownerUserId == viewer.id ||
            (isVacationProject(project) &&
                project.assignedUserIds.contains(viewer.id));
      case UserRole.employee:
        return project.assignedUserIds.contains(viewer.id);
    }
  }

  bool canTrackProject({required User user, required Project project}) {
    switch (user.role) {
      case UserRole.admin:
      case UserRole.manager:
        return true;
      case UserRole.teamLead:
        return project.ownerUserId == user.id ||
            (isVacationProject(project) &&
                project.assignedUserIds.contains(user.id));
      case UserRole.employee:
        return project.assignedUserIds.contains(user.id);
    }
  }

  bool hasUserWorkedOnProject(String userId, String projectId) {
    return _timesheetEntries.any(
      (entry) => entry.userId == userId && entry.projectId == projectId,
    );
  }

  double getProjectConsumedCost(
    String projectId, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final project = getProjectById(projectId);
    if (project == null || project.hourlyCost == null) {
      return 0;
    }
    final hours = getProjectTotalHours(
      projectId,
      startDate: startDate,
      endDate: endDate,
    );
    return hours * project.hourlyCost!;
  }

  double getProjectEstimatedRevenue(
    String projectId, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final project = getProjectById(projectId);
    if (project == null || project.hourlyRate == null) {
      return 0;
    }
    final hours = getProjectTotalHours(
      projectId,
      startDate: startDate,
      endDate: endDate,
    );
    return hours * project.hourlyRate!;
  }

  double getProjectGrossMargin(
    String projectId, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final revenue = getProjectEstimatedRevenue(
      projectId,
      startDate: startDate,
      endDate: endDate,
    );
    final cost = getProjectConsumedCost(
      projectId,
      startDate: startDate,
      endDate: endDate,
    );
    return revenue - cost;
  }

  double getProjectBudgetBurnRate(
    String projectId, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final project = getProjectById(projectId);
    if (project == null || project.estimatedBudget == null) {
      return 0;
    }
    if (project.estimatedBudget! <= 0) {
      return 0;
    }
    final consumed = getProjectConsumedCost(
      projectId,
      startDate: startDate,
      endDate: endDate,
    );
    return consumed / project.estimatedBudget!;
  }

  double getProjectForecastMonthlyCost(
    String projectId,
    DateTime monthReference,
  ) {
    final project = getProjectById(projectId);
    if (project == null || project.hourlyCost == null) {
      return 0;
    }

    final monthStart = DateTime(monthReference.year, monthReference.month, 1);
    final monthEnd = DateTime(monthReference.year, monthReference.month + 1, 0);
    final today = DateTime.now();
    final trackedEnd =
        (today.year == monthReference.year &&
            today.month == monthReference.month)
        ? DateUtils.dateOnly(today)
        : monthEnd;

    final consumedHours = getProjectTotalHours(
      projectId,
      startDate: monthStart,
      endDate: trackedEnd,
    );
    final elapsedWorkingDays = getWorkingDaysInRange(monthStart, trackedEnd);
    final totalWorkingDays = getWorkingDaysInRange(monthStart, monthEnd);

    if (elapsedWorkingDays == 0 || totalWorkingDays == 0) {
      return consumedHours * project.hourlyCost!;
    }

    final dailyAvg = consumedHours / elapsedWorkingDays;
    final forecastHours = dailyAvg * totalWorkingDays;
    return forecastHours * project.hourlyCost!;
  }

  bool isVacationProject(Project project) {
    final normalized = project.name.toLowerCase().trim();
    return normalized.contains('ferie');
  }

  bool canViewUser({required User viewer, required User target}) {
    // Requirement: every authenticated user can open person details.
    return viewer.isActive && target.isActive;
  }

  bool _matchesUserReference({
    required String? reference,
    required String userId,
    String? userEmail,
  }) {
    if (reference == null || reference.trim().isEmpty) {
      return false;
    }

    final normalizedRef = reference.trim().toLowerCase();
    if (normalizedRef == userId.trim().toLowerCase()) {
      return true;
    }

    if (userEmail != null && userEmail.trim().isNotEmpty) {
      final normalizedEmail = userEmail.trim().toLowerCase();
      if (normalizedRef == normalizedEmail) {
        return true;
      }
    }

    return false;
  }

  bool isWorkingDay(DateTime date) {
    final day = DateUtils.dateOnly(date);
    final isWeekday =
        day.weekday >= DateTime.monday && day.weekday <= DateTime.friday;
    return isWeekday && !WorkCalendarUtils.isItalianPublicHoliday(day);
  }

  int getWorkingDaysInRange(DateTime startDate, DateTime endDate) {
    final start = DateUtils.dateOnly(startDate);
    final end = DateUtils.dateOnly(endDate);
    if (end.isBefore(start)) {
      return 0;
    }

    var current = start;
    var workingDays = 0;
    while (!current.isAfter(end)) {
      if (isWorkingDay(current)) {
        workingDays++;
      }
      current = current.add(const Duration(days: 1));
    }
    return workingDays;
  }

  int getWorkingDaysInMonth(DateTime monthReference) {
    final start = DateTime(monthReference.year, monthReference.month, 1);
    final end = DateTime(monthReference.year, monthReference.month + 1, 0);
    return getWorkingDaysInRange(start, end);
  }

  DateTime getPenultimateWorkingDay(DateTime monthReference) {
    return _nthWorkingDayFromMonthEnd(monthReference, 2);
  }

  DateTime getLastWorkingDay(DateTime monthReference) {
    return _nthWorkingDayFromMonthEnd(monthReference, 1);
  }

  DateTime _nthWorkingDayFromMonthEnd(DateTime monthReference, int n) {
    var cursor = DateTime(monthReference.year, monthReference.month + 1, 0);
    var found = 0;
    while (true) {
      if (isWorkingDay(cursor)) {
        found++;
        if (found == n) {
          return DateUtils.dateOnly(cursor);
        }
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }
  }

  int getPerfectDaysCount({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
    double perfectThreshold = 8.0,
  }) {
    final dailyHours = <DateTime, double>{};
    final entries = getEntriesForUser(userId, startDate, endDate);
    for (final entry in entries) {
      final day = DateUtils.dateOnly(entry.date);
      dailyHours[day] = (dailyHours[day] ?? 0) + entry.hours;
    }

    return dailyHours.entries
        .where(
          (entry) => isWorkingDay(entry.key) && entry.value >= perfectThreshold,
        )
        .length;
  }

  int getCurrentStreak(String userId, {DateTime? referenceDate}) {
    final today = DateUtils.dateOnly(referenceDate ?? DateTime.now());
    var cursor = today;

    if (isWorkingDay(cursor) && getDailyHours(userId, cursor) < 8.0) {
      cursor = _previousWorkingDay(cursor);
    }

    var streak = 0;
    while (isWorkingDay(cursor) && getDailyHours(userId, cursor) >= 8.0) {
      streak++;
      cursor = _previousWorkingDay(cursor);
    }
    return streak;
  }

  int getMonthlyExperience(String userId, DateTime monthReference) {
    final monthStart = DateTime(monthReference.year, monthReference.month, 1);
    final monthEnd = DateTime(monthReference.year, monthReference.month + 1, 0);
    final entries = getEntriesForUser(userId, monthStart, monthEnd);
    final totalHours = entries.fold<double>(
      0,
      (sum, entry) => sum + entry.hours,
    );
    final perfectDays = getPerfectDaysCount(
      userId: userId,
      startDate: monthStart,
      endDate: monthEnd,
    );
    return (totalHours * 10).round() + (perfectDays * 25);
  }

  TeamMonthlyKpi getMonthlyKpiForUsers({
    required List<User> users,
    required DateTime monthReference,
  }) {
    final monthStart = DateTime(monthReference.year, monthReference.month, 1);
    final monthEnd = DateTime(monthReference.year, monthReference.month + 1, 0);
    final targetWorkingDays = getWorkingDaysInRange(monthStart, monthEnd);
    final targetPerUser = targetWorkingDays * 8.0;

    if (users.isEmpty) {
      return TeamMonthlyKpi.empty(monthReference);
    }

    final userIds = users.map((u) => u.id).toSet();
    var totalHours = 0.0;
    var totalPerfectDays = 0;
    var totalDelayDays = 0;
    var delayedEntries = 0;

    for (final user in users) {
      final userEntries = getEntriesForUser(user.id, monthStart, monthEnd);
      final userHours = userEntries.fold<double>(
        0,
        (sum, entry) => sum + entry.hours,
      );
      totalHours += userHours;
      totalPerfectDays += getPerfectDaysCount(
        userId: user.id,
        startDate: monthStart,
        endDate: monthEnd,
      );
    }

    for (final entry in _timesheetEntries) {
      if (!userIds.contains(entry.userId)) {
        continue;
      }
      if (entry.date.isBefore(monthStart) || entry.date.isAfter(monthEnd)) {
        continue;
      }
      final createdDay = DateUtils.dateOnly(entry.createdAt);
      final entryDay = DateUtils.dateOnly(entry.date);
      final delay = createdDay.difference(entryDay).inDays;
      if (delay > 0) {
        totalDelayDays += delay;
        delayedEntries++;
      }
    }

    final targetTotal = targetPerUser * users.length;
    final completionRate = targetTotal <= 0 ? 0.0 : totalHours / targetTotal;
    final overtimeUnderTime = totalHours - targetTotal;
    final avgHoursPerUser = totalHours / users.length;
    final saturationRate = targetPerUser <= 0
        ? 0.0
        : avgHoursPerUser / targetPerUser;
    final dsoAverageDays = delayedEntries == 0
        ? 0.0
        : totalDelayDays / delayedEntries;
    final qualityScore = (users.length * targetWorkingDays) == 0
        ? 0.0
        : totalPerfectDays / (users.length * targetWorkingDays);

    return TeamMonthlyKpi(
      monthReference: DateTime(monthReference.year, monthReference.month, 1),
      targetWorkingDays: targetWorkingDays,
      targetHoursTotal: targetTotal,
      actualHoursTotal: totalHours,
      completionRate: completionRate,
      overtimeUnderTimeHours: overtimeUnderTime,
      saturationRate: saturationRate,
      dsoAverageDays: dsoAverageDays,
      qualityScore: qualityScore,
    );
  }

  DateTime _previousWorkingDay(DateTime date) {
    var cursor = date.subtract(const Duration(days: 1));
    while (!isWorkingDay(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return cursor;
  }

  @override
  void dispose() {
    _cancelRealtimeListeners();
    _realtimeTickController.close();
    super.dispose();
  }
}

class TeamMonthlyKpi {
  final DateTime monthReference;
  final int targetWorkingDays;
  final double targetHoursTotal;
  final double actualHoursTotal;
  final double completionRate;
  final double overtimeUnderTimeHours;
  final double saturationRate;
  final double dsoAverageDays;
  final double qualityScore;

  const TeamMonthlyKpi({
    required this.monthReference,
    required this.targetWorkingDays,
    required this.targetHoursTotal,
    required this.actualHoursTotal,
    required this.completionRate,
    required this.overtimeUnderTimeHours,
    required this.saturationRate,
    required this.dsoAverageDays,
    required this.qualityScore,
  });

  factory TeamMonthlyKpi.empty(DateTime monthReference) {
    return TeamMonthlyKpi(
      monthReference: DateTime(monthReference.year, monthReference.month, 1),
      targetWorkingDays: 0,
      targetHoursTotal: 0,
      actualHoursTotal: 0,
      completionRate: 0,
      overtimeUnderTimeHours: 0,
      saturationRate: 0,
      dsoAverageDays: 0,
      qualityScore: 0,
    );
  }
}
