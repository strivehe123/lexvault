import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'pages/home_page.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  await state.init();
  runApp(
    ChangeNotifierProvider.value(
      value: state,
      child: const VacMasterApp(),
    ),
  );
}

class VacMasterApp extends StatelessWidget {
  const VacMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LexVault',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: const HomePage(),
    );
  }
}
