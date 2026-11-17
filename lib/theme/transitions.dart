import 'package:flutter/material.dart';
import '../utils/helpers.dart';
import 'tokens.dart';

class AppSpring {
  AppSpring._();

  static const SpringDescription gentle = SpringDescription(
    mass: 1,
    stiffness: 200,
    damping: 20,
  );

  static const SpringDescription standard = SpringDescription(
    mass: 1,
    stiffness: 300,
    damping: 20,
  );

  static const SpringDescription bouncy = SpringDescription(
    mass: 0.8,
    stiffness: 400,
    damping: 12,
  );

  static const SpringDescription snappy = SpringDescription(
    mass: 1,
    stiffness: 400,
    damping: 25,
  );
}

class IOSPageTransition extends PageTransitionsBuilder {
  const IOSPageTransition();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppHelpers.reduceMotion) return child;

    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.08, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

class ModalPageTransition extends PageTransitionsBuilder {
  const ModalPageTransition();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppHelpers.reduceMotion) return child;

    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(curved),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1.0).animate(curved),
          child: child,
        ),
      ),
    );
  }
}

Future<T?> openModalScreen<T>(BuildContext context, Widget screen) {
  return Navigator.of(context).push<T>(
    PageRouteBuilder(
      pageBuilder: (_, _, _) => screen,
      transitionDuration: AppDuration.page,
      reverseTransitionDuration: AppDuration.normal,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (AppHelpers.reduceMotion) return child;
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.12),
              end: Offset.zero,
            ).animate(curved),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
              child: child,
            ),
          ),
        );
      },
    ),
  );
}
