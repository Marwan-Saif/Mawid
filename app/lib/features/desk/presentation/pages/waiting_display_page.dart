import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/desk_board.dart';
import '../../domain/entities/waiting_display.dart';
import '../cubit/waiting_display_cubit.dart';
import '../l10n/desk_strings.dart';
import '../services/announcer.dart';

/// The waiting-room screen for a tablet or a TV running the app (the server also serves the same
/// screen at /w/{slug} for any browser). Dark, huge numbers, speaks every call.
class WaitingDisplayPage extends StatefulWidget {
  const WaitingDisplayPage({super.key, this.announcer});

  final Announcer? announcer;

  @override
  State<WaitingDisplayPage> createState() => _WaitingDisplayPageState();
}

class _WaitingDisplayPageState extends State<WaitingDisplayPage> with SingleTickerProviderStateMixin {
  late final Announcer _announcer = widget.announcer ?? Announcer();
  late final AnimationController _flash =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  late final Timer _clock;

  static const _bg = Color(0xFF0B1220);
  static const _panel = Color(0xFF111A2E);
  static const _border = Color(0xFF23324D);
  static const _text = Color(0xFFE2E8F0);
  static const _muted = Color(0xFFA3B3C9);
  static const _accent = Color(0xFF38BDF8);
  static const _ok = Color(0xFF34D399);
  static const _busy = Color(0xFFFBBF24);

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    _flash.dispose();
    _announcer.stop();
    super.dispose();
  }

  void _onCall(BuildContext context, DisplayCall call) {
    final d = context.desk;
    final fmt = Fmt.of(context);
    if (!(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      _flash.forward(from: 0).then((_) => _flash.reverse());
    }
    _announcer.say(d.spokenCall(fmt.number(call.ticketNo), call.name, call.room), language: d.ttsLanguage);
  }

  @override
  Widget build(BuildContext context) {
    final d = context.desk;
    final fmt = Fmt.of(context);
    final lang = context.l10n.localeName;
    return BlocConsumer<WaitingDisplayCubit, WaitingDisplayState>(
      listenWhen: (a, b) => b.announce != null && a.announce != b.announce,
      listener: (context, s) => _onCall(context, s.announce!),
      builder: (context, s) {
        final data = s.display;
        final width = MediaQuery.sizeOf(context).width;
        final wide = width > 900;
        final scale = (width / 1280).clamp(0.6, 1.6).toDouble();
        TextStyle t(double size, {FontWeight w = FontWeight.w600, Color color = _text}) =>
            TextStyle(fontSize: size * scale, fontWeight: w, color: color, height: 1.15);

        final call = data?.lastCall;
        final callPanel = AnimatedBuilder(
          animation: _flash,
          builder: (context, child) => Container(
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Color.lerp(_border, _accent, _flash.value)!, width: 2 + 6 * _flash.value),
            ),
            padding: const EdgeInsets.all(24),
            child: child,
          ),
          child: Semantics(
            liveRegion: true,
            child: Center(
              child: call == null
                  ? Text(d.idleCall, style: t(28, color: _muted))
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(d.nowCalling, style: t(22, color: _muted)),
                      const SizedBox(height: 8),
                      Text(fmt.number(call.ticketNo), style: t(150, w: FontWeight.w800, color: _accent)),
                      Text(call.name, style: t(48, w: FontWeight.w700)),
                      if (call.room != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          decoration: BoxDecoration(
                              color: _bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: _border)),
                          child: Text(call.room!, style: t(36, w: FontWeight.w700)),
                        ),
                      ],
                      if (call.staffName != null) ...[
                        const SizedBox(height: 10),
                        Text(call.staffName!, style: t(20, color: _muted)),
                      ],
                    ]),
            ),
          ),
        );

        final team = Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final st in data?.staff ?? const <DisplayStaff>[])
              Container(
                width: 240 * scale,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(st.name, style: t(20, w: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(st.room ?? (lang == 'ar' ? st.titleAr : st.titleEn), style: t(16, color: _muted)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.circle, size: 12 * scale, color: st.presence == StaffPresence.available ? _ok : _busy),
                    const SizedBox(width: 6),
                    Text(d.presence(st.presence),
                        style: t(16, w: FontWeight.w700, color: st.presence == StaffPresence.available ? _ok : _busy)),
                  ]),
                  if (st.nowServingTicket != null)
                    Text(d.nowServing(fmt.number(st.nowServingTicket!)), style: t(15, color: _muted)),
                ]),
              ),
          ],
        );

        final waiting = data?.waiting ?? const <DisplayEntry>[];
        final queue = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${d.waiting} (${fmt.number(waiting.length)})', style: t(20, color: _muted)),
          const SizedBox(height: 8),
          if (waiting.isEmpty) Text(d.nobodyWaiting, style: t(22, color: _muted)),
          for (final w in waiting.take(8))
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: _border))),
              child: Row(children: [
                SizedBox(width: 80 * scale, child: Text(fmt.number(w.ticketNo), style: t(30, w: FontWeight.w800, color: _accent))),
                Expanded(child: Text(w.name, style: t(26), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Expanded(child: Text(w.room ?? w.staffName ?? '', style: t(20, color: _muted), maxLines: 1)),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(w.etaMin <= 1 ? d.now : d.etaMinutes(fmt.number(w.etaMin)), style: t(24)),
                  if (w.delayMin >= 5) Text(d.delay(fmt.number(w.delayMin)), style: t(15, w: FontWeight.w700, color: _busy)),
                ]),
              ]),
            ),
        ]);

        Widget panel(Widget child) => Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: _border)),
              child: child,
            );

        final header = Row(children: [
          Expanded(
            child: Text(data?.place.name(lang) ?? '…', style: t(34, w: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (!s.online)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 16),
              child: Row(children: [
                Icon(Icons.wifi_off, color: _busy, size: 22 * scale),
                const SizedBox(width: 6),
                if (s.lastUpdate != null && data != null)
                  Text(d.lastUpdate(fmt.time(s.lastUpdate!, data.place.timezone)), style: t(16, color: _busy)),
              ]),
            ),
          if (data != null) Text(fmt.time(DateTime.now().toUtc(), data.place.timezone), style: t(34, w: FontWeight.w700)),
          const SizedBox(width: 12),
          IconButton(
            tooltip: _announcer.enabled ? d.soundOff : d.soundOn,
            color: _text,
            iconSize: 28 * scale,
            onPressed: () => setState(() => _announcer.enabled = !_announcer.enabled),
            icon: Icon(_announcer.enabled ? Icons.volume_up : Icons.volume_off),
          ),
          IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            color: _muted,
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.close),
          ),
        ]);

        return Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(20 * scale),
              child: wide
                  ? Column(children: [
                      header,
                      const SizedBox(height: 16),
                      Expanded(
                        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Expanded(flex: 11, child: callPanel),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 10,
                            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(d.doctors, style: t(20, color: _muted)),
                                const SizedBox(height: 10),
                                team,
                              ])),
                              const SizedBox(height: 16),
                              Expanded(child: panel(SingleChildScrollView(child: queue))),
                            ]),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      Text(d.displayHint, style: t(16, color: _muted)),
                    ])
                  : ListView(children: [
                      header,
                      const SizedBox(height: 16),
                      SizedBox(height: 380 * scale, child: callPanel),
                      const SizedBox(height: 16),
                      panel(team),
                      const SizedBox(height: 16),
                      panel(queue),
                      const SizedBox(height: 12),
                      Text(d.displayHint, style: t(16, color: _muted)),
                    ]),
            ),
          ),
        );
      },
    );
  }
}
