import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_link.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// Root widget: theme + declarative routing.
class FamilySuperApp extends ConsumerWidget {
  const FamilySuperApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    AppLink.attach(router);

    return MaterialApp.router(
      title: 'FAM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
