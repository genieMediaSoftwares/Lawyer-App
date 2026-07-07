// import 'package:flutter/material.dart';
// import 'routes/app_router.dart';
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp.router(
//       debugShowCheckedModeBanner: false,
//       title: 'CaseMitra',
//       routerConfig: AppRouter.router,
//     );
//   }
// }
import 'core/network/test_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'routes/app_router.dart';
import 'core/theme/app_theme.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(
      BuildContext context,
      WidgetRef ref,
      ) {
    final router = ref.watch(routerProvider);
    TestApi.test();
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'LawConnect',

      theme: AppTheme.luxuryTheme,
      darkTheme: AppTheme.luxuryTheme,

      routerConfig: router,
    );
  }
}