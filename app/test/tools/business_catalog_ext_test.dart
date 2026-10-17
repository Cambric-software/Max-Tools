import 'package:flutter_test/flutter_test.dart';
import 'package:max_tools/tools/catalog/tool_catalog.dart';
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

  group('decision and contract', () {
    test('can take job compares against your floor', () async {
      final good = await run(
        'freelance.canTakeJob',
        <String, dynamic>{
          'quotedPrice': 3000,
          'estimatedHours': 20,
          'minimumRate': 100,
        },
      );
      expect(good['meetsMinimum'], isTrue);
      expect(good['effectiveRate'], 150.0);

      final bad = await run(
        'freelance.canTakeJob',
        <String, dynamic>{
          'quotedPrice': 1000,
          'estimatedHours': 20,
          'minimumRate': 100,
        },
      );
      expect(bad['meetsMinimum'], isFalse);
      expect(bad['verdict'], contains('Renegotiate'));
    });

    test('payment terms compute due date and ageing', () async {
      final out = await run(
        'freelance.paymentTerms',
        <String, dynamic>{
          'invoiceDate': '2026-01-01',
          'netDays': 30,
          'today': '2026-02-15',
        },
      );
      expect(out['dueDate'], '2026-01-31');
      expect(out['daysUntilDue'], 0);
      expect(out['daysLate'], 15);
      expect(out['overdue'], isTrue);
    });

    test('payment terms handle a future due date', () async {
      final out = await run(
        'freelance.paymentTerms',
        <String, dynamic>{
          'invoiceDate': '2026-01-01',
          'netDays': 30,
          'today': '2026-01-10',
        },
      );
      expect(out['daysUntilDue'], 21);
      expect(out['overdue'], isFalse);
    });

    test('a malformed date is rejected', () async {
      expect(
        await error(
          'freelance.paymentTerms',
          <String, dynamic>{'invoiceDate': '31/01/2026', 'netDays': 30},
        ),
        isNotNull,
      );
    });

    test('rate card builds three tiers', () async {
      final out = await run(
        'freelance.rateCard',
        <String, dynamic>{'baseRate': 50, 'midMultiplier': 1.5,
            'seniorMultiplier': 2.5},
      );
      final roles = out['roles'] as List<Map<String, dynamic>>;
      expect(roles.map((r) => r['rate']), <double>[50.0, 75.0, 125.0]);
    });

    test('rate card rejects inverted multipliers', () async {
      expect(
        await error(
          'freelance.rateCard',
          <String, dynamic>{'baseRate': 50, 'midMultiplier': 3,
              'seniorMultiplier': 2},
        ),
        isNotNull,
      );
    });
  });

  group('capacity', () {
    test('capacity reports free and target hours', () async {
      final out = await run(
        'freelance.capacity',
        <String, dynamic>{
          'workingDays': 20,
          'hoursPerDay': 8,
          'bookedHours': 100,
          'targetUtilisationPercent': 75,
        },
      );
      expect(out['availableHours'], 160.0);
      expect(out['freeHours'], 60.0);
      expect(out['targetBookableHours'], 120.0);
      expect(out['atTarget'], isTrue);
    });

    test('capacity flags overbooking', () async {
      final out = await run(
        'freelance.capacity',
        <String, dynamic>{
          'workingDays': 10,
          'hoursPerDay': 8,
          'bookedHours': 70,
          'targetUtilisationPercent': 75,
        },
      );
      expect(out['atTarget'], isFalse);
      expect(out['overbookedBy'], 10.0);
    });

    test('utilisation gap shows the cost of admin', () async {
      final out = await run(
        'freelance.utilisationGap',
        <String, dynamic>{'billableHours': 30, 'totalHours': 40,
            'hourlyRate': 60},
      );
      expect(out['utilisationPercent'], 75.0);
      expect(out['adminHours'], 10.0);
      expect(out['adminValue'], 600.0);
    });
  });

  group('forecasting', () {
    test('revenue target divides by the margin you need', () async {
      final out = await run(
        'business.revenueTarget',
        <String, dynamic>{
          'annualTarget': 50000,
          'billableDays': 200,
          'targetMarginPercent': 50,
        },
      );
      expect(out['requiredRevenue'], 100000.0);
      expect(out['perBillableDay'], 500.0);
      expect(out['perMonth'], 8333.33);
    });

    test('revenue target rejects impossible margins', () async {
      expect(
        await error(
          'business.revenueTarget',
          <String, dynamic>{'annualTarget': 1000, 'billableDays': 100,
              'targetMarginPercent': 0},
        ),
        isNotNull,
      );
    });

    test('monthly run rate and annualised', () async {
      final out = await run(
        'business.recurringRevenue',
        <String, dynamic>{'totalRevenue': 60000, 'months': 6},
      );
      expect(out['monthlyRunRate'], 10000.0);
      expect(out['annualised'], 120000.0);
    });

    test('payback period', () async {
      final out = await run(
        'business.paybackPeriod',
        <String, dynamic>{'investment': 12000, 'monthlyProfit': 1000},
      );
      expect(out['monthsToPayback'], 12.0);
      expect(out['yearsToPayback'], 1.0);
    });

    test('payback needs a positive profit', () async {
      expect(
        await error(
          'business.paybackPeriod',
          <String, dynamic>{'investment': 1000, 'monthlyProfit': 0},
        ),
        isNotNull,
      );
    });

    test('roi', () async {
      final out = await run(
        'business.roi',
        <String, dynamic>{'gain': 500, 'investment': 1000},
      );
      expect(out['roiPercent'], 50.0);
      expect(out['multiple'], 1.5);
    });

    test('projected profit scenarios', () async {
      final out = await run(
        'business.projectedProfit',
        <String, dynamic>{
          'bestHours': 10,
          'expectedHours': 20,
          'worstHours': 40,
          'hourlyRate': 100,
          'fixedCosts': 500,
        },
      );
      expect(out['best'], 500.0);
      expect(out['expected'], 1500.0);
      expect(out['worst'], 3500.0);
      expect(out['verdict'], contains('Profitable'));
    });

    test('scenarios warn when the worst case loses money', () async {
      final out = await run(
        'business.projectedProfit',
        <String, dynamic>{
          'bestHours': 10,
          'expectedHours': 20,
          'worstHours': 60,
          'hourlyRate': 20,
          'fixedCosts': 500,
        },
      );
      expect(out['worst'], 700.0);
      final losing = await run(
        'business.projectedProfit',
        <String, dynamic>{
          'bestHours': 10,
          'expectedHours': 20,
          'worstHours': 60,
          'hourlyRate': 10,
          'fixedCosts': 1000,
        },
      );
      expect(losing['worst'], -400.0);
      expect(losing['verdict'], contains('lose money'));
    });

    test('scenarios reject inconsistent hours', () async {
      expect(
        await error(
          'business.projectedProfit',
          <String, dynamic>{
            'bestHours': 40,
            'expectedHours': 20,
            'worstHours': 10,
            'hourlyRate': 100,
          },
        ),
        isNotNull,
      );
    });
  });

  group('pricing and costs', () {
    test('discount impact shows what it costs', () async {
      final out = await run(
        'business.discountImpact',
        <String, dynamic>{'listPrice': 1000, 'discountPercent': 20, 'costs': 200},
      );
      expect(out['discountedPrice'], 800.0);
      expect(out['profitBefore'], 800.0);
      expect(out['profitAfter'], 600.0);
      expect(out['profitGivenAway'], 200.0);
    });

    test('expense ratio', () async {
      final out = await run(
        'business.expenseRatio',
        <String, dynamic>{'revenue': 10000, 'expenses': 2500},
      );
      expect(out['expenseRatioPercent'], 25.0);
      expect(out['retained'], 7500.0);
    });

    test('cost escalation compounds', () async {
      final out = await run(
        'business.costEscalation',
        <String, dynamic>{'cost': 1000, 'inflationPercent': 10, 'years': 2},
      );
      expect(out['futureCost'], 1210.0);
      expect(out['increasePercent'], 21.0);
    });

    test('withholding', () async {
      final out = await run(
        'business.withholding',
        <String, dynamic>{'grossAmount': 1000, 'withholdingPercent': 20},
      );
      expect(out['withheld'], 200.0);
      expect(out['net'], 800.0);
    });

    test('minimum viable price includes overhead', () async {
      final out = await run(
        'business.minimumProjectPrice',
        <String, dynamic>{'estimatedHours': 10, 'minimumRate': 100,
            'overheadPercent': 20},
      );
      expect(out['rawHoursValue'], 1000.0);
      expect(out['minimumPrice'], 1200.0);
      expect(out['overheadCovered'], 200.0);
    });

    test('quote split keeps the total', () async {
      final out = await run(
        'business.quoteSplit',
        <String, dynamic>{'total': 10000, 'itemCount': 2, 'designPercent': 30},
      );
      expect(out['design'], 3000.0);
      expect(out['build'], 7000.0);
      expect(out['evenShare'], 5000.0);
    });
  });

  group('catalog size', () {
    test('the catalog now exceeds 100 tools', () {
      expect(registry.length, greaterThanOrEqualTo(100));
    });

    test('both halves clear fifty tools', () {
      var developerSide = 0;
      var creativeSide = 0;
      registry.categoryCounts().forEach((category, count) {
        final creative = <String>{'animator', 'freelancer', 'business'}
            .contains(category.name);
        if (creative) {
          creativeSide += count;
        } else {
          developerSide += count;
        }
      });
      expect(developerSide, greaterThanOrEqualTo(50));
      expect(creativeSide, greaterThanOrEqualTo(50));
    });
  });
}
