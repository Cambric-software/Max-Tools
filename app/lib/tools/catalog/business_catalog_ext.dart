/// Second business and freelancer batch: forecasting, contracts, capacity and
/// the questions owners actually ask ("can I take this job?", "when do I get
/// paid?", "is this worth doing?").
library;

import '../tool_descriptor.dart';
import '../tool_registry.dart';
import '../variable_store.dart';

ToolParameter _num(
  String name,
  String description, {
  bool required = false,
  Object? fallback,
}) =>
    ToolParameter(
      name: name,
      description: description,
      required: required,
      defaultValue: fallback,
      type: VariableType.number,
    );

ToolParameter _text(
  String name,
  String description, {
  bool required = false,
  Object? defaultValue,
}) =>
    ToolParameter(
      name: name,
      description: description,
      required: required,
      defaultValue: defaultValue,
    );

double _money(num value) => (value * 100).round() / 100;

double _round(num value, int places) {
  var factor = 1.0;
  for (var i = 0; i < places; i++) {
    factor *= 10;
  }
  return (value * factor).round() / factor;
}

num _number(Object? value, String name) {
  if (value is num) return value;
  final parsed = num.tryParse('${value ?? ''}');
  if (parsed == null) {
    throw ToolArgumentError('"$name" must be a number, got "${value ?? ''}".');
  }
  return parsed;
}

int _int(Object? value, String name) => _number(value, name).round();

/// Forecasting, contract and capacity tools.
List<ToolDescriptor> businessToolsAdvanced() => <ToolDescriptor>[
      ToolDescriptor(
        id: 'freelance.canTakeJob',
        name: 'Can I Take This Job?',
        description: 'Check whether a project still makes sense at your rate.',
        category: ToolCategory.freelancer,
        tags: <String>['decision', 'quote', 'rate', 'worth'],
        synonyms: <String>['is this job worth taking'],
        parameters: <ToolParameter>[
          _num('quotedPrice', 'What the client will pay.', required: true),
          _num('estimatedHours', 'Hours you expect to spend.', required: true),
          _num('minimumRate', 'The lowest rate you accept.', required: true),
          _num('otherCosts', 'Direct costs to cover.', fallback: 0),
        ],
        run: (args) async {
          final price = _number(args['quotedPrice'], 'quotedPrice');
          final hours = _number(args['estimatedHours'], 'estimatedHours');
          final minRate = _number(args['minimumRate'], 'minimumRate');
          final other = _number(args['otherCosts'], 'otherCosts');
          if (hours <= 0) {
            return const ToolResult.failure('estimatedHours must be above 0.');
          }
          final net = price - other;
          final effective = net / hours;
          final meetsFloor = effective >= minRate;
          return ToolResult.success(<String, dynamic>{
            'effectiveRate': _money(effective),
            'minimumRate': _money(minRate),
            'meetsMinimum': meetsFloor,
            'profit': _money(net),
            'verdict': meetsFloor
                ? 'Worth taking at ${_money(effective)} per hour.'
                : 'Below your floor of ${_money(minRate)}. Renegotiate or decline.',
          });
        },
      ),
      ToolDescriptor(
        id: 'freelance.paymentTerms',
        name: 'Payment Due Date',
        description: 'Due date and ageing from an invoice date and terms.',
        category: ToolCategory.freelancer,
        tags: <String>['payment', 'terms', 'due', 'ageing'],
        synonyms: <String>['when is this due', 'invoice due date'],
        parameters: <ToolParameter>[
          _text('invoiceDate', 'Invoice date as YYYY-MM-DD.', required: true),
          _num('netDays', 'Payment terms in days.', required: true),
          _text('today', 'Today as YYYY-MM-DD.', defaultValue: ''),
        ],
        run: (args) async {
          final invoiceDate = _parseDate(args['invoiceDate'] as String);
          if (invoiceDate == null) {
            return const ToolResult.failure(
              'invoiceDate must look like YYYY-MM-DD.',
            );
          }
          final terms = _int(args['netDays'], 'netDays');
          if (terms < 0) {
            return const ToolResult.failure('netDays cannot be negative.');
          }
          final due = invoiceDate.add(Duration(days: terms));
          final todayRaw = (args['today'] as String? ?? '').trim();
          final today = todayRaw.isEmpty ? DateTime.now() : _parseDate(todayRaw);
          final daysLate = today == null ? 0 : today.difference(due).inDays;
          return ToolResult.success(<String, dynamic>{
            'dueDate': _formatDate(due),
            'termsDays': terms,
            'daysUntilDue': daysLate < 0 ? -daysLate : 0,
            'daysLate': daysLate > 0 ? daysLate : 0,
            'overdue': daysLate > 0,
          });
        },
      ),
      ToolDescriptor(
        id: 'freelance.rateCard',
        name: 'Rate Card',
        description: 'Build a rate card across roles from one base rate.',
        category: ToolCategory.freelancer,
        tags: <String>['rate card', 'roles', 'pricing', 'multiplier'],
        synonyms: <String>['rates per role', 'build a rate card'],
        parameters: <ToolParameter>[
          _num('baseRate', 'Rate for the junior role.', required: true),
          _num('midMultiplier', 'Multiplier for mid-level.', fallback: 1.5),
          _num('seniorMultiplier', 'Multiplier for senior.', fallback: 2.5),
        ],
        run: (args) async {
          final base = _number(args['baseRate'], 'baseRate');
          final mid = _number(args['midMultiplier'], 'midMultiplier');
          final senior = _number(args['seniorMultiplier'], 'seniorMultiplier');
          if (base < 0) {
            return const ToolResult.failure('baseRate cannot be negative.');
          }
          if (mid < 1 || senior < mid) {
            return const ToolResult.failure(
              'Multipliers must be at least 1 and senior must not be below mid.',
            );
          }
          return ToolResult.success(<String, dynamic>{
            'roles': <Map<String, dynamic>>[
              <String, dynamic>{'role': 'Junior', 'rate': _money(base)},
              <String, dynamic>{'role': 'Mid-level', 'rate': _money(base * mid)},
              <String, dynamic>{
                'role': 'Senior',
                'rate': _money(base * senior),
              },
            ],
          });
        },
      ),
      ToolDescriptor(
        id: 'freelance.capacity',
        name: 'Capacity This Month',
        description: 'How much work fits in the time you actually have.',
        category: ToolCategory.freelancer,
        tags: <String>['capacity', 'availability', 'hours', 'planning'],
        synonyms: <String>['how much work can i take'],
        parameters: <ToolParameter>[
          _num('workingDays', 'Working days available.', required: true),
          _num('hoursPerDay', 'Hours per day.', fallback: 8),
          _num('bookedHours', 'Hours already committed.', fallback: 0),
          _num('targetUtilisationPercent', 'Utilisation you aim for.',
              fallback: 75),
        ],
        run: (args) async {
          final days = _number(args['workingDays'], 'workingDays');
          final perDay = _number(args['hoursPerDay'], 'hoursPerDay');
          final booked = _number(args['bookedHours'], 'bookedHours');
          final target = _number(
              args['targetUtilisationPercent'], 'targetUtilisationPercent');
          if (days < 0 || perDay <= 0) {
            return const ToolResult.failure(
              'workingDays cannot be negative and hoursPerDay must be above 0.',
            );
          }
          final available = days * perDay;
          final targetHours = available * target / 100;
          return ToolResult.success(<String, dynamic>{
            'availableHours': _round(available, 1),
            'bookedHours': _round(booked, 1),
            'freeHours': _round(available - booked, 1),
            'targetBookableHours': _round(targetHours, 1),
            'overbookedBy': _round(booked - targetHours, 1),
            'atTarget': booked <= targetHours,
          });
        },
      ),
      ToolDescriptor(
        id: 'freelance.utilisationGap',
        name: 'Utilisation Gap',
        description: 'The gap between billed and non-billable hours.',
        category: ToolCategory.freelancer,
        tags: <String>['utilisation', 'gap', 'admin', 'time'],
        synonyms: <String>['how much time goes on admin'],
        parameters: <ToolParameter>[
          _num('billableHours', 'Hours billed.', required: true),
          _num('totalHours', 'Total hours worked.', required: true),
          _num('hourlyRate', 'Rate billed at.', fallback: 0),
        ],
        run: (args) async {
          final billable = _number(args['billableHours'], 'billableHours');
          final total = _number(args['totalHours'], 'totalHours');
          final rate = _number(args['hourlyRate'], 'hourlyRate');
          if (total <= 0) {
            return const ToolResult.failure('totalHours must be above 0.');
          }
          final admin = total - billable;
          return ToolResult.success(<String, dynamic>{
            'utilisationPercent': _round(billable / total * 100, 1),
            'adminHours': _round(admin, 1),
            'adminValue': _money(admin * rate),
            'toBillHoursIfFullDay':
                (rate > 0 ? (admin * rate / rate).ceil() : 0),
          });
        },
      ),
      ToolDescriptor(
        id: 'business.revenueTarget',
        name: 'Revenue Target',
        description: 'What you must bill each period to hit a yearly target.',
        category: ToolCategory.business,
        tags: <String>['target', 'revenue', 'forecast', 'goal'],
        synonyms: <String>['what do i need to bill to hit my target'],
        parameters: <ToolParameter>[
          _num('annualTarget', 'Target for the year.', required: true),
          _num('billableDays', 'Billable days in the year.', required: true),
          _num('targetMarginPercent', 'Margin you need.', fallback: 40),
        ],
        run: (args) async {
          final target = _number(args['annualTarget'], 'annualTarget');
          final days = _number(args['billableDays'], 'billableDays');
          final margin = _number(args['targetMarginPercent'], 'targetMarginPercent');
          if (target <= 0) {
            return const ToolResult.failure('annualTarget must be above 0.');
          }
          if (days <= 0) {
            return const ToolResult.failure('billableDays must be above 0.');
          }
          if (margin <= 0 || margin >= 100) {
            return const ToolResult.failure(
              'targetMarginPercent must be between 0 and 100.',
            );
          }
          final neededRevenue = target / (margin / 100);
          return ToolResult.success(<String, dynamic>{
            'requiredRevenue': _money(neededRevenue),
            'perBillableDay': _money(neededRevenue / days),
            'perMonth': _money(neededRevenue / 12),
            'targetProfit': _money(target),
            'targetMarginPercent': margin,
          });
        },
      ),
      ToolDescriptor(
        id: 'business.recurringRevenue',
        name: 'Monthly Run Rate',
        description: 'Normalise revenue across irregular months.',
        category: ToolCategory.business,
        tags: <String>['recurring', 'run rate', 'average', 'monthly'],
        synonyms: <String>['average monthly revenue', 'run rate'],
        parameters: <ToolParameter>[
          _num('totalRevenue', 'Revenue across the period.', required: true),
          _num('months', 'Months in the period.', required: true),
        ],
        run: (args) async {
          final total = _number(args['totalRevenue'], 'totalRevenue');
          final months = _number(args['months'], 'months');
          if (months <= 0) {
            return const ToolResult.failure('months must be above 0.');
          }
          return ToolResult.success(<String, dynamic>{
            'monthlyRunRate': _money(total / months),
            'annualised': _money(total / months * 12),
            'totalRevenue': _money(total),
            'months': months,
          });
        },
      ),
      ToolDescriptor(
        id: 'business.paybackPeriod',
        name: 'Payback Period',
        description: 'How long until an investment pays for itself.',
        category: ToolCategory.business,
        tags: <String>['payback', 'investment', 'roi', 'time'],
        synonyms: <String>['how long until this pays off'],
        parameters: <ToolParameter>[
          _num('investment', 'Upfront cost.', required: true),
          _num('monthlyProfit', 'Profit added each month.', required: true),
        ],
        run: (args) async {
          final investment = _number(args['investment'], 'investment');
          final monthly = _number(args['monthlyProfit'], 'monthlyProfit');
          if (monthly <= 0) {
            return const ToolResult.failure(
              'monthlyProfit must be above 0 to pay back.',
            );
          }
          if (investment <= 0) {
            return const ToolResult.failure('investment must be above 0.');
          }
          final months = investment / monthly;
          return ToolResult.success(<String, dynamic>{
            'monthsToPayback': _round(months, 2),
            'yearsToPayback': _round(months / 12, 2),
          });
        },
      ),
      ToolDescriptor(
        id: 'business.roi',
        name: 'Return on Investment',
        description: 'ROI from a gain against an investment.',
        category: ToolCategory.business,
        tags: <String>['roi', 'return', 'investment', 'performance'],
        synonyms: <String>['what is my roi'],
        parameters: <ToolParameter>[
          _num('gain', 'Value gained.', required: true),
          _num('investment', 'Amount invested.', required: true),
        ],
        run: (args) async {
          final gain = _number(args['gain'], 'gain');
          final investment = _number(args['investment'], 'investment');
          if (investment <= 0) {
            return const ToolResult.failure('investment must be above 0.');
          }
          final roi = gain / investment * 100;
          return ToolResult.success(<String, dynamic>{
            'roiPercent': _round(roi, 1),
            'multiple': _round(1 + gain / investment, 2),
            'totalValue': _money(gain + investment),
          });
        },
      ),
      ToolDescriptor(
        id: 'business.discountImpact',
        name: 'Discount Impact',
        description: 'What a discount costs you in profit.',
        category: ToolCategory.business,
        tags: <String>['discount', 'profit', 'sacrifice', 'impact'],
        synonyms: <String>['what does discounting cost me'],
        parameters: <ToolParameter>[
          _num('listPrice', 'Price without discount.', required: true),
          _num('discountPercent', 'Discount offered.', required: true),
          _num('costs', 'Direct costs.', fallback: 0),
        ],
        run: (args) async {
          final list = _number(args['listPrice'], 'listPrice');
          final discount = _number(args['discountPercent'], 'discountPercent');
          final costs = _number(args['costs'], 'costs');
          if (discount < 0 || discount > 100) {
            return const ToolResult.failure(
              'discountPercent must be between 0 and 100.',
            );
          }
          final discounted = list * (1 - discount / 100);
          final fullProfit = list - costs;
          final discountedProfit = discounted - costs;
          return ToolResult.success(<String, dynamic>{
            'discountedPrice': _money(discounted),
            'discountAmount': _money(list - discounted),
            'profitBefore': _money(fullProfit),
            'profitAfter': _money(discountedProfit),
            'profitGivenAway': _money(fullProfit - discountedProfit),
            'marginAfterPercent': discounted == 0
                ? 0.0
                : _round(discountedProfit / discounted * 100, 1),
          });
        },
      ),
      ToolDescriptor(
        id: 'business.expenseRatio',
        name: 'Expense Ratio',
        description: 'Expenses as a share of revenue, and what is left.',
        category: ToolCategory.business,
        tags: <String>['expenses', 'ratio', 'overhead', 'costs'],
        synonyms: <String>['expense ratio', 'overhead percentage'],
        parameters: <ToolParameter>[
          _num('revenue', 'Revenue.', required: true),
          _num('expenses', 'Total expenses.', required: true),
        ],
        run: (args) async {
          final revenue = _number(args['revenue'], 'revenue');
          final expenses = _number(args['expenses'], 'expenses');
          if (revenue <= 0) {
            return const ToolResult.failure('revenue must be above 0.');
          }
          return ToolResult.success(<String, dynamic>{
            'expenseRatioPercent': _round(expenses / revenue * 100, 1),
            'retained': _money(revenue - expenses),
            'retainedPercent': _round((revenue - expenses) / revenue * 100, 1),
          });
        },
      ),
      ToolDescriptor(
        id: 'business.costEscalation',
        name: 'Cost Escalation',
        description: "Project today's costs forward with annual inflation.",
        category: ToolCategory.business,
        tags: <String>['inflation', 'escalation', 'future', 'planning'],
        synonyms: <String>['what will this cost next year'],
        parameters: <ToolParameter>[
          _num('cost', "Today's cost.", required: true),
          _num('inflationPercent', 'Annual inflation.', required: true),
          _num('years', 'Years ahead.', required: true),
        ],
        run: (args) async {
          final cost = _number(args['cost'], 'cost');
          final rate = _number(args['inflationPercent'], 'inflationPercent');
          final years = _number(args['years'], 'years');
          if (years < 0) {
            return const ToolResult.failure('years cannot be negative.');
          }
          var future = cost;
          final yearly = <Map<String, dynamic>>[];
          for (var year = 1; year <= years.round(); year++) {
            future *= (1 + rate / 100);
            yearly.add(<String, dynamic>{
              'year': year,
              'cost': _money(future),
            });
          }
          return ToolResult.success(<String, dynamic>{
            'futureCost': _money(future),
            'increaseAmount': _money(future - cost),
            'increasePercent':
                cost == 0 ? 0.0 : _round((future / cost - 1) * 100, 1),
            'yearly': yearly,
          });
        },
      ),
      ToolDescriptor(
        id: 'business.withholding',
        name: 'Profit After Withholding',
        description: 'Net profit once a withholding or deductions bite.',
        category: ToolCategory.business,
        tags: <String>['withholding', 'deduction', 'net', 'paye'],
        synonyms: <String>['after deductions', 'net of withholding'],
        parameters: <ToolParameter>[
          _num('grossAmount', 'Gross received.', required: true),
          _num('withholdingPercent', 'Withholding rate.', required: true),
          _num('otherDeductions', 'Other deductions.', fallback: 0),
        ],
        run: (args) async {
          final gross = _number(args['grossAmount'], 'grossAmount');
          final rate = _number(args['withholdingPercent'], 'withholdingPercent');
          final other = _number(args['otherDeductions'], 'otherDeductions');
          if (rate < 0 || rate > 100) {
            return const ToolResult.failure(
              'withholdingPercent must be between 0 and 100.',
            );
          }
          final withheld = gross * rate / 100;
          return ToolResult.success(<String, dynamic>{
            'withheld': _money(withheld),
            'otherDeductions': _money(other),
            'net': _money(gross - withheld - other),
            'effectiveRatePercent':
                gross == 0 ? 0.0 : _round((withheld + other) / gross * 100, 1),
          });
        },
      ),
      ToolDescriptor(
        id: 'business.minimumProjectPrice',
        name: 'Minimum Viable Price',
        description: 'The lowest price worth taking on a project.',
        category: ToolCategory.freelancer,
        tags: <String>['minimum', 'floor', 'price', 'worth'],
        synonyms: <String>['what is the least i should charge'],
        parameters: <ToolParameter>[
          _num('estimatedHours', 'Hours expected.', required: true),
          _num('minimumRate', 'Your floor rate.', required: true),
          _num('overheadPercent', 'Overhead to cover.', fallback: 20),
        ],
        run: (args) async {
          final hours = _number(args['estimatedHours'], 'estimatedHours');
          final rate = _number(args['minimumRate'], 'minimumRate');
          final overhead = _number(args['overheadPercent'], 'overheadPercent');
          if (hours <= 0) {
            return const ToolResult.failure('estimatedHours must be above 0.');
          }
          final floor = hours * rate * (1 + overhead / 100);
          return ToolResult.success(<String, dynamic>{
            'minimumPrice': _money(floor),
            'rawHoursValue': _money(hours * rate),
            'overheadCovered': _money(floor - hours * rate),
            'perHourEffective': _money(floor / hours),
          });
        },
      ),
      ToolDescriptor(
        id: 'business.quoteSplit',
        name: 'Quote Line Split',
        description: 'Split a quote across deliverable line items.',
        category: ToolCategory.freelancer,
        tags: <String>['quote', 'split', 'line items', 'breakdown'],
        synonyms: <String>['break a quote into parts'],
        parameters: <ToolParameter>[
          _num('total', 'Total quote value.', required: true),
          _num('itemCount', 'Number of line items.', required: true),
          _num('designPercent', 'Percent allocated to design.', fallback: 0),
        ],
        run: (args) async {
          final total = _number(args['total'], 'total');
          final count = _int(args['itemCount'], 'itemCount');
          final design = _number(args['designPercent'], 'designPercent');
          if (count < 1) {
            return const ToolResult.failure('itemCount must be at least 1.');
          }
          if (design < 0 || design > 100) {
            return const ToolResult.failure(
              'designPercent must be between 0 and 100.',
            );
          }
          final designAmount = total * design / 100;
          final buildAmount = total - designAmount;
          return ToolResult.success(<String, dynamic>{
            'design': _money(designAmount),
            'build': _money(buildAmount),
            'evenShare': _money(total / count),
            'lineItems': <Map<String, dynamic>>[
              <String, dynamic>{'name': 'Design', 'amount': _money(designAmount)},
              <String, dynamic>{'name': 'Build', 'amount': _money(buildAmount)},
            ],
          });
        },
      ),
      ToolDescriptor(
        id: 'business.projectedProfit',
        name: 'Projected Profit Scenarios',
        description: 'Profit at low, expected and high estimates.',
        category: ToolCategory.business,
        tags: <String>['scenario', 'forecast', 'range', 'risk'],
        synonyms: <String>['worst case best case profit'],
        parameters: <ToolParameter>[
          _num('bestHours', 'Best-case hours.', required: true),
          _num('expectedHours', 'Expected hours.', required: true),
          _num('worstHours', 'Worst-case hours.', required: true),
          _num('hourlyRate', 'Rate charged.', required: true),
          _num('fixedCosts', 'Costs regardless.', fallback: 0),
        ],
        run: (args) async {
          final best = _number(args['bestHours'], 'bestHours');
          final expected = _number(args['expectedHours'], 'expectedHours');
          final worst = _number(args['worstHours'], 'worstHours');
          final rate = _number(args['hourlyRate'], 'hourlyRate');
          final costs = _number(args['fixedCosts'], 'fixedCosts');
          if (worst < expected || expected < best) {
            return const ToolResult.failure(
              'Supply hours so that worstHours >= expectedHours >= bestHours.',
            );
          }
          return ToolResult.success(<String, dynamic>{
            'best': _money(best * rate - costs),
            'expected': _money(expected * rate - costs),
            'worst': _money(worst * rate - costs),
            'range': _money((worst - best) * rate),
            'verdict': worst * rate - costs > 0
                ? 'Profitable even in the worst case.'
                : 'You lose money if the project runs long. Price for the worst '
                    'case or add a change-order clause.',
          });
        },
      ),
    ];

DateTime? _parseDate(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value.trim());
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  return DateTime(year, month, day);
}

String _formatDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
