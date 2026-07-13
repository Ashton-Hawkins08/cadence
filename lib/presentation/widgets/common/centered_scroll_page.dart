import 'package:flutter/material.dart';

/// A page of content that centers vertically when it fits the viewport and
/// scrolls when it doesn't — the standard fix for onboarding/form-style
/// screens that overflow on short phones or when the keyboard opens.
///
/// Deliberately has no `Expanded`/`Spacer` support: those need a bounded
/// max-height context, which conflicts with the unbounded height a
/// scrollable gives its child. Callers needing "push this to the bottom"
/// layouts should use a fixed gap instead.
class CenteredScrollPage extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const CenteredScrollPage({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(32),
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight:
                (constraints.maxHeight - padding.vertical).clamp(0, double.infinity),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [child],
          ),
        ),
      ),
    );
  }
}
