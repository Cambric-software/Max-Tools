import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tool_shell.dart';

/// One movement of money.
class _Entry {
  _Entry({
    required this.date,
    required this.amount,
    required this.income,
    required this.category,
    this.note = '',
  });

  final DateTime date;
  final double amount;
  final bool income;
  final String category;
  final String note;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'date': date.toIso8601String(),
        'amount': amount,
        'income': income,
        'category': category,
        'note': note,
      };

  static _Entry fromJson(Map<String, dynamic> json) => _Entry(
        date: DateTime.tryParse('${json['date']}') ?? DateTime.now(),
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        income: json['income'] == true,
        category: '${json['category'] ?? 'Other'}',
        note: '${json['note'] ?? ''}',
      );
}

/// Something owned (asset) or owed (liability).
class _Account {
  _Account({
    required this.name,
    required this.balance,
    required this.liability,
  });

  final String name;
  final double balance;
  final bool liability;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'balance': balance,
        'liability': liability,
      };

  static _Account fromJson(Map<String, dynamic> json) => _Account(
        name: '${json['name'] ?? 'Account'}',
        balance: (json['balance'] as num?)?.toDouble() ?? 0,
        liability: json['liability'] == true,
      );
}

/// Wealth: accounts, day-to-day money, charts and the three calculations
/// people actually need.
///
/// Everything is stored locally and nothing is sent anywhere. The charts are
/// drawn from the entries below them, so a chart can never disagree with the
/// list it came from.
class WealthTool extends StatefulWidget {
  /// Create the tool.
  const WealthTool({super.key});

  @override
  State<WealthTool> createState() => _WealthToolState();
}

class _WealthToolState extends State<WealthTool>
    with SingleTickerProviderStateMixin {
  static const String _storageKey = 'max_tools.wealth.v1';

  late final TabController _tabs = TabController(length: 4, vsync: this);

  final List<_Entry> _entries = <_Entry>[];
  final List<_Account> _accounts = <_Account>[];
  final TextEditingController _currencyController =
      TextEditingController(text: 'EGP');
  String _currency = 'EGP';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _currency = '${decoded['currency'] ?? 'EGP'}';
          final accounts = decoded['accounts'];
          if (accounts is List) {
            _accounts.addAll(accounts
                .whereType<Map<String, dynamic>>()
                .map(_Account.fromJson));
          }
          final entries = decoded['entries'];
          if (entries is List) {
            _entries.addAll(entries
                .whereType<Map<String, dynamic>>()
                .map(_Entry.fromJson));
          }
        }
      }
    } catch (_) {
      // Corrupt storage starts empty rather than blocking the tool.
    }
    _currencyController.text = _currency;
    if (!mounted) return;
    setState(() => _loaded = true);
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode(<String, dynamic>{
          'currency': _currency,
          'accounts': _accounts.map((_Account a) => a.toJson()).toList(),
          'entries': _entries.map((_Entry e) => e.toJson()).toList(),
        }),
      );
    } catch (_) {
      // The figures stay correct on screen; only persistence failed.
    }
  }

  double get _assets => _accounts
      .where((_Account a) => !a.liability)
      .fold(0, (double sum, _Account a) => sum + a.balance);

  double get _liabilities => _accounts
      .where((_Account a) => a.liability)
      .fold(0, (double sum, _Account a) => sum + a.balance);

  double get _netWorth => _assets - _liabilities;

  String _money(double value) =>
      '${value.toStringAsFixed(2)} $_currency';

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wealth'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const <Widget>[
            Tab(text: 'Overview'),
            Tab(text: 'Money in and out'),
            Tab(text: 'Accounts'),
            Tab(text: 'Plan'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: <Widget>[
          _overview(context),
          _entriesTab(context),
          _accountsTab(context),
          _planTab(context),
        ],
      ),
    );
  }

  // ── overview ─────────────────────────────────────────────────────────────

  Widget _overview(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final monthEntries = _entries
        .where((_Entry e) =>
            e.date.year == now.year && e.date.month == now.month)
        .toList();
    final income = monthEntries
        .where((_Entry e) => e.income)
        .fold(0.0, (double s, _Entry e) => s + e.amount);
    final spending = monthEntries
        .where((_Entry e) => !e.income)
        .fold(0.0, (double s, _Entry e) => s + e.amount);
    final byCategory = <String, double>{};
    for (final entry in monthEntries.where((_Entry e) => !e.income)) {
      byCategory[entry.category] =
          (byCategory[entry.category] ?? 0) + entry.amount;
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Card(
          color: theme.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Net worth',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _money(_netWorth),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Assets ${_money(_assets)}  ·  Liabilities '
                  '${_money(_liabilities)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'This month',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _figure(
                        context,
                        'In',
                        _money(income),
                        Colors.green.shade600,
                      ),
                    ),
                    Expanded(
                      child: _figure(
                        context,
                        'Out',
                        _money(spending),
                        Colors.red.shade600,
                      ),
                    ),
                    Expanded(
                      child: _figure(
                        context,
                        'Kept',
                        _money(income - spending),
                        (income - spending) >= 0
                            ? theme.colorScheme.primary
                            : Colors.red.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Tooltip(
                  message: 'Net worth is what you own minus what you owe. '
                      '"Kept" is income minus spending for this calendar month. '
                      'Both come straight from the entries you add below.',
                  child: Text(
                    'Net worth = assets − liabilities. Kept = income − spending.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Six months of money in and out',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Green is money in, red is money out. A month with no entries '
                  'is drawn empty rather than estimated.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 190,
                  child: CustomPaint(
                    painter: _BarChartPainter(
                      months: _recentMonths(6),
                      income: _monthlyTotals(income: true, months: 6),
                      expense: _monthlyTotals(income: false, months: 6),
                      labelColour: theme.colorScheme.onSurfaceVariant,
                      gridColour: theme.colorScheme.outlineVariant,
                      textDirection: Directionality.of(context),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Where this month’s spending went',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                if (byCategory.isEmpty)
                  Text(
                    'No spending recorded this month yet.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  _spendingBreakdown(context, byCategory, spending),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _explain(
          context,
          'How to read this page',
          'Add what you own and owe under Accounts, then add each movement of '
              'money under Money in and out. Net worth is the first thing to '
              'watch: it is the single number that combines everything. The '
              'monthly bars show whether you are keeping more than you spend, '
              'and the ring shows which category is taking the largest share. '
              'Nothing here is synced to a bank, so the accuracy is exactly the '
              'accuracy of what you enter.',
        ),
      ],
    );
  }

  Widget _figure(
    BuildContext context,
    String label,
    String value,
    Color colour,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: colour,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// The ring and its legend use one ordered list, so a swatch and its segment
  /// are always the same colour.
  Widget _spendingBreakdown(
    BuildContext context,
    Map<String, double> byCategory,
    double spending,
  ) {
    final theme = Theme.of(context);
    final ordered = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final colours = _palette(context, ordered.length);

    return SizedBox(
      height: math.max(170, ordered.length * 26.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 150,
            height: 150,
            child: CustomPaint(
              painter: _DonutPainter(
                values: ordered.map((MapEntry<String, double> e) => e.value)
                    .toList(),
                colours: colours,
              ),
              child: Center(
                child: Text(
                  _money(spending),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (var i = 0; i < ordered.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: colours[i % colours.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(ordered[i].key)),
                        Text(_money(ordered[i].value)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _recentMonths(int count) {
    const names = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final now = DateTime.now();
    return <String>[
      for (var back = count - 1; back >= 0; back--)
        names[DateTime(now.year, now.month - back).month - 1],
    ];
  }

  List<double> _monthlyTotals({required bool income, required int months}) {
    final now = DateTime.now();
    return <double>[
      for (var back = months - 1; back >= 0; back--)
        _entries
            .where((_Entry e) =>
                e.income == income &&
                e.date.year == DateTime(now.year, now.month - back).year &&
                e.date.month == DateTime(now.year, now.month - back).month)
            .fold(0.0, (double s, _Entry e) => s + e.amount),
    ];
  }

  List<Color> _palette(BuildContext context, int count) {
    final base = Theme.of(context).colorScheme.primary;
    final hsl = HSLColor.fromColor(base);
    return <Color>[
      for (var i = 0; i < math.max(count, 1); i++)
        hsl
            .withHue((hsl.hue + i * 47) % 360)
            .withLightness((0.42 + (i % 3) * 0.08).clamp(0.0, 1.0))
            .toColor(),
    ];
  }

  // ── entries ──────────────────────────────────────────────────────────────

  Widget _entriesTab(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = _entries.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Text(
          'Every movement of money, newest first.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => _addEntry(context),
            icon: const Icon(Icons.add),
            label: const Text('Add income or expense'),
          ),
        ),
        const SizedBox(height: 16),
        if (sorted.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('Nothing recorded yet.'),
            ),
          )
        else
          for (final entry in sorted)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: entry.income
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.red.withValues(alpha: 0.12),
                  child: Icon(
                    entry.income
                        ? Icons.south_west
                        : Icons.north_east,
                    color: entry.income
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),
                title: Text(entry.category),
                subtitle: Text(
                  '${entry.date.year}-${entry.date.month.toString().padLeft(2, '0')}-'
                  '${entry.date.day.toString().padLeft(2, '0')}'
                  '${entry.note.isEmpty ? '' : ' · ${entry.note}'}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '${entry.income ? '+' : '−'}${_money(entry.amount)}',
                      style: TextStyle(
                        color: entry.income
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline, size: 19),
                      onPressed: () {
                        setState(() => _entries.remove(entry));
                        _save();
                      },
                    ),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 16),
        _explain(
          context,
          'Why record each movement?',
          'A balance tells you where you are. Entries tell you how you got '
              'there. Once there are a few weeks of entries, the Overview page '
              'can show which category is growing and whether your income is '
              'actually ahead. Record the amount as a positive number and choose '
              'income or expense — the sign is handled for you.',
        ),
      ],
    );
  }

  Future<void> _addEntry(BuildContext context) async {
    final added = await showDialog<_Entry>(
      context: context,
      builder: (_) => _EntryDialog(currency: _currency),
    );
    if (added == null) return;
    setState(() => _entries.add(added));
    await _save();
  }

  // ── accounts ─────────────────────────────────────────────────────────────

  Widget _accountsTab(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Text(
          'What you own and what you owe.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _currencyController,
          decoration: const InputDecoration(
            labelText: 'Currency label',
            helperText: 'Shown next to every amount. Use EGP, USD, or any '
                'label you prefer.',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (String value) {
            final trimmed = value.trim();
            setState(() => _currency = trimmed.isEmpty ? 'EGP' : trimmed);
            _save();
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            FilledButton.icon(
              onPressed: () => _addAccount(context, liability: false),
              icon: const Icon(Icons.add),
              label: const Text('Add asset'),
            ),
            OutlinedButton.icon(
              onPressed: () => _addAccount(context, liability: true),
              icon: const Icon(Icons.add),
              label: const Text('Add liability'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_accounts.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'Add cash, savings, investments, a car, or a loan and a card '
                'balance. Net worth updates immediately.',
              ),
            ),
          )
        else ...<Widget>[
          for (final account in _accounts)
            Card(
              child: ListTile(
                leading: Icon(
                  account.liability
                      ? Icons.credit_card_outlined
                      : Icons.account_balance_wallet_outlined,
                  color: account.liability
                      ? Colors.red.shade700
                      : Colors.green.shade700,
                ),
                title: Text(account.name),
                subtitle: Text(account.liability ? 'Liability' : 'Asset'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      _money(account.balance),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline, size: 19),
                      onPressed: () {
                        setState(() => _accounts.remove(account));
                        _save();
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 16),
        _explain(
          context,
          'Asset or liability?',
          'An asset is something that could be turned into money: cash, a bank '
              'balance, investments, property. A liability is something you owe: '
              'a loan, a card balance, unpaid rent. Net worth subtracts the '
              'second from the first. Do not include the same money twice — if '
              'a savings account is listed, its interest should not also be '
              'added as cash.',
        ),
      ],
    );
  }

  Future<void> _addAccount(
    BuildContext context, {
    required bool liability,
  }) async {
    final added = await showDialog<_Account>(
      context: context,
      builder: (_) => _AccountDialog(liability: liability, currency: _currency),
    );
    if (added == null) return;
    setState(() => _accounts.add(added));
    await _save();
  }

  // ── plan ─────────────────────────────────────────────────────────────────

  Widget _planTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        _explain(
          context,
          'Three questions these calculators answer',
          'How much will regular saving grow to? What will a loan really cost '
              'each month? How long until a savings goal is reached? Each '
              'calculator states the formula it uses, so the number can be '
              'checked by hand. Results are estimates: they assume a constant '
              'rate, which no real investment guarantees.',
        ),
        const SizedBox(height: 16),
        _CompoundCalculator(currency: _currency),
        const SizedBox(height: 16),
        _LoanCalculator(currency: _currency),
        const SizedBox(height: 16),
        _GoalCalculator(currency: _currency),
      ],
    );
  }

  Widget _explain(BuildContext context, String title, String body) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.lightbulb_outline,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.55),
            ),
          ],
        ),
      ),
    );
  }
}

// ── dialogs ────────────────────────────────────────────────────────────────

class _EntryDialog extends StatefulWidget {
  const _EntryDialog({required this.currency});

  final String currency;

  @override
  State<_EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<_EntryDialog> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _category = TextEditingController();
  final TextEditingController _note = TextEditingController();
  bool _income = false;
  DateTime _date = DateTime.now();
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _category.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a movement'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SegmentedButton<bool>(
              segments: const <ButtonSegment<bool>>[
                ButtonSegment<bool>(value: false, label: Text('Expense')),
                ButtonSegment<bool>(value: true, label: Text('Income')),
              ],
              selected: <bool>{_income},
              onSelectionChanged: (Set<bool> value) =>
                  setState(() => _income = value.first),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount (${widget.currency})',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                hintText: 'Food, rent, salary…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Date: ${_date.year}-'
                    '${_date.month.toString().padLeft(2, '0')}-'
                    '${_date.day.toString().padLeft(2, '0')}',
                  ),
                ),
                TextButton(
                  onPressed: _pickDate,
                  child: const Text('Change'),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount greater than zero.');
      return;
    }
    if (_category.text.trim().isEmpty) {
      setState(() => _error = 'Give it a category so the chart can group it.');
      return;
    }
    Navigator.of(context).pop(
      _Entry(
        date: _date,
        amount: amount,
        income: _income,
        category: _category.text.trim(),
        note: _note.text.trim(),
      ),
    );
  }
}

class _AccountDialog extends StatefulWidget {
  const _AccountDialog({required this.liability, required this.currency});

  final bool liability;
  final String currency;

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _balance = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.liability ? 'Add a liability' : 'Add an asset'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _balance,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: widget.liability
                  ? 'Amount owed (${widget.currency})'
                  : 'Current value (${widget.currency})',
              border: const OutlineInputBorder(),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final balance = double.tryParse(_balance.text.trim());
            if (_name.text.trim().isEmpty) {
              setState(() => _error = 'Give it a name.');
              return;
            }
            if (balance == null || balance < 0) {
              setState(() => _error = 'Enter a value of zero or more.');
              return;
            }
            Navigator.of(context).pop(
              _Account(
                name: _name.text.trim(),
                balance: balance,
                liability: widget.liability,
              ),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

// ── calculators ────────────────────────────────────────────────────────────

class _CompoundCalculator extends StatefulWidget {
  const _CompoundCalculator({required this.currency});

  final String currency;

  @override
  State<_CompoundCalculator> createState() => _CompoundCalculatorState();
}

class _CompoundCalculatorState extends State<_CompoundCalculator> {
  final TextEditingController _start = TextEditingController(text: '0');
  final TextEditingController _monthly = TextEditingController(text: '1000');
  final TextEditingController _rate = TextEditingController(text: '8');
  final TextEditingController _years = TextEditingController(text: '10');

  List<TextEditingController> get _all =>
      <TextEditingController>[_start, _monthly, _rate, _years];

  @override
  void initState() {
    super.initState();
    for (final controller in _all) {
      controller.addListener(_refresh);
    }
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    for (final controller in _all) {
      controller.removeListener(_refresh);
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final start = double.tryParse(_start.text) ?? 0;
    final monthly = double.tryParse(_monthly.text) ?? 0;
    final annual = (double.tryParse(_rate.text) ?? 0) / 100;
    final years = (double.tryParse(_years.text) ?? 0).clamp(0, 80);
    final months = (years * 12).round();
    final monthlyRate = annual / 12;

    var future = start;
    for (var i = 0; i < months; i++) {
      future = future * (1 + monthlyRate) + monthly;
    }
    final contributed = start + monthly * months;
    final growth = future - contributed;

    return ToolSection(
      title: 'Savings growth',
      icon: Icons.trending_up,
      children: <Widget>[
        _numberField(_start, 'Starting amount (${widget.currency})'),
        _numberField(_monthly, 'Added each month (${widget.currency})'),
        _numberField(_rate, 'Annual growth rate (%)'),
        _numberField(_years, 'Years'),
        const SizedBox(height: 12),
        Text(
          'After $months months: ${future.toStringAsFixed(2)} ${widget.currency}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          'You put in ${contributed.toStringAsFixed(2)}; growth adds '
          '${growth.toStringAsFixed(2)}.',
        ),
        const ToolNote(
          'Formula: each month the balance grows by rate ÷ 12, then the monthly '
          'addition is applied. This assumes the rate is constant and the '
          'contribution is made at the end of each month.',
        ),
      ],
    );
  }
}

class _LoanCalculator extends StatefulWidget {
  const _LoanCalculator({required this.currency});

  final String currency;

  @override
  State<_LoanCalculator> createState() => _LoanCalculatorState();
}

class _LoanCalculatorState extends State<_LoanCalculator> {
  final TextEditingController _principal = TextEditingController(text: '100000');
  final TextEditingController _rate = TextEditingController(text: '12');
  final TextEditingController _months = TextEditingController(text: '60');

  List<TextEditingController> get _all =>
      <TextEditingController>[_principal, _rate, _months];

  @override
  void initState() {
    super.initState();
    for (final controller in _all) {
      controller.addListener(_refresh);
    }
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    for (final controller in _all) {
      controller.removeListener(_refresh);
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final principal = double.tryParse(_principal.text) ?? 0;
    final annual = (double.tryParse(_rate.text) ?? 0) / 100;
    final months = (double.tryParse(_months.text) ?? 0).clamp(1, 600);
    final monthlyRate = annual / 12;

    final payment = monthlyRate == 0
        ? principal / months
        : principal *
            monthlyRate *
            math.pow(1 + monthlyRate, months) /
            (math.pow(1 + monthlyRate, months) - 1);
    final total = payment * months;
    final interest = total - principal;

    return ToolSection(
      title: 'Loan repayment',
      icon: Icons.account_balance_outlined,
      children: <Widget>[
        _numberField(_principal, 'Amount borrowed (${widget.currency})'),
        _numberField(_rate, 'Annual interest rate (%)'),
        _numberField(_months, 'Repayment period (months)'),
        const SizedBox(height: 12),
        Text(
          'Monthly payment: ${payment.toStringAsFixed(2)} ${widget.currency}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          'Total paid ${total.toStringAsFixed(2)}; interest '
          '${interest.toStringAsFixed(2)}.',
        ),
        const ToolNote(
          'Formula: the standard amortisation payment, '
          'P × r ÷ (1 − (1 + r)⁻ⁿ), where r is the monthly rate. The last '
          'payment may differ by a rounding amount with a real lender.',
        ),
      ],
    );
  }
}

class _GoalCalculator extends StatefulWidget {
  const _GoalCalculator({required this.currency});

  final String currency;

  @override
  State<_GoalCalculator> createState() => _GoalCalculatorState();
}

class _GoalCalculatorState extends State<_GoalCalculator> {
  final TextEditingController _goal = TextEditingController(text: '50000');
  final TextEditingController _current = TextEditingController(text: '0');
  final TextEditingController _monthly = TextEditingController(text: '2000');
  final TextEditingController _rate = TextEditingController(text: '6');

  List<TextEditingController> get _all =>
      <TextEditingController>[_goal, _current, _monthly, _rate];

  @override
  void initState() {
    super.initState();
    for (final controller in _all) {
      controller.addListener(_refresh);
    }
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    for (final controller in _all) {
      controller.removeListener(_refresh);
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goal = double.tryParse(_goal.text) ?? 0;
    final current = double.tryParse(_current.text) ?? 0;
    final monthly = double.tryParse(_monthly.text) ?? 0;
    final annual = (double.tryParse(_rate.text) ?? 0) / 100;
    final monthlyRate = annual / 12;

    String answer;
    if (current >= goal) {
      answer = 'You have already reached this goal.';
    } else if (monthly <= 0 && monthlyRate <= 0) {
      answer = 'With nothing added and no growth, this goal is never reached.';
    } else {
      var balance = current;
      var months = 0;
      while (balance < goal && months < 1200) {
        balance = balance * (1 + monthlyRate) + monthly;
        months++;
      }
      answer = months >= 1200
          ? 'More than 100 years at this rate. Increase the monthly amount.'
          : 'About $months months (${(months / 12).toStringAsFixed(1)} years).';
    }

    return ToolSection(
      title: 'Time to a goal',
      icon: Icons.flag_outlined,
      children: <Widget>[
        _numberField(_goal, 'Goal (${widget.currency})'),
        _numberField(_current, 'Already saved (${widget.currency})'),
        _numberField(_monthly, 'Added each month (${widget.currency})'),
        _numberField(_rate, 'Annual growth rate (%)'),
        const SizedBox(height: 12),
        Text(answer, style: Theme.of(context).textTheme.titleMedium),
        const ToolNote(
          'The balance is grown monthly, then the contribution is added, until '
          'it reaches the goal. Fees and tax are not modelled.',
        ),
      ],
    );
  }
}

Widget _numberField(TextEditingController controller, String label) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    ),
  );
}

// ── charts ─────────────────────────────────────────────────────────────────

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({
    required this.months,
    required this.income,
    required this.expense,
    required this.labelColour,
    required this.gridColour,
    required this.textDirection,
  });

  final List<String> months;
  final List<double> income;
  final List<double> expense;
  final Color labelColour;
  final Color gridColour;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = <double>[...income, ...expense]
        .fold<double>(0, math.max);
    if (maxValue <= 0) {
      _drawEmpty(canvas, size);
      return;
    }

    const bottom = 22.0;
    final chartHeight = size.height - bottom;
    final groupWidth = size.width / months.length;

    final grid = Paint()
      ..color = gridColour
      ..strokeWidth = 1;

    for (var i = 0; i <= 3; i++) {
      final y = chartHeight * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    for (var i = 0; i < months.length; i++) {
      final centre = groupWidth * i + groupWidth / 2;
      final barWidth = math.min(16.0, groupWidth / 3.5);
      final inHeight = chartHeight * (income[i] / maxValue);
      final outHeight = chartHeight * (expense[i] / maxValue);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            centre - barWidth - 2,
            chartHeight - inHeight,
            barWidth,
            inHeight,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = Colors.green.shade600,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            centre + 2,
            chartHeight - outHeight,
            barWidth,
            outHeight,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = Colors.red.shade600,
      );

      final painter = TextPainter(
        text: TextSpan(
          text: months[i],
          style: TextStyle(color: labelColour, fontSize: 11),
        ),
        textDirection: textDirection,
      )..layout(maxWidth: groupWidth);
      painter.paint(
        canvas,
        Offset(centre - painter.width / 2, chartHeight + 5),
      );
    }
  }

  void _drawEmpty(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: const TextSpan(
        text: 'No entries yet',
        style: TextStyle(color: Colors.grey, fontSize: 13),
      ),
      textDirection: textDirection,
    )..layout(maxWidth: size.width);
    painter.paint(
      canvas,
      Offset((size.width - painter.width) / 2, size.height / 2 - 8),
    );
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) =>
      old.income != income || old.expense != expense;
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.values, required this.colours});

  final List<double> values;
  final List<Color> colours;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (double s, double v) => s + v);
    if (total <= 0) return;

    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: math.min(size.width, size.height) / 2 - 6,
    );

    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = (values[i] / total) * math.pi * 2;
      canvas.drawArc(
        rect,
        start,
        sweep - 0.02,
        false,
        Paint()
          ..color = colours[i % colours.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 22
          ..strokeCap = StrokeCap.butt,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.values != values || old.colours != colours;
}
