import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../models/vacation_request_model.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_reveal.dart';

class VacationRequestsScreen extends StatefulWidget {
  const VacationRequestsScreen({super.key});

  @override
  State<VacationRequestsScreen> createState() => _VacationRequestsScreenState();
}

class _VacationRequestsScreenState extends State<VacationRequestsScreen> {
  DateTimeRange? _selectedRange;
  String? _selectedApproverId;
  final TextEditingController _motivationController = TextEditingController();

  @override
  void dispose() {
    _motivationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final dataService = context.watch<DataService>();
    final currentUser = authService.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final approvers = dataService.getVacationApproversForUser(currentUser);
    if (_selectedApproverId != null &&
        !approvers.any((user) => user.id == _selectedApproverId)) {
      _selectedApproverId = null;
    }
    _selectedApproverId ??= approvers.isEmpty ? null : approvers.first.id;

    final incoming = dataService.getVacationRequestsForApprover(currentUser.id);
    final mine = dataService.getVacationRequestsForRequester(currentUser.id);
    final pendingIncoming = incoming
        .where((request) => request.status == VacationRequestStatus.pending)
        .length;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('Richieste ferie')),
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
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedReveal(
                  delay: const Duration(milliseconds: 50),
                  child: _VacationHero(
                    pendingIncoming: pendingIncoming,
                    myPending: mine
                        .where(
                          (request) =>
                              request.status == VacationRequestStatus.pending,
                        )
                        .length,
                  ),
                ),
                const SizedBox(height: 14),
                AnimatedReveal(
                  delay: const Duration(milliseconds: 90),
                  child: _RequestFormCard(
                    selectedRange: _selectedRange,
                    selectedApproverId: _selectedApproverId,
                    approvers: approvers,
                    motivationController: _motivationController,
                    onPickRange: () => _pickRange(context),
                    onApproverChanged: (value) {
                      setState(() {
                        _selectedApproverId = value;
                      });
                    },
                    onSubmit: approvers.isEmpty
                        ? null
                        : () => _submitRequest(
                            context: context,
                            currentUser: currentUser,
                            dataService: dataService,
                          ),
                  ),
                ),
                if (currentUser.role != UserRole.employee ||
                    incoming.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text('Da approvare', style: AppTheme.heading3),
                  const SizedBox(height: 10),
                  if (incoming.isEmpty)
                    const _EmptyPanel(text: 'Nessuna richiesta ricevuta.')
                  else
                    ...incoming.map(
                      (request) => _VacationRequestCard(
                        request: request,
                        requester: dataService.getUserById(
                          request.requesterUserId,
                        ),
                        approver: dataService.getUserById(
                          request.approverUserId,
                        ),
                        reviewer: request.reviewerUserId == null
                            ? null
                            : dataService.getUserById(request.reviewerUserId!),
                        canReview:
                            request.status == VacationRequestStatus.pending &&
                            (request.approverUserId == currentUser.id ||
                                currentUser.role == UserRole.admin ||
                                currentUser.role == UserRole.manager),
                        onApprove: () => _approveRequest(
                          context: context,
                          dataService: dataService,
                          currentUser: currentUser,
                          request: request,
                        ),
                        onReject: () => _rejectRequest(
                          context: context,
                          dataService: dataService,
                          currentUser: currentUser,
                          request: request,
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 18),
                const Text('Le mie richieste', style: AppTheme.heading3),
                const SizedBox(height: 10),
                if (mine.isEmpty)
                  const _EmptyPanel(text: 'Non hai ancora richieste ferie.')
                else
                  ...mine.map(
                    (request) => _VacationRequestCard(
                      request: request,
                      requester: dataService.getUserById(
                        request.requesterUserId,
                      ),
                      approver: dataService.getUserById(request.approverUserId),
                      reviewer: request.reviewerUserId == null
                          ? null
                          : dataService.getUserById(request.reviewerUserId!),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickRange(BuildContext context) async {
    final now = DateUtils.dateOnly(DateTime.now());
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 2, 12, 31),
      initialDateRange: _selectedRange ?? DateTimeRange(start: now, end: now),
      locale: const Locale('it'),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _selectedRange = DateTimeRange(
        start: DateUtils.dateOnly(picked.start),
        end: DateUtils.dateOnly(picked.end),
      );
    });
  }

  Future<void> _submitRequest({
    required BuildContext context,
    required User currentUser,
    required DataService dataService,
  }) async {
    final range = _selectedRange;
    final approverId = _selectedApproverId;
    final motivation = _motivationController.text.trim();
    if (range == null || approverId == null || motivation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleziona periodo, destinatario e motivazione.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final workingDays = dataService.getWorkingDaysInRange(
      range.start,
      range.end,
    );
    if (workingDays == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Il periodo scelto non contiene giorni lavorativi.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    await dataService.addVacationRequest(
      VacationRequest(
        id: 'vac_${DateTime.now().millisecondsSinceEpoch}',
        requesterUserId: currentUser.id,
        approverUserId: approverId,
        startDate: range.start,
        endDate: range.end,
        workingDays: workingDays,
        motivation: motivation,
        createdAt: DateTime.now(),
      ),
    );

    if (!context.mounted) {
      return;
    }
    setState(() {
      _selectedRange = null;
      _motivationController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Richiesta ferie inviata.'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  Future<void> _approveRequest({
    required BuildContext context,
    required DataService dataService,
    required User currentUser,
    required VacationRequest request,
  }) async {
    await dataService.approveVacationRequest(
      requestId: request.id,
      reviewer: currentUser,
    );
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Richiesta accettata e ferie consuntivate.'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  Future<void> _rejectRequest({
    required BuildContext context,
    required DataService dataService,
    required User currentUser,
    required VacationRequest request,
  }) async {
    final noteController = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Respingi richiesta'),
        content: TextField(
          controller: noteController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motivazione risposta',
            prefixIcon: Icon(Icons.edit_note_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(noteController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Respingi'),
          ),
        ],
      ),
    );
    noteController.dispose();
    if (note == null) {
      return;
    }

    await dataService.rejectVacationRequest(
      requestId: request.id,
      reviewer: currentUser,
      reviewerNote: note.isEmpty ? null : note,
    );
  }
}

class _VacationHero extends StatelessWidget {
  final int pendingIncoming;
  final int myPending;

  const _VacationHero({required this.pendingIncoming, required this.myPending});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.beach_access_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ferie e assenze',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$myPending tue in lavorazione • $pendingIncoming da approvare',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
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

class _RequestFormCard extends StatelessWidget {
  final DateTimeRange? selectedRange;
  final String? selectedApproverId;
  final List<User> approvers;
  final TextEditingController motivationController;
  final VoidCallback onPickRange;
  final ValueChanged<String?> onApproverChanged;
  final VoidCallback? onSubmit;

  const _RequestFormCard({
    required this.selectedRange,
    required this.selectedApproverId,
    required this.approvers,
    required this.motivationController,
    required this.onPickRange,
    required this.onApproverChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final rangeLabel = selectedRange == null
        ? 'Seleziona periodo'
        : '${DateFormat('d MMM', 'it').format(selectedRange!.start)} - ${DateFormat('d MMM yyyy', 'it').format(selectedRange!.end)}';

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
          const Text('Nuova richiesta', style: AppTheme.heading3),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 260,
                child: OutlinedButton.icon(
                  onPressed: onPickRange,
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(rangeLabel),
                ),
              ),
              SizedBox(
                width: 300,
                child: DropdownButtonFormField<String>(
                  initialValue: selectedApproverId,
                  decoration: const InputDecoration(
                    labelText: 'Destinatario',
                    prefixIcon: Icon(Icons.supervisor_account_outlined),
                  ),
                  items: approvers
                      .map(
                        (user) => DropdownMenuItem(
                          value: user.id,
                          child: Text(
                            '${user.fullName} • ${user.role.displayName}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: onApproverChanged,
                ),
              ),
            ],
          ),
          if (approvers.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Nessun destinatario disponibile: assegna TL o Manager al profilo.',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.warningColor),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: motivationController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Motivazione',
              prefixIcon: Icon(Icons.edit_note_outlined),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: onSubmit,
              icon: const Icon(Icons.send_outlined),
              label: const Text('Invia richiesta'),
            ),
          ),
        ],
      ),
    );
  }
}

class _VacationRequestCard extends StatelessWidget {
  final VacationRequest request;
  final User? requester;
  final User? approver;
  final User? reviewer;
  final bool canReview;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _VacationRequestCard({
    required this.request,
    required this.requester,
    required this.approver,
    required this.reviewer,
    this.canReview = false,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (request.status) {
      VacationRequestStatus.pending => AppTheme.warningColor,
      VacationRequestStatus.approved => AppTheme.successColor,
      VacationRequestStatus.rejected => AppTheme.errorColor,
    };
    final dateLabel =
        '${DateFormat('d MMM', 'it').format(request.startDate)} - ${DateFormat('d MMM yyyy', 'it').format(request.endDate)}';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE8F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.event_available_outlined, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      requester?.fullName ?? 'Utente',
                      style: AppTheme.bodyLarge,
                    ),
                    Text(
                      '$dateLabel • ${request.workingDays} gg lavorativi',
                      style: AppTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: request.status, color: color),
            ],
          ),
          const SizedBox(height: 10),
          Text(request.motivation, style: AppTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(
            'Verso: ${approver?.fullName ?? 'N/D'}'
            '${reviewer == null ? '' : ' • Gestita da: ${reviewer!.fullName}'}',
            style: AppTheme.caption,
          ),
          if (request.reviewerNote != null &&
              request.reviewerNote!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Nota: ${request.reviewerNote}', style: AppTheme.bodySmall),
          ],
          if (canReview) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close),
                    label: const Text('Respingi'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check),
                    label: const Text('Accetta'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final VacationRequestStatus status;
  final Color color;

  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.displayName,
        style: AppTheme.caption.copyWith(color: color),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final String text;

  const _EmptyPanel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE8F9)),
      ),
      child: Text(text, style: AppTheme.bodyMedium),
    );
  }
}
