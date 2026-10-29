import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:max_tools/core/config/cambric_config.dart';
import 'package:max_tools/core/security/security_service.dart';

import 'package:max_tools/core/subscription/subscription_service.dart';
import 'package:max_tools/core/subscription/subscription_tier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CambricConfig config;
  late SubscriptionService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    config = const CambricConfig(
      productId: 'max-tools-product',
      productName: 'Max Tools',
      version: '0.2.0',
      templateVersion: '1.0.0',
    );
    service = SubscriptionService(
      config: config,
      security: const SecurityService(),
    );
    await service.load();
  });

  test('starts on free tier', () {
    expect(service.tier, SubscriptionTier.free);
    expect(service.state.isPaid, isFalse);
  });

  test('can() grants free for free', () {
    expect(service.can(SubscriptionTier.free), isTrue);
    expect(service.can(SubscriptionTier.pro), isFalse);
  });

  test('clear reverts to free', () async {
    await service.clear();
    expect(service.tier, SubscriptionTier.free);
  });
}