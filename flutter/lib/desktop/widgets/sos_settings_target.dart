import 'package:flutter/material.dart';

class SosSettingsTarget extends StatefulWidget {
  const SosSettingsTarget({super.key, required this.label, this.onOpen});

  final String label;
  final VoidCallback? onOpen;

  @override
  State<SosSettingsTarget> createState() => _SosSettingsTargetState();
}

class _SosSettingsTargetState extends State<SosSettingsTarget> {
  bool _showFocus = false;

  @override
  Widget build(BuildContext context) {
    final onOpen = widget.onOpen;
    const area = SizedBox(width: 30, height: 25);
    if (onOpen == null) return area;

    return Semantics(
      label: widget.label,
      button: true,
      onTap: onOpen,
      child: FocusableActionDetector(
        mouseCursor: MouseCursor.defer,
        onShowFocusHighlight: (show) => setState(() => _showFocus = show),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            onOpen();
            return null;
          }),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: onOpen,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: _showFocus
                  ? Border.all(color: Theme.of(context).colorScheme.primary)
                  : null,
              borderRadius: BorderRadius.circular(4),
            ),
            child: area,
          ),
        ),
      ),
    );
  }
}
