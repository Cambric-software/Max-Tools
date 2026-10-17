import 'package:flutter_test/flutter_test.dart';
import 'package:max_tools/tools/catalog/tool_catalog.dart';
import 'package:max_tools/tools/tool_descriptor.dart';
import 'package:max_tools/tools/tool_registry.dart';

void main() {
  late ToolRegistry registry;

  setUp(() {
    registry = buildDefaultRegistry();
  });

  Future<Map<String, dynamic>> run(String id, Map<String, dynamic> args) async {
    final result = await registry.run(id, args);
    expect(result.success, isTrue, reason: '${result.error}');
    return result.value as Map<String, dynamic>;
  }

  Future<String?> error(String id, Map<String, dynamic> args) async =>
      (await registry.run(id, args)).error;

  group('freelancer: pricing', () {
    test('hourly to project price', () async {
      final out = await run(
        'freelance.hourlyToProject',
        <String, dynamic>{'hours': 10, 'hourlyRate': 80},
      );
      expect(out['base'], 800.0);
      expect(out['total'], 800.0);
    });

    test('markup is added after the base', () async {
      final out = await run(
        'freelance.hourlyToProject',
        <String, dynamic>{'hours': 10, 'hourlyRate': 80, 'markupPercent': 25},
      );
      expect(out['total'], 1000.0);
      expect(out['markupAmount'], 200.0);
    });

    test('negative hours are rejected', () async {
      expect(
        await error(
          'freelance.hourlyToProject',
          <String, dynamic>{'hours': -5, 'hourlyRate': 80},
        ),
        isNotNull,
      );
    });

    test('day rate to hourly', () async {
      final out = await run(
        'freelance.dayRateToHourly',
        <String, dynamic>{'dayRate': 800, 'hoursPerDay': 8},
      );
      expect(out['hourlyRate'], 100.0);
    });

    test('day rate conversion rejects a zero-length day', () async {
      expect(
        await error(
          'freelance.dayRateToHourly',
          <String, dynamic>{'dayRate': 800, 'hoursPerDay': 0},
        ),
        isNotNull,
      );
    });

    test('quote with tax applies discount before tax', () async {
      final out = await run(
        'freelance.quoteWithTax',
        <String, dynamic>{
          'netAmount': 1000,
          'taxPercent': 20,
          'discountPercent': 10,
        },
      );
      expect(out['afterDiscount'], 900.0);
      expect(out['taxAmount'], 180.0);
      expect(out['total'], 1080.0);
    });

    test('invoice total nets off the deposit', () async {
      final out = await run(
        'freelance.invoiceTotal',
        <String, dynamic>{
          'subtotal': 1000,
          'taxPercent': 20,
          'discountAmount': 100,
          'depositPaid': 300,
        },
      );
      expect(out['total'], 1080.0);
      expect(out['balanceDue'], 780.0);
    });
  });

  group('freelancer: milestones and rates', () {
    test('milestone plan keeps the total intact', () async {
      final out = await run(
        'freelance.milestonePlan',
        <String, dynamic>{'total': 10000, 'depositPercent': 30, 'milestoneCount': 3},
      );
      expect(out['deposit'], 3000.0);
      expect(out['finalTotal'], 10000.0);
      expect(out['schedule'], hasLength(4));
    });

    test('milestone count must be positive', () async {
      expect(
        await error(
          'freelance.milestonePlan',
          <String, dynamic>{'total': 100, 'milestoneCount': 0},
        ),
        isNotNull,
      );
    });

    test('deposit percentage is bounded', () async {
      expect(
        await error(
          'freelance.milestonePlan',
          <String, dynamic>{'total': 100, 'depositPercent': 150},
        ),
        isNotNull,
      );
    });

    test('effective rate counts unpaid time against you', () async {
      final out = await run(
        'freelance.effectiveRate',
        <String, dynamic>{
          'paidAmount': 1000,
          'billableHours': 10,
          'unpaidHours': 10,
        },
      );
      expect(out['effectiveRate'], 50.0);
      expect(out['billedRate'], 100.0);
    });

    test('effective rate rejects zero hours', () async {
      expect(
        await error(
          'freelance.effectiveRate',
          <String, dynamic>{'paidAmount': 100, 'billableHours': 0},
        ),
        isNotNull,
      );
    });

    test('billable split reports utilisation', () async {
      final out = await run(
        'freelance.billableSplit',
        <String, dynamic>{
          'billableHours': 30,
          'nonBillableHours': 10,
          'hourlyRate': 50,
        },
      );
      expect(out['utilisationPercent'], 75.0);
      expect(out['earned'], 1500.0);
      expect(out['unbilledValue'], 500.0);
    });

    test('retainer consumption and overage', () async {
      final out = await run(
        'freelance.retainerConsumed',
        <String, dynamic>{
          'retainerAmount': 2000,
          'hoursUsed': 10,
          'hourlyRate': 100,
        },
      );
      expect(out['includedHours'], 20.0);
      expect(out['hoursRemaining'], 10.0);
      expect(out['overageValue'], 0.0);

      final over = await run(
        'freelance.retainerConsumed',
        <String, dynamic>{
          'retainerAmount': 1000,
          'hoursUsed': 15,
          'hourlyRate': 100,
        },
      );
      expect(over['overageValue'], 500.0);
    });

    test('late payment interest', () async {
      final out = await run(
        'freelance.latePayment',
        <String, dynamic>{
          'invoiceAmount': 3650,
          'daysLate': 30,
          'annualRatePercent': 8,
        },
      );
      expect(out['interest'], 24.0);
      expect(out['amountDue'], 3674.0);
    });

    test('deposit covers start-up cost or says so', () async {
      final good = await run(
        'freelance.depositToStart',
        <String, dynamic>{
          'projectTotal': 10000,
          'firstPhaseCost': 2000,
          'depositPercent': 40,
        },
      );
      expect(good['coversStartUpCost'], isTrue);
      expect(good['shortfall'], 0.0);

      final bad = await run(
        'freelance.depositToStart',
        <String, dynamic>{
          'projectTotal': 10000,
          'firstPhaseCost': 5000,
          'depositPercent': 10,
        },
      );
      expect(bad['coversStartUpCost'], isFalse);
      expect(bad['shortfall'], 4000.0);
      expect(bad['breakEvenDepositPercent'], 50.0);
    });
  });

  group('business: profit and pricing', () {
    test('project profit includes labour', () async {
      final out = await run(
        'business.projectProfit',
        <String, dynamic>{
          'revenue': 5000,
          'costs': 1000,
          'hours': 40,
          'hourlyCost': 25,
        },
      );
      expect(out['labourCost'], 1000.0);
      expect(out['totalCosts'], 2000.0);
      expect(out['profit'], 3000.0);
      expect(out['marginPercent'], 60.0);
      expect(out['profitable'], isTrue);
    });

    test('a loss is reported honestly', () async {
      final out = await run(
        'business.projectProfit',
        <String, dynamic>{'revenue': 1000, 'costs': 2000},
      );
      expect(out['profit'], -1000.0);
      expect(out['profitable'], isFalse);
    });

    test('markup to margin: 50% markup is a 33.33% margin', () async {
      final out = await run(
        'business.markupToMargin',
        <String, dynamic>{'markupPercent': 50},
      );
      expect(out['marginPercent'], 33.33);
    });

    test('price from margin inverts correctly', () async {
      final out = await run(
        'business.priceFromMargin',
        <String, dynamic>{'cost': 100, 'targetMarginPercent': 50},
      );
      expect(out['price'], 200.0);
      expect(out['profit'], 100.0);
    });

    test('price from margin rejects impossible margins', () async {
      expect(
        await error(
          'business.priceFromMargin',
          <String, dynamic>{'cost': 100, 'targetMarginPercent': 100},
        ),
        isNotNull,
      );
    });

    test('tax set-aside', () async {
      final out = await run(
        'business.taxSetAside',
        <String, dynamic>{'profit': 10000, 'taxPercent': 25, 'alreadyReserved': 1000},
      );
      expect(out['taxRequired'], 2500.0);
      expect(out['takeHome'], 7500.0);
      expect(out['stillToReserve'], 1500.0);
    });

    test('tax set-aside never reports a negative amount to reserve', () async {
      final out = await run(
        'business.taxSetAside',
        <String, dynamic>{'profit': 1000, 'taxPercent': 20, 'alreadyReserved': 500},
      );
      expect(out['stillToReserve'], 0.0);
    });

    test('break-even rounds up to a whole job', () async {
      final out = await run(
        'business.breakEven',
        <String, dynamic>{
          'fixedCosts': 1000,
          'pricePerUnit': 300,
          'variableCostPerUnit': 100,
        },
      );
      expect(out['breakEvenUnits'], 5.0);
      expect(out['contributionPerUnit'], 200.0);

      final rounded = await run(
        'business.breakEven',
        <String, dynamic>{
          'fixedCosts': 1000,
          'pricePerUnit': 250,
          'variableCostPerUnit': 100,
        },
      );
      expect(rounded['unitsToRoundUpTo'], 7);
    });

    test('break-even refuses a negative contribution', () async {
      final message = await error(
        'business.breakEven',
        <String, dynamic>{
          'fixedCosts': 1000,
          'pricePerUnit': 50,
          'variableCostPerUnit': 100,
        },
      );
      expect(message, contains('break even'));
    });
  });

  group('business: forecasting', () {
    test('budget burn flags overspend', () async {
      final onTrack = await run(
        'business.budgetBurn',
        <String, dynamic>{
          'budget': 10000,
          'spent': 5000,
          'daysElapsed': 50,
          'totalDays': 100,
        },
      );
      expect(onTrack['onTrack'], isTrue);
      expect(onTrack['percentUsed'], 50.0);

      final over = await run(
        'business.budgetBurn',
        <String, dynamic>{
          'budget': 10000,
          'spent': 9000,
          'daysElapsed': 50,
          'totalDays': 100,
        },
      );
      expect(over['onTrack'], isFalse);
      expect(over['overBy'], 8000.0);
    });

    test('cash flow finds the lowest balance', () async {
      final out = await run(
        'business.cashFlow',
        <String, dynamic>{
          'startingBalance': 1000,
          'monthlyIncome': 500,
          'monthlyCosts': 800,
          'periods': 3,
        },
      );
      expect(out['netPerPeriod'], -300.0);
      expect(out['finalBalance'], 100.0);
      expect(out['lowestBalance'], 100.0);
      expect(out['goesNegative'], isFalse);
    });

    test('cash flow warns before the balance goes negative', () async {
      final out = await run(
        'business.cashFlow',
        <String, dynamic>{
          'startingBalance': 500,
          'monthlyIncome': 100,
          'monthlyCosts': 400,
          'periods': 3,
        },
      );
      expect(out['goesNegative'], isTrue);
      expect(out['lowestBalance'], -400.0);
    });

    test('currency conversion', () async {
      final out = await run(
        'business.currency',
        <String, dynamic>{
          'amount': 100,
          'rate': 0.92,
          'from': 'USD',
          'to': 'EUR',
        },
      );
      expect(out['converted'], 92.0);
      expect(out['from'], 'USD');
    });

    test('currency conversion rejects a zero rate', () async {
      expect(
        await error(
          'business.currency',
          <String, dynamic>{'amount': 100, 'rate': 0},
        ),
        isNotNull,
      );
    });

    test('cost per client', () async {
      final out = await run(
        'business.costPerClient',
        <String, dynamic>{
          'totalCosts': 10000,
          'clientCount': 5,
          'averageRevenue': 4000,
        },
      );
      expect(out['costPerClient'], 2000.0);
      expect(out['profitPerClient'], 2000.0);
      expect(out['marginPercent'], 50.0);
    });

    test('cost per client needs at least one client', () async {
      expect(
        await error(
          'business.costPerClient',
          <String, dynamic>{'totalCosts': 100, 'clientCount': 0},
        ),
        isNotNull,
      );
    });

    test('scope change pricing uses a flat fee when given', () async {
      final hourly = await run(
        'business.scopeChangePrice',
        <String, dynamic>{'extraHours': 5, 'hourlyRate': 100},
      );
      expect(hourly['net'], 500.0);
      expect(hourly['basis'], 'hours x rate');

      final fixed = await run(
        'business.scopeChangePrice',
        <String, dynamic>{'extraHours': 5, 'hourlyRate': 100, 'fixedFee': 300},
      );
      expect(fixed['net'], 300.0);
      expect(fixed['basis'], 'flat fee');
    });

    test('pricing tiers keep their order', () async {
      final out = await run(
        'business.pricingTiers',
        <String, dynamic>{'basePrice': 1000, 'entryPercent': 60, 'premiumPercent': 180},
      );
      final tiers = out['tiers'] as List<Map<String, dynamic>>;
      expect(tiers.map((t) => t['price']), <double>[600.0, 1000.0, 1800.0]);
    });

    test('pricing tiers reject an inverted range', () async {
      expect(
        await error(
          'business.pricingTiers',
          <String, dynamic>{'basePrice': 100, 'entryPercent': 200, 'premiumPercent': 100},
        ),
        isNotNull,
      );
    });

    test('margin after tax', () async {
      final out = await run(
        'business.marginAfterTax',
        <String, dynamic>{'revenue': 10000, 'costs': 6000, 'taxPercent': 20},
      );
      expect(out['grossProfit'], 4000.0);
      expect(out['taxAmount'], 800.0);
      expect(out['netProfit'], 3200.0);
      expect(out['netMarginPercent'], 32.0);
    });

    test('a loss pays no tax', () async {
      final out = await run(
        'business.marginAfterTax',
        <String, dynamic>{'revenue': 1000, 'costs': 2000, 'taxPercent': 20},
      );
      expect(out['taxAmount'], 0.0);
      expect(out['netProfit'], -1000.0);
    });
  });

  group('catalog completeness', () {
    test('business and freelance categories are now populated', () {
      expect(registry.byCategory(ToolCategoryNames.business), isNotEmpty);
      expect(registry.byCategory(ToolCategoryNames.freelancer), isNotEmpty);
      expect(registry.byCategory(ToolCategoryNames.animator), isNotEmpty);
    });

    test('the catalog now exceeds 90 tools', () {
      expect(registry.length, greaterThanOrEqualTo(90));
    });
  });
}

/// Local aliases so the assertions above read clearly.
class ToolCategoryNames {
  static const business = ToolCategory.business;
  static const freelancer = ToolCategory.freelancer;
  static const animator = ToolCategory.animator;
}
