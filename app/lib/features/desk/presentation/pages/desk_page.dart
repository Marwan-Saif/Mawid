import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../places/presentation/cubit/home_cubit.dart';
import '../../domain/entities/desk_board.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/repositories/desk_repository.dart';
import '../cubit/audit_cubit.dart';
import '../cubit/desk_cubit.dart';
import '../cubit/invoices_cubit.dart';
import '../cubit/waiting_display_cubit.dart';
import '../l10n/desk_strings.dart';
import '../widgets/audit_view.dart';
import '../widgets/invoice_editor_sheet.dart';
import '../widgets/queue_widgets.dart';
import '../widgets/walk_in_sheet.dart';
import 'invoice_page.dart';
import 'scan_page.dart';
import 'waiting_display_page.dart';

/// The front desk: today's queue, invoices and the log, for the owner or the receptionist.
/// Expects [DeskCubit], [InvoicesCubit] and [AuditCubit] above it.
class DeskPage extends StatelessWidget {
  const DeskPage({super.key, required this.repository});

  /// For the screens this page opens (waiting screen, one invoice's history).
  final DeskRepository repository;

  @override
  Widget build(BuildContext context) {
    final d = context.desk;
    final l10n = context.l10n;
    return BlocListener<DeskCubit, DeskState>(
      listenWhen: (a, b) => b.notice != null && a.notice != b.notice,
      listener: (context, state) {
        final n = state.notice!;
        final fmt = Fmt.of(context);
        if (n.failure != null) {
          showMessage(context, d.failure(n.failure!, l10n));
        } else if (n.called != null) {
          showMessage(context, d.calledToast);
        } else if (n.checkedIn != null) {
          final b = n.checkedIn!;
          showMessage(context,
              d.checkedIn(b.customerName ?? b.customerPhone ?? '', b.ticketNo == null ? '…' : fmt.number(b.ticketNo!)));
        }
        if (n.failure == null) context.read<AuditCubit>().load();
      },
      child: DefaultTabController(
        length: 3,
        child: BlocBuilder<DeskCubit, DeskState>(
          builder: (context, state) {
            final cubit = context.read<DeskCubit>();
            final board = state.board;
            return Scaffold(
              appBar: AppBar(
                title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(board?.place.name(l10n.localeName) ?? d.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(d.title, style: Theme.of(context).textTheme.labelMedium),
                ]),
                actions: [
                  IconButton(
                    tooltip: d.walkIn,
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    onPressed: board == null ? null : () => showWalkInSheet(context, cubit, board),
                  ),
                  IconButton(
                    tooltip: d.waitingScreen,
                    icon: const Icon(Icons.tv_outlined),
                    onPressed: board == null ? null : () => _openDisplay(context, board.place.slug),
                  ),
                  if (repository.canSimulateOffline)
                    PopupMenuButton<String>(
                      onSelected: (_) => cubit.toggleSimulatedOffline(),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'offline',
                          child: Text(state.simulatingOffline ? d.endSimulation : d.simulateOffline),
                        ),
                      ],
                    ),
                ],
                bottom: TabBar(tabs: [
                  Tab(text: d.tabQueue, icon: const Icon(Icons.groups_outlined)),
                  Tab(text: d.tabInvoices, icon: const Icon(Icons.receipt_long_outlined)),
                  Tab(text: d.tabLog, icon: const Icon(Icons.history)),
                ]),
              ),
              floatingActionButton: board == null
                  ? null
                  : FloatingActionButton.extended(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute<bool>(
                        builder: (_) => ScanPage(onCode: cubit.scan),
                      )),
                      icon: const Icon(Icons.qr_code_scanner),
                      label: Text(d.scan),
                    ),
              body: Column(
                children: [
                  SyncBanner(state: state),
                  Expanded(
                    child: TabBarView(children: [
                      _QueueTab(state: state, onInvoice: (e) => _invoiceFor(context, e)),
                      _InvoicesTab(board: board, repository: repository),
                      board == null ? const SizedBox.shrink() : AuditView(timezone: board.place.timezone),
                    ]),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _invoiceFor(BuildContext context, QueueEntry entry) async {
    final board = context.read<DeskCubit>().state.board;
    if (board == null) return;
    final saved = await showInvoiceEditor(
      context,
      cubit: context.read<InvoicesCubit>(),
      services: board.services,
      currency: board.place.currency,
      visit: entry,
    );
    if (saved != null && context.mounted) {
      context.read<DeskCubit>().load(silent: true);
      context.read<AuditCubit>().load();
      _openInvoice(context, saved, board, repository);
    }
  }

  void _openDisplay(BuildContext context, String slug) {
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => BlocProvider(
        create: (_) => WaitingDisplayCubit(repository, slug)..start(),
        child: const WaitingDisplayPage(),
      ),
    ));
  }
}

void _openInvoice(BuildContext context, Invoice inv, DeskBoard board, DeskRepository repository) {
  final invoices = context.read<InvoicesCubit>();
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: invoices),
        BlocProvider(create: (_) => AuditCubit(repository, entityType: 'INVOICE', entityId: inv.id)..load()),
      ],
      child: InvoicePage(invoiceId: inv.id, place: board.place, services: board.services),
    ),
  ));
}

class _QueueTab extends StatelessWidget {
  const _QueueTab({required this.state, required this.onInvoice});

  final DeskState state;
  final void Function(QueueEntry) onInvoice;

  @override
  Widget build(BuildContext context) {
    final d = context.desk;
    final cubit = context.read<DeskCubit>();
    final board = state.board;
    if (board == null) {
      if (state.status == LoadStatus.failure) return ErrorView(failure: state.failure!, onRetry: cubit.load);
      return const Padding(padding: EdgeInsets.all(AppSpace.lg), child: SkeletonList());
    }
    List<Widget> section(String title, List<QueueEntry> list, {bool invoices = false}) => [
          SectionHeader(title: '$title (${Fmt.of(context).number(list.length)})'),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.sm),
              child: Text(d.nobodyHere, style: TextStyle(color: context.colors.textSecondary)),
            ),
          for (final e in list)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.sm),
              child: QueueTile(entry: e, board: board, busy: state.busyId == e.id, onInvoice: invoices ? onInvoice : null),
            ),
        ];

    return RefreshIndicator(
      onRefresh: cubit.load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, 96),
        children: [
          CountsRow(counts: board.counts),
          const SizedBox(height: AppSpace.lg),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: board.staff.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpace.sm),
              itemBuilder: (_, i) =>
                  StaffCard(staff: board.staff[i], board: board, busy: state.busyId == board.staff[i].id),
            ),
          ),
          ...section(d.inRoom, board.inRoom),
          ...section(d.waiting, board.waiting),
          ...section(d.notArrived, board.notArrived),
          ...section(d.finished, board.finished, invoices: true),
        ],
      ),
    );
  }
}

class _InvoicesTab extends StatefulWidget {
  const _InvoicesTab({required this.board, required this.repository});

  final DeskBoard? board;
  final DeskRepository repository;

  @override
  State<_InvoicesTab> createState() => _InvoicesTabState();
}

class _InvoicesTabState extends State<_InvoicesTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    context.read<InvoicesCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final d = context.desk;
    final board = widget.board;
    return BlocBuilder<InvoicesCubit, InvoicesState>(
      builder: (context, state) {
        final cubit = context.read<InvoicesCubit>();
        if (state.status == LoadStatus.loading && state.invoices.isEmpty) {
          return const Padding(padding: EdgeInsets.all(AppSpace.lg), child: SkeletonList());
        }
        if (state.status == LoadStatus.failure && state.invoices.isEmpty) {
          return ErrorView(failure: state.failure!, onRetry: cubit.load);
        }
        final fmt = Fmt.of(context);
        final c = context.colors;
        return RefreshIndicator(
          onRefresh: cubit.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, 96),
            children: [
              if (board != null)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final saved = await showInvoiceEditor(context,
                          cubit: cubit, services: board.services, currency: board.place.currency);
                      if (saved != null && context.mounted) {
                        context.read<AuditCubit>().load();
                        _openInvoice(context, saved, board, widget.repository);
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: Text(d.newInvoice),
                  ),
                ),
              const SizedBox(height: AppSpace.md),
              if (state.invoices.isEmpty) EmptyState(icon: Icons.receipt_long_outlined, title: d.noInvoices),
              for (final inv in state.invoices)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.sm),
                  child: AppCard(
                    onTap: board == null ? null : () => _openInvoice(context, inv, board, widget.repository),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(inv.number == null ? d.provisional : '#${inv.number}',
                              style: Theme.of(context).textTheme.titleSmall),
                          Text(inv.customerName, style: Theme.of(context).textTheme.bodySmall),
                          if (inv.edited && board != null)
                            Text(d.editedAt(fmt.time(inv.updatedAt!, board.place.timezone)),
                                style: TextStyle(color: c.warning, fontSize: 12, fontWeight: FontWeight.w600)),
                          if (inv.pendingSync)
                            Text(d.notSentYet, style: TextStyle(color: c.textSecondary, fontSize: 12)),
                        ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(fmt.money(inv.total, inv.currency), style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          d.status(inv.status),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: switch (inv.status) {
                              InvoiceStatus.paid => c.success,
                              InvoiceStatus.voided => c.danger,
                              InvoiceStatus.issued => c.warning,
                            },
                          ),
                        ),
                      ]),
                    ]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
