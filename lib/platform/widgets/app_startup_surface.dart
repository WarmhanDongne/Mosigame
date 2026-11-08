import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';

/// Keeps verification on the app background without showing login or lobby UI.
class AppStartupSurface extends StatelessWidget {
  const AppStartupSurface({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: MosiColors.violet,
    body: SafeArea(
      child: Center(
        child: child ?? const CircularProgressIndicator(color: Colors.white),
      ),
    ),
  );
}
