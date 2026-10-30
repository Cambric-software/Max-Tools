import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/ecosystem/cambric_ecosystem_service.dart';
import 'core/ecosystem/product_registry_service.dart';
import 'core/lifecycle/app_lifecycle_service.dart';
import 'core/cache/tool_result_cache.dart';
import 'core/config/cambric_config.dart';
import 'core/security/security_service.dart';
import 'core/services/hotkey_service.dart';
import 'core/services/service_registry.dart';
import 'core/subscription/subscription_service.dart';
import 'core/settings/app_settings.dart';
import 'core/storage/cambric_paths.dart';
import 'core/updates/install_layout.dart';
import 'features/screens/home/home_screen.dart';
import 'package:cambric_design/cambric_design.dart';
import 'features/tools/catalog/tool_catalog.dart';
import 'features/tools/tool_registry.dart';
import 'features/tools/tools_scope.dart';
import 'features/tools/variable_store.dart';
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

  // Offline-first tool result cache.
  final cacheFile = File(
    '${(await CambricPaths.appData()).path}${Platform.pathSeparator}tool_results.json',
  );
  final toolCache = ToolResultCache(file: cacheFile);
  toolCache.load();
  final toolRegistry = buildDefaultRegistry(cache: toolCache);

  // Global hotkeys for favourite tools.
  final hotkeys = HotkeyService();
  await hotkeys.load();
  final navigatorKey = GlobalKey<NavigatorState>();
  HardwareKeyboard.instance.addHandler((event) {
    if (event is! KeyDownEvent) return false;
    final spec = HotkeyService.specFromEvent(event);
    final toolId = hotkeys.toolFor(spec);
    if (toolId == null) return false;
    final tool = toolRegistry.find(toolId);
    final screen = tool?.screen;
    final nav = navigatorKey.currentState;
    if (screen != null && nav != null) {
      nav.push(MaterialPageRoute<void>(builder: screen));
      return true;
    }
    return false;
  });

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

  // Load subscription state (offline license validation).
  final subscription = SubscriptionService(
    config: config,
    security: const SecurityService(),
  );
  await subscription.load();

  final services = ServiceRegistry();
  services.register<SubscriptionService>(subscription);

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
      registry: toolRegistry,
      navigatorKey: navigatorKey,
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
  final ToolRegistry registry;
  final GlobalKey<NavigatorState> navigatorKey;

  const MaxToolsApp({
    super.key,
    required this.config,
    required this.existingProducts,
    required this.variables,
    required this.registry,
    required this.navigatorKey,
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
      registry: registry,
      variables: variables,
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: AppSettings.instance.themeMode,
        builder: (BuildContext context, ThemeMode mode, Widget? _) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            title: config.productName,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
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
