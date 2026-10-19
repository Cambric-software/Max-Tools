import 'dart:io';

import 'package:flutter/material.dart';

import 'core/ecosystem/cambric_ecosystem_service.dart';
import 'core/ecosystem/product_registry_service.dart';
import 'core/lifecycle/app_lifecycle_service.dart';
import 'core/config/cambric_config.dart';
import 'core/settings/app_settings.dart';
import 'core/storage/cambric_paths.dart';
import 'core/updates/install_layout.dart';
import 'screens/home/home_screen.dart';
import 'theme/app_theme.dart';
import 'tools/catalog/tool_catalog.dart';
import 'tools/tools_scope.dart';
import 'tools/variable_store.dart';
import 'core/cambric_app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Self-healing handoff: if a newer version was activated while this copy
  // was not running (for example the user launched an old desktop shortcut),
  // start that version and exit instead of running a stale build. Running the
  // version already on disk is better than exiting with nothing, so failure
  // here falls through rather than blocking startup.
  final handoffResult = await handoff();
  if (handoffResult == HandoffAction.relaunchActiveVersion) {
    exit(0);
  }

  // Load central configuration.
  final config = await CambricConfig.load(
    'lib/core/config/cambric_config.json',
  );

  // Variables persist between sessions so a palette result survives a restart.
  VariableStore? variables;
  try {
    final supportDirectory = await CambricPaths.appData();
    final store = VariableStore(
      file: File('$supportDirectory${Platform.pathSeparator}variables.json'),
    )..load();
    variables = store;
  } catch (_) {
    // A missing support directory is not worth failing startup over; the
    // palette simply will not remember anything this session.
    variables = VariableStore();
  }

  // Initialize application lifecycle tracking.
  final lifecycle = AppLifecycleService();
  await lifecycle.initialize();

  // Read the person's stored preferences before the first frame, so the app
  // opens in the theme they chose instead of flashing the default first.
  await AppSettings.instance.load();

  // Initialize the local Cambric ecosystem service.
  final ecosystem = CambricEcosystemService();
  await ecosystem.ensureIdentity();

  // Register this product in the shared local registry.
  final registry = ProductRegistryService();
  await registry.register({
    'productId': config.productId,
    'name': config.productName,
    'version': config.version,
    'platform': 'flutter',
    'protocolVersion': config.ecosystemProtocolVersion,
    'capabilities': [
      'local-storage',
      'cache',
      'release-discovery',
      'updates',
      'ecosystem',
    ],
    'lastSeen': DateTime.now().toIso8601String(),
  });

  final products = await registry.products();

  runApp(
    MaxToolsApp(
      config: config,
      existingProducts: products,
      variables: variables,
    ),
  );
}

/// The application root.
///
/// Named for the product rather than for the template it was generated from,
/// so the widget tree, the window title and the about screen all describe the
/// same thing.
class MaxToolsApp extends StatelessWidget {
  final CambricConfig config;
  final List<Map<String, dynamic>> existingProducts;
  final VariableStore variables;

  const MaxToolsApp({
    super.key,
    required this.config,
    required this.existingProducts,
    required this.variables,
  });

  @override
  Widget build(BuildContext context) {
    // One registry for the whole app: every tool screen, the command palette
    // and automation all resolve tools through this instance.
    //
    // The scope sits ABOVE MaterialApp, not inside `home:`. Anything pushed
    // onto the Navigator is a sibling of `home`, so a scope placed there would
    // be invisible to every pushed route, and tapping Tools or the command
    // palette would crash the app.
    return ToolsScope(
      registry: buildDefaultRegistry(),
      variables: variables,
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: AppSettings.instance.themeMode,
        builder: (BuildContext context, ThemeMode mode, Widget? _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: config.productName,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: mode,
            // The product surface is the home screen. There is no wizard gate:
            // the app is usable immediately, and everything the setup wizard
            // collected is shown on the Cambric screen.
            home: CambricAppShell(
              productName: config.productName,
              version: config.version,
              child: HomeScreen(
                config: config,
                existingProducts: existingProducts,
              ),
            ),
          );
        },
      ),
    );
  }
}
