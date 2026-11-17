import 'package:flutter/material.dart';

import '../error/failures.dart';
import '../l10n/app_localizations.dart';
import '../l10n/failure_messages.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Shown when a list is empty: icon, a short title, a hint and an optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle, this.action});

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: c.primarySoft, shape: BoxShape.circle),
              child: Icon(icon, color: c.primary, size: 32),
            ),
            const SizedBox(height: AppSpace.lg),
            Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpace.xs),
              Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: AppSpace.lg), action!],
          ],
        ),
      ),
    );
  }
}

/// A failure with a retry button.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.failure, required this.onRetry});

  final Failure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: failure is OfflineFailure ? Icons.wifi_off_outlined : Icons.error_outline,
      title: failure.message(context.l10n),
      action: OutlinedButton(onPressed: onRetry, child: Text(context.l10n.retry)),
    );
  }
}

/// Placeholder blocks while content loads, so the layout doesn't jump.
class SkeletonList extends StatefulWidget {
  const SkeletonList({super.key, this.count = 4, this.height = 84});

  final int count;
  final double height;

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final block = Container(
      height: widget.height,
      decoration: BoxDecoration(color: context.colors.taken, borderRadius: BorderRadius.circular(AppRadius.md)),
    );
    return Semantics(
      label: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
      child: Column(
        children: [
          for (var i = 0; i < widget.count; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.md),
              child: reduceMotion ? block : FadeTransition(opacity: Tween(begin: 1.0, end: 0.5).animate(_pulse), child: block),
            ),
        ],
      ),
    );
  }
}

void showFailure(BuildContext context, Failure failure) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(failure.message(context.l10n))));
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
