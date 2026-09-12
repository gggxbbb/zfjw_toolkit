import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// Shared breakpoints for navigation and content density.
final class AppBreakpoints {
  AppBreakpoints._();

  static const double navigationRail = 720;
  static const double extendedNavigationRail = 1100;
  static const double maxContentWidth = 1280;
}

/// Exposes the shell's active navigation mode to page-level spacing helpers.
class AppLayoutScope extends InheritedWidget {
  const AppLayoutScope({
    super.key,
    required this.usesNavigationRail,
    required super.child,
  });

  final bool usesNavigationRail;

  static bool usesNavigationRailOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppLayoutScope>()
          ?.usesNavigationRail ??
      false;

  @override
  bool updateShouldNotify(AppLayoutScope oldWidget) =>
      usesNavigationRail != oldWidget.usesNavigationRail;
}

/// Centers desktop content while allowing compact layouts to use all space.
class AppContentFrame extends StatelessWidget {
  const AppContentFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: math.min(constraints.maxWidth, AppBreakpoints.maxContentWidth),
        height: constraints.maxHeight,
        child: child,
      ),
    ),
  );
}

/// Lays independent cards out in one or two columns based on available width.
class AppResponsiveColumns extends StatelessWidget {
  const AppResponsiveColumns({
    super.key,
    required this.children,
    this.spacing = AppTokens.space4,
    this.minColumnWidth = 400,
  });

  final List<Widget> children;
  final double spacing;
  final double minColumnWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= minColumnWidth * 2 + spacing
          ? 2
          : 1;
      final itemWidth = columns == 1
          ? constraints.maxWidth
          : (constraints.maxWidth - spacing) / 2;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final child in children)
            SizedBox(width: itemWidth, child: child),
        ],
      );
    },
  );
}
