import 'package:flutter/material.dart';
import 'package:sakan/core/theme/app_theme.dart';
import 'package:sakan/routes/app_router.dart';

class SakanApp extends StatelessWidget {
  const SakanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Sakan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
