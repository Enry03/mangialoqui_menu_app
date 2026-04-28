import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'router.dart';

class MangialoquiMenuApp extends StatelessWidget {
  const MangialoquiMenuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Mangialoqui Menu',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: appRouter,
    );
  }
}
