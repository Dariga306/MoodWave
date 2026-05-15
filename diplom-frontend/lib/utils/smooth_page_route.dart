import 'package:flutter/material.dart';

PageRouteBuilder<T> smoothPageRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 450),
    reverseTransitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, reverseAnimation, child) {
      final tween = Tween(begin: const Offset(0, 0.08), end: Offset.zero);
      final curveTween = CurveTween(curve: Curves.easeOutCubic);
      final offsetAnimation = animation.drive(curveTween).drive(tween);
      
      return FadeTransition(
        opacity: animation.drive(
          CurveTween(curve: Curves.easeOut),
        ),
        child: SlideTransition(
          position: offsetAnimation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        ),
      );
    },
  );
}
