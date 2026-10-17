/// Freelancer and business tools: quoting, billing, rates and the money side
/// of running a project.
///
/// Money maths is where a wrong answer actually costs someone, so these tools
/// are deliberately explicit about what they assume (percentages are entered
/// as whole numbers, tax is added after discount, and every result states the
/// inputs it used).
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

/// Round to two decimal places, the precision money is quoted in.
double _money(num value) => (value * 100).round() / 100;

/// Freelancer and business tools.
List<ToolDescriptor> businessTools() => <ToolDescriptor>[
      ToolDescriptor(
        id: 'freelance.hourlyToProject',
        name: 'Hourly to Project Price',
        description: 'Price a project from hours and an hourly rate.',
        category: ToolCategory.freelancer,
        tags: <String>['price', 'quote', 'hourly', 'rate'],
        synonyms: <String>['how much should i charge', 'price by hours'],
        parameters: <ToolParameter>[
          _num('hours', 'Estimated hours.', required: true),
          _num('hourlyRate', 'Your hourly rate.', required: true),
          _num('markupPercent', 'Contingency or overhead on top.', fallback: 0),
        ],
        run: (args) async {
          final hours = _number(args['hours'], 'hours');
          final rate = _number(args['hourlyRate'], 'hourlyRate');
          final markup = _number(args['markupPercent'], 'markupPercent');
          if (hours < 0) {
            return const ToolResult.failure('hours cannot be negative.');
          }
          if (rate < 0) {
            return const ToolResult.failure('hourlyRate cannot be negative.');
          }
          final base = hours * rate;
          final withMarkup = base * (1 + markup / 100);
          return ToolResult.success(<String, dynamic>{
            'base': _money(base),
            'total': _money(withMarkup),
            'markupAmount': _money(withMarkup - base),
            'assumptions': 'hours x rate, then +${_round(markup, 2)}% markup',
          });
        },
      ),
      ToolDescriptor(
        id: 'freelance.dayRateToHourly',
        name: 'Day Rate to Hourly',
        description: 'Convert a day rate into an hourly rate.',
        category: ToolCategory.freelancer,
        tags: <String>['day rate', 'hourly', 'convert', 'rate'],
        synonyms: <String>['day rate per hour', 'convert day rate'],
        parameters: <ToolParameter>[
          _num('dayRate', 'Your day rate.', required: true),
          _num('hoursPerDay', 'Billable hours in a day.', fallback: 8),
        ],
        run: (args) async {
          final dayRate = _number(args['dayRate'], 'dayRate');
          final hours = _number(args['hoursPerDay'], 'hoursPerDay');
          if (hours <= 0) {
            return const ToolResult.failure('hoursPerDay must be above 0.');
          }
          return ToolResult.success(<String, dynamic>{
            'hourlyRate': _money(dayRate / hours),
            'dayRate': _money(dayRate),
            'note': 'Working ${_round(hours, 2)}-hour days.',
          });
        },
      ),
      ToolDescriptor(
        id: 'freelance.quoteWithTax',
        name: 'Quote with Tax',
        description: 'Add tax to a quote and report the breakdown.',
        category: ToolCategory.freelancer,
        tags: <String>['quote', 'tax', 'vat', 'total'],
        synonyms: <String>['add tax to my quote', 'quote total with vat'],
        parameters: <ToolParameter>[
          _num('netAmount', 'Price before tax.', required: true),
          _num('taxPercent', 'Tax rate as a percentage.', required: true),
          _num('discountPercent', 'Discount applied first.', fallback: 0),
        ],
        run: (args) async {
          final net = _number(args['netAmount'], 'netAmount');
          final tax = _number(args['taxPercent'], 'taxPercent');
          final discount = _number(args['discountPercent'], 'discountPercent');
          if (tax < 0 || discount < 0) {
            return const ToolResult.failure(
              'taxPercent and discountPercent cannot be negative.',
            );
          }
          final discounted = net * (1 - discount / 100);
          final taxAmount = discounted * tax / 100;
          final total = discounted + taxAmount;
          return ToolResult.success(<String, dynamic>{
            'netAmount': _money(net),
            'afterDiscount': _money(discounted),
            'taxAmount': _money(taxAmount),
            'total': _money(total),
            'order': 'discount, then tax',
          });
        },
      ),
      ToolDescriptor(
        id: 'freelance.invoiceTotal',
        name: 'Invoice Total',
        description: 'Invoice total with tax, discount and an optional deposit.',
        category: ToolCategory.freelancer,
        tags: <String>['invoice', 'total', 'tax', 'billing'],
        synonyms: <String>['invoice total', 'what do i invoice'],
        parameters: <ToolParameter>[
          _num('subtotal', 'Sum of line items.', required: true),
          _num('taxPercent', 'Tax rate.', fallback: 0),
          _num('discountAmount', 'Flat discount.', fallback: 0),
          _num('depositPaid', 'Already paid.', fallback: 0),
        ],
        run: (args) async {
          final subtotal = _number(args['subtotal'], 'subtotal');
          final tax = _number(args['taxPercent'], 'taxPercent');
          final discount = _number(args['discountAmount'], 'discountAmount');
          final paid = _number(args['depositPaid'], 'depositPaid');
          final discounted = subtotal - discount;
          final taxAmount = discounted * tax / 100;
          final total = discounted + taxAmount;
          return ToolResult.success(<String, dynamic>{
            'subtotal': _money(subtotal),
            'discount': _money(discount),
            'taxAmount': _money(taxAmount),
            'total': _money(total),
            'balanceDue': _money(total - paid),
          });
        },
      ),
      ToolDescriptor(
        id: 'freelance.milestonePlan',
        name: 'Milestone Plan',
        description: 'Split a project total across weighted milestones.',
        category: ToolCategory.freelancer,
        tags: <String>['milestone', 'stages', 'split', 'billing'],
        synonyms: <String>['split payment into stages', 'milestone breakdown'],
        parameters: <ToolParameter>[
          _num('total', 'Total project price.', required: true),
          _num('depositPercent', 'Deposit taken up front.', fallback: 30),
          _num('milestoneCount', 'Number of milestones.', fallback: 4),
        ],
        run: (args) async {
          final total = _number(args['total'], 'total');
          final depositPercent = _number(args['depositPercent'], 'depositPercent');
          final count = _int(args['milestoneCount'], 'milestoneCount');
          if (total < 0) {
            return const ToolResult.failure('total cannot be negative.');
          }
          if (depositPercent < 0 || depositPercent > 100) {
            return const ToolResult.failure(
              'depositPercent must be between 0 and 100.',
            );
          }
          if (count < 1) {
            return const ToolResult.failure('milestoneCount must be at least 1.');
          }
          final deposit = total * depositPercent / 100;
          final remaining = total - deposit;
          final each = remaining / count;
          return ToolResult.success(<String, dynamic>{
            'deposit': _money(deposit),
            'milestoneAmount': _money(each),
            'milestoneCount': count,
            'finalTotal': _money(deposit + each * count),
            'schedule': <Map<String, dynamic>>[
              <String, dynamic>{'milestone': 'Deposit', 'amount': _money(deposit)},
              for (var i = 1; i <= count; i++)
                <String, dynamic>{
                  'milestone': 'Milestone $i',
                  'amount': _money(each),
                },
            ],
          });
        },
      ),
      ToolDescriptor(
        id: 'freelance.effectiveRate',
        name: 'Effective Hourly Rate',
        description: 'What you actually earned per hour, including unpaid time.',
        category: ToolCategory.freelancer,
        tags: <String>['effective', 'rate', 'profit', 'unpaid'],
        synonyms: <String>['what did i really earn per hour'],
        parameters: <ToolParameter>[
          _num('paidAmount', 'Total paid to you.', required: true),
          _num('billableHours', 'Hours billed.', required: true),
          _num('unpaidHours', 'Hours worked but not billed.', fallback: 0),
        ],
        run: (args) async {
          final paid = _number(args['paidAmount'], 'paidAmount');
          final billable = _number(args['billableHours'], 'billableHours');
          final unpaid = _number(args['unpaidHours'], 'unpaidHours');
          final totalHours = billable + unpaid;
          if (totalHours <= 0) {
            return const ToolResult.failure('total hours must be above 0.');
          }
          return ToolResult.success(<String, dynamic>{
            'effectiveRate': _money(paid / totalHours),
            'billedRate': billable > 0 ? _money(paid / billable) : 0.0,
            'unpaidHours': unpaid,
            'unpaidHoursPercent':
                _round(unpaid / totalHours * 100, 1),
          });
        },
      ),
      ToolDescriptor(
        id: 'freelance.billableSplit',
        name: 'Billable Split',
        description: 'Split hours into billable and non-billable.',
        category: ToolCategory.freelancer,
        tags: <String>['billable', 'hours', 'utilisation', 'tracking'],
        synonyms: <String>['utilisation', 'how much of my time was billable'],
        parameters: <ToolParameter>[
          _num('billableHours', 'Hours billed.', required: true),
          _num('nonBillableHours', 'Hours not billed.', fallback: 0),
          _num('hourlyRate', 'Rate applied to billable hours.', fallback: 0),
        ],
        run: (args) async {
          final billable = _number(args['billableHours'], 'billableHours');
          final nonBillable =
              _number(args['nonBillableHours'], 'nonBillableHours');
          final rate = _number(args['hourlyRate'], 'hourlyRate');
          final total = billable + nonBillable;
          if (total <= 0) {
            return const ToolResult.failure('total hours must be above 0.');
          }
          return ToolResult.success(<String, dynamic>{
            'totalHours': _round(total, 2),
            'utilisationPercent': _round(billable / total * 100, 1),
            'earned': _money(billable * rate),
            'unbilledValue': _money(nonBillable * rate),
          });
        },
      ),
      ToolDescriptor(
        id: 'freelance.retainerConsumed',
        name: 'Retainer Consumed',
        description: 'How much of a monthly retainer has been used.',
        category: ToolCategory.freelancer,
        tags: <String>['retainer', 'hours', 'consumed', 'remaining'],
        synonyms: <String>['how much retainer is left'],
        parameters: <ToolParameter>[
          _num('retainerAmount', 'Retainer per month.', required: true),
          _num('hoursUsed', 'Hours used this month.', required: true),
          _num('hourlyRate', 'Rate implied by the retainer.', required: true),
        ],
        run: (args) async {
          final retainer = _number(args['retainerAmount'], 'retainerAmount');
          final used = _number(args['hoursUsed'], 'hoursUsed');
          final rate = _number(args['hourlyRate'], 'hourlyRate');
          if (rate <= 0) {
            return const ToolResult.failure('hourlyRate must be above 0.');
          }
          final includedHours = retainer / rate;
          if (used < 0) {
            return const ToolResult.failure('hoursUsed cannot be negative.');
          }
          final usedValue = used * rate;
          return ToolResult.success(<String, dynamic>{
            'includedHours': _round(includedHours, 2),
            'hoursRemaining': _round(includedHours - used, 2),
            'valueRemaining': _money(retainer - usedValue),
            'overageValue': usedValue > retainer ? _money(usedValue - retainer) : 0.0,
            'percentUsed': _round(used / includedHours * 100, 1),
          });
        },
      ),
      ToolDescriptor(
        id: 'freelance.latePayment',
        name: 'Late Payment Penalty',
        description: 'Interest on an overdue invoice.',
        category: ToolCategory.freelancer,
        tags: <String>['late', 'overdue', 'interest', 'invoice'],
        synonyms: <String>['late payment penalty', 'interest on overdue invoice'],
        parameters: <ToolParameter>[
          _num('invoiceAmount', 'Invoice total.', required: true),
          _num('daysLate', 'Days past due.', required: true),
          _num('annualRatePercent', 'Annual interest rate.', fallback: 8),
        ],
        run: (args) async {
          final amount = _number(args['invoiceAmount'], 'invoiceAmount');
          final days = _number(args['daysLate'], 'daysLate');
          final rate = _number(args['annualRatePercent'], 'annualRatePercent');
          if (days < 0) {
            return const ToolResult.failure('daysLate cannot be negative.');
          }
          final interest = amount * rate / 100 * days / 365;
          return ToolResult.success(<String, dynamic>{
            'interest': _money(interest),
            'amountDue': _money(amount + interest),
            'dailyInterest': _money(amount * rate / 100 / 365),
            'note': 'Simple interest on a 365-day year. Check your contract '
                'before applying it.',
          });
        },
      ),
      ToolDescriptor(
        id: 'freelance.depositToStart',
        name: 'Deposit to Start',
        description: 'Deposit needed to start, and what it leaves you covering.',
        category: ToolCategory.freelancer,
        tags: <String>['deposit', 'start', 'upfront', 'kickoff'],
        synonyms: <String>['how much deposit should i take'],
        parameters: <ToolParameter>[
          _num('projectTotal', 'Total project price.', required: true),
          _num('firstPhaseCost', 'Your cost to start.', required: true),
          _num('depositPercent', 'Deposit percentage.', fallback: 40),
        ],
        run: (args) async {
          final total = _number(args['projectTotal'], 'projectTotal');
          final cost = _number(args['firstPhaseCost'], 'firstPhaseCost');
          final percent = _number(args['depositPercent'], 'depositPercent');
          if (percent < 0 || percent > 100) {
            return const ToolResult.failure(
              'depositPercent must be between 0 and 100.',
            );
          }
          final deposit = total * percent / 100;
          final covered = deposit >= cost;
          return ToolResult.success(<String, dynamic>{
            'deposit': _money(deposit),
            'coversStartUpCost': covered,
            'shortfall': _money(covered ? 0 : cost - deposit),
            'breakEvenDepositPercent':
                total == 0 ? 0 : _round(cost / total * 100, 1),
            'advice': covered
                ? 'The deposit covers your cost to start.'
                : 'Raise the deposit to at least '
                    '${total == 0 ? 0 : _round(cost / total * 100, 1)}%.',
          });
        },
      ),

      // ── Business ───────────────────────────────────────────────────────
      ToolDescriptor(
        id: 'business.projectProfit',
        name: 'Project Profit',
        description: 'Profit and margin for a project.',
        category: ToolCategory.business,
        tags: <String>['profit', 'margin', 'project', 'costs'],
        synonyms: <String>['did we make money', 'project profitability'],
        parameters: <ToolParameter>[
          _num('revenue', 'What the client paid.', required: true),
          _num('costs', 'Direct costs.', required: true),
          _num('hours', 'Hours spent.', fallback: 0),
          _num('hourlyCost', 'Your internal cost per hour.', fallback: 0),
        ],
        run: (args) async {
          final revenue = _number(args['revenue'], 'revenue');
          final direct = _number(args['costs'], 'costs');
          final hours = _number(args['hours'], 'hours');
          final hourlyCost = _number(args['hourlyCost'], 'hourlyCost');
          final labour = hours * hourlyCost;
          final totalCosts = direct + labour;
          final profit = revenue - totalCosts;
          return ToolResult.success(<String, dynamic>{
            'revenue': _money(revenue),
            'directCosts': _money(direct),
            'labourCost': _money(labour),
            'totalCosts': _money(totalCosts),
            'profit': _money(profit),
            'marginPercent': revenue == 0
                ? 0.0
                : _round(profit / revenue * 100, 1),
            'profitable': profit > 0,
          });
        },
      ),
      ToolDescriptor(
        id: 'business.markupToMargin',
        name: 'Markup to Margin',
        description: 'Convert a markup percentage into a profit margin.',
        category: ToolCategory.business,
        tags: <String>['markup', 'margin', 'pricing', 'convert'],
        synonyms: <String>['markup vs margin', 'convert markup'],
        parameters: <ToolParameter>[
          _num('markupPercent', 'Markup on cost.', required: true),
        ],
        run: (args) async {
          final markup = _number(args['markupPercent'], 'markupPercent');
          if (markup <= -100) {
            return const ToolResult.failure('markupPercent must be above -100.');
          }
          final margin = markup / (100 + markup) * 100;
          return ToolResult.success(<String, dynamic>{
            'markupPercent': _round(markup, 2),
            'marginPercent': _round(margin, 2),
            'note': 'Markup is measured on cost; margin on the selling price. '
                'They are never the same number.',
          });
        },
      ),
      ToolDescriptor(
        id: 'business.priceFromMargin',
        name: 'Price from Margin',
        description: 'The price you need to hit a target margin.',
        category: ToolCategory.business,
        tags: <String>['price', 'margin', 'target', 'costs'],
        synonyms: <String>['what should i charge for this cost'],
        parameters: <ToolParameter>[
          _num('cost', 'Total cost.', required: true),
          _num('targetMarginPercent', 'Margin you want.', required: true),
        ],
        run: (args) async {
          final cost = _number(args['cost'], 'cost');
          final margin = _number(args['targetMarginPercent'], 'targetMarginPercent');
          if (margin >= 100) {
            return const ToolResult.failure(
              'targetMarginPercent must be below 100.',
            );
          }
          if (margin <= -100) {
            return const ToolResult.failure(
              'targetMarginPercent must be above -100.',
            );
          }
          final price = cost / (1 - margin / 100);
          return ToolResult.success(<String, dynamic>{
            'price': _money(price),
            'profit': _money(price - cost),
            'marginPercent': margin,
            'note': 'Margin is measured on the selling price, not the cost.',
          });
        },
      ),
      ToolDescriptor(
        id: 'business.taxSetAside',
        name: 'Tax Set-Aside',
        description: 'How much of income to reserve for tax.',
        category: ToolCategory.business,
        tags: <String>['tax', 'reserve', 'set aside', 'hmrc'],
        synonyms: <String>['how much to put away for tax'],
        parameters: <ToolParameter>[
          _num('profit', 'Profit for the period.', required: true),
          _num('taxPercent', 'Effective tax rate.', required: true),
          _num('alreadyReserved', 'Already set aside.', fallback: 0),
        ],
        run: (args) async {
          final profit = _number(args['profit'], 'profit');
          final rate = _number(args['taxPercent'], 'taxPercent');
          final reserved = _number(args['alreadyReserved'], 'alreadyReserved');
          if (rate < 0 || rate > 100) {
            return const ToolResult.failure(
              'taxPercent must be between 0 and 100.',
            );
          }
          final required = profit * rate / 100;
          return ToolResult.success(<String, dynamic>{
            'taxRequired': _money(required),
            'takeHome': _money(profit - required),
            'alreadyReserved': _money(reserved),
            'stillToReserve': _money(required - reserved > 0 ? required - reserved : 0),
          });
        },
      ),
      ToolDescriptor(
        id: 'business.breakEven',
        name: 'Break-Even',
        description: 'How many units or jobs cover your fixed costs.',
        category: ToolCategory.business,
        tags: <String>['break even', 'fixed costs', 'units', 'pricing'],
        synonyms: <String>['how many jobs to break even'],
        parameters: <ToolParameter>[
          _num('fixedCosts', 'Costs regardless of volume.', required: true),
          _num('pricePerUnit', 'Price charged per unit.', required: true),
          _num('variableCostPerUnit', 'Cost per unit.', fallback: 0),
        ],
        run: (args) async {
          final fixed = _number(args['fixedCosts'], 'fixedCosts');
          final price = _number(args['pricePerUnit'], 'pricePerUnit');
          final variable = _number(args['variableCostPerUnit'], 'variableCostPerUnit');
          final contribution = price - variable;
          if (contribution <= 0) {
            return const ToolResult.failure(
              'Each unit must contribute more than it costs, otherwise you can '
              'never break even.',
            );
          }
          final units = fixed / contribution;
          return ToolResult.success(<String, dynamic>{
            'breakEvenUnits': _round(units, 2),
            'unitsToRoundUpTo': units.ceil(),
            'contributionPerUnit': _money(contribution),
            'contributionMarginPercent':
                price == 0 ? 0.0 : _round(contribution / price * 100, 1),
          });
        },
      ),
      ToolDescriptor(
        id: 'business.budgetBurn',
        name: 'Budget Burn Rate',
        description: 'How fast a budget is being consumed and where it lands.',
        category: ToolCategory.business,
        tags: <String>['budget', 'burn', 'spend', 'projection'],
        synonyms: <String>['are we over budget', 'budget burn rate'],
        parameters: <ToolParameter>[
          _num('budget', 'Total budget.', required: true),
          _num('spent', 'Spent so far.', required: true),
          _num('daysElapsed', 'Days elapsed.', required: true),
          _num('totalDays', 'Total days in the project.', required: true),
        ],
        run: (args) async {
          final budget = _number(args['budget'], 'budget');
          final spent = _number(args['spent'], 'spent');
          final elapsed = _number(args['daysElapsed'], 'daysElapsed');
          final total = _number(args['totalDays'], 'totalDays');
          if (budget <= 0) {
            return const ToolResult.failure('budget must be above 0.');
          }
          if (elapsed <= 0 || total <= 0) {
            return const ToolResult.failure(
              'daysElapsed and totalDays must be above 0.',
            );
          }
          final dailySpend = spent / elapsed;
          final projected = dailySpend * total;
          return ToolResult.success(<String, dynamic>{
            'percentUsed': _round(spent / budget * 100, 1),
            'dailySpend': _money(dailySpend),
            'projectedTotal': _money(projected),
            'remaining': _money(budget - spent),
            'onTrack': projected <= budget,
            'overBy': projected > budget ? _money(projected - budget) : 0.0,
            'percentTimeUsed': _round(elapsed / total * 100, 1),
          });
        },
      ),
      ToolDescriptor(
        id: 'business.cashFlow',
        name: 'Cash Flow Projection',
        description: 'Project the bank balance across a simple timeline.',
        category: ToolCategory.business,
        tags: <String>['cash flow', 'forecast', 'bank', 'projection'],
        synonyms: <String>['will i run out of money', 'cash flow forecast'],
        parameters: <ToolParameter>[
          _num('startingBalance', 'Money in the bank now.', required: true),
          _num('monthlyIncome', 'Money coming in each period.', required: true),
          _num('monthlyCosts', 'Money going out each period.', required: true),
          _num('periods', 'Number of periods.', fallback: 6),
        ],
        run: (args) async {
          final start = _number(args['startingBalance'], 'startingBalance');
          final income = _number(args['monthlyIncome'], 'monthlyIncome');
          final costs = _number(args['monthlyCosts'], 'monthlyCosts');
          final periods = _int(args['periods'], 'periods');
          if (periods < 1) {
            return const ToolResult.failure('periods must be at least 1.');
          }
          final net = income - costs;
          var balance = start;
          var lowest = start;
          final timeline = <Map<String, dynamic>>[
            <String, dynamic>{'period': 0, 'balance': _money(start)},
          ];
          for (var period = 1; period <= periods; period++) {
            balance += net;
            if (balance < lowest) lowest = balance;
            timeline.add(<String, dynamic>{
              'period': period,
              'balance': _money(balance),
            });
          }
          return ToolResult.success(<String, dynamic>{
            'netPerPeriod': _money(net),
            'finalBalance': _money(balance),
            'lowestBalance': _money(lowest),
            'goesNegative': lowest < 0,
            'timeline': timeline,
          });
        },
      ),
      ToolDescriptor(
        id: 'business.currency',
        name: 'Currency Conversion',
        description: 'Convert between two currencies at a given rate.',
        category: ToolCategory.business,
        tags: <String>['currency', 'exchange', 'convert', 'rate'],
        synonyms: <String>['convert currency', 'exchange rate maths'],
        parameters: <ToolParameter>[
          _num('amount', 'Amount to convert.', required: true),
          _num('rate', 'Units of target per 1 unit of source.', required: true),
          _text('from', 'Source currency.', defaultValue: 'USD'),
          _text('to', 'Target currency.', defaultValue: 'EUR'),
        ],
        run: (args) async {
          final amount = _number(args['amount'], 'amount');
          final rate = _number(args['rate'], 'rate');
          if (rate <= 0) {
            return const ToolResult.failure('rate must be above 0.');
          }
          return ToolResult.success(<String, dynamic>{
            'converted': _money(amount * rate),
            'from': args['from'],
            'to': args['to'],
            'rate': rate,
            'inverseRate': _round(1 / rate, 6),
          });
        },
      ),
      ToolDescriptor(
        id: 'business.costPerClient',
        name: 'Cost per Client',
        description: 'Cost and margin for each client on a roster.',
        category: ToolCategory.business,
        tags: <String>['clients', 'cost', 'roster', 'unit economics'],
        synonyms: <String>['average cost per client'],
        parameters: <ToolParameter>[
          _num('totalCosts', 'Total costs.', required: true),
          _num('clientCount', 'Number of clients.', required: true),
          _num('averageRevenue', 'Average revenue per client.', fallback: 0),
        ],
        run: (args) async {
          final costs = _number(args['totalCosts'], 'totalCosts');
          final clients = _number(args['clientCount'], 'clientCount');
          final revenue = _number(args['averageRevenue'], 'averageRevenue');
          if (clients <= 0) {
            return const ToolResult.failure('clientCount must be above 0.');
          }
          final perClient = costs / clients;
          return ToolResult.success(<String, dynamic>{
            'costPerClient': _money(perClient),
            'revenuePerClient': _money(revenue),
            'profitPerClient': _money(revenue - perClient),
            'marginPercent': revenue == 0
                ? 0.0
                : _round((revenue - perClient) / revenue * 100, 1),
          });
        },
      ),
      ToolDescriptor(
        id: 'business.scopeChangePrice',
        name: 'Scope Change Price',
        description: 'Price additional work discovered mid-project.',
        category: ToolCategory.business,
        tags: <String>['scope', 'change', 'extra', 'variation'],
        synonyms: <String>['charge for extra work', 'variation order'],
        parameters: <ToolParameter>[
          _num('extraHours', 'Extra hours needed.', required: true),
          _num('hourlyRate', 'Your rate.', required: true),
          _num('fixedFee', 'Flat fee instead of hours.', fallback: 0),
          _num('taxPercent', 'Tax to add.', fallback: 0),
        ],
        run: (args) async {
          final hours = _number(args['extraHours'], 'extraHours');
          final rate = _number(args['hourlyRate'], 'hourlyRate');
          final fixed = _number(args['fixedFee'], 'fixedFee');
          final tax = _number(args['taxPercent'], 'taxPercent');
          final net = fixed > 0 ? fixed : hours * rate;
          final total = net * (1 + tax / 100);
          return ToolResult.success(<String, dynamic>{
            'net': _money(net),
            'taxAmount': _money(total - net),
            'total': _money(total),
            'basis': fixed > 0 ? 'flat fee' : 'hours x rate',
          });
        },
      ),
      ToolDescriptor(
        id: 'business.pricingTiers',
        name: 'Pricing Tiers',
        description: 'Build good/better/best tiers from a base price.',
        category: ToolCategory.business,
        tags: <String>['tiers', 'pricing', 'packages', 'upsell'],
        synonyms: <String>['package pricing', 'three tier pricing'],
        parameters: <ToolParameter>[
          _num('basePrice', 'The middle tier.', required: true),
          _num('entryPercent', 'Entry tier relative to base.', fallback: 60),
          _num('premiumPercent', 'Premium tier relative to base.', fallback: 180),
        ],
        run: (args) async {
          final base = _number(args['basePrice'], 'basePrice');
          final entry = _number(args['entryPercent'], 'entryPercent');
          final premium = _number(args['premiumPercent'], 'premiumPercent');
          if (base < 0) {
            return const ToolResult.failure('basePrice cannot be negative.');
          }
          if (entry >= premium) {
            return const ToolResult.failure(
              'entryPercent must be below premiumPercent.',
            );
          }
          return ToolResult.success(<String, dynamic>{
            'tiers': <Map<String, dynamic>>[
              <String, dynamic>{
                'name': 'Good',
                'price': _money(base * entry / 100),
              },
              <String, dynamic>{
                'name': 'Better',
                'price': _money(base),
              },
              <String, dynamic>{
                'name': 'Best',
                'price': _money(base * premium / 100),
              },
            ],
          });
        },
      ),
      ToolDescriptor(
        id: 'business.marginAfterTax',
        name: 'Margin After Tax',
        description: 'Real margin once tax and costs are taken out.',
        category: ToolCategory.business,
        tags: <String>['margin', 'tax', 'net', 'profit'],
        synonyms: <String>['what do i actually keep'],
        parameters: <ToolParameter>[
          _num('revenue', 'Money in.', required: true),
          _num('costs', 'Money out in costs.', required: true),
          _num('taxPercent', 'Tax rate on profit.', fallback: 0),
        ],
        run: (args) async {
          final revenue = _number(args['revenue'], 'revenue');
          final costs = _number(args['costs'], 'costs');
          final tax = _number(args['taxPercent'], 'taxPercent');
          final profit = revenue - costs;
          final taxAmount = profit > 0 ? profit * tax / 100 : 0.0;
          final net = profit - taxAmount;
          return ToolResult.success(<String, dynamic>{
            'grossProfit': _money(profit),
            'taxAmount': _money(taxAmount),
            'netProfit': _money(net),
            'netMarginPercent': revenue == 0
                ? 0.0
                : _round(net / revenue * 100, 1),
          });
        },
      ),
    ];

// ── helpers ─────────────────────────────────────────────────────────────

num _number(Object? value, String name) {
  if (value is num) return value;
  final parsed = num.tryParse('${value ?? ''}');
  if (parsed == null) {
    throw ToolArgumentError('"$name" must be a number, got "${value ?? ''}".');
  }
  return parsed;
}

int _int(Object? value, String name) => _number(value, name).round();

double _round(num value, int places) {
  var factor = 1.0;
  for (var i = 0; i < places; i++) {
    factor *= 10;
  }
  return (value * factor).round() / factor;
}
