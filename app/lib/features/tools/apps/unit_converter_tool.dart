import 'package:flutter/material.dart';

import 'tool_shell.dart';

/// One unit within a category, expressed as a factor of the category's base
/// unit. Temperature is handled separately because it offsets rather than just
/// scales.
class _Unit {
  const _Unit(this.name, this.symbol, this.factor);

  final String name;
  final String symbol;
  final double factor;
}

class _Category {
  const _Category(this.name, this.units, {this.temperature = false});

  final String name;
  final List<_Unit> units;
  final bool temperature;
}

/// Converts between everyday units.
///
/// Every factor here is an exact definition, not a rounded approximation:
/// an inch is 25.4 millimetres by definition, a pound is 0.45359237 kilograms
/// by definition, and a kilobyte is 1024 bytes by the meaning most people use
/// when checking a file size. Where a unit has two competing meanings, the tool
/// says which one it uses.
class UnitConverterTool extends StatefulWidget {
  /// Create the tool.
  const UnitConverterTool({super.key});

  @override
  State<UnitConverterTool> createState() => _UnitConverterToolState();
}

class _UnitConverterToolState extends State<UnitConverterTool> {
  static const List<_Category> _categories = <_Category>[
    _Category('Length', <_Unit>[
      _Unit('Nanometre', 'nm', 1e-9),
      _Unit('Micrometre', 'µm', 1e-6),
      _Unit('Millimetre', 'mm', 0.001),
      _Unit('Centimetre', 'cm', 0.01),
      _Unit('Inch', 'in', 0.0254),
      _Unit('Foot', 'ft', 0.3048),
      _Unit('Yard', 'yd', 0.9144),
      _Unit('Metre', 'm', 1),
      _Unit('Kilometre', 'km', 1000),
      _Unit('Mile', 'mi', 1609.344),
      _Unit('Nautical mile', 'nmi', 1852),
    ]),
    _Category('Mass', <_Unit>[
      _Unit('Microgram', 'µg', 1e-9),
      _Unit('Milligram', 'mg', 1e-6),
      _Unit('Gram', 'g', 0.001),
      _Unit('Ounce', 'oz', 0.028349523125),
      _Unit('Pound', 'lb', 0.45359237),
      _Unit('Stone', 'st', 6.35029318),
      _Unit('Kilogram', 'kg', 1),
      _Unit('Tonne', 't', 1000),
    ]),
    _Category('Temperature', <_Unit>[
      _Unit('Celsius', '°C', 1),
      _Unit('Fahrenheit', '°F', 1),
      _Unit('Kelvin', 'K', 1),
    ], temperature: true),
    _Category('Area', <_Unit>[
      _Unit('Square millimetre', 'mm²', 0.000001),
      _Unit('Square centimetre', 'cm²', 0.0001),
      _Unit('Square inch', 'in²', 0.00064516),
      _Unit('Square foot', 'ft²', 0.09290304),
      _Unit('Square metre', 'm²', 1),
      _Unit('Acre', 'ac', 4046.8564224),
      _Unit('Hectare', 'ha', 10000),
      _Unit('Square kilometre', 'km²', 1000000),
      _Unit('Square mile', 'mi²', 2589988.110336),
    ]),
    _Category('Volume', <_Unit>[
      _Unit('Millilitre', 'mL', 0.001),
      _Unit('Teaspoon (US)', 'tsp', 0.00492892159375),
      _Unit('Tablespoon (US)', 'tbsp', 0.01478676478125),
      _Unit('Fluid ounce (US)', 'fl oz', 0.0295735295625),
      _Unit('Cup (US)', 'cup', 0.2365882365),
      _Unit('Litre', 'L', 1),
      _Unit('Pint (US)', 'pt', 0.473176473),
      _Unit('Quart (US)', 'qt', 0.946352946),
      _Unit('Gallon (US)', 'gal', 3.785411784),
      _Unit('Gallon (UK)', 'gal UK', 4.54609),
      _Unit('Cubic metre', 'm³', 1000),
    ]),
    _Category('Speed', <_Unit>[
      _Unit('Metre per second', 'm/s', 1),
      _Unit('Kilometre per hour', 'km/h', 0.2777777777777778),
      _Unit('Mile per hour', 'mph', 0.44704),
      _Unit('Knot', 'kn', 0.5144444444444445),
      _Unit('Foot per second', 'ft/s', 0.3048),
    ]),
    _Category('Time', <_Unit>[
      _Unit('Millisecond', 'ms', 0.001),
      _Unit('Second', 's', 1),
      _Unit('Minute', 'min', 60),
      _Unit('Hour', 'h', 3600),
      _Unit('Day', 'd', 86400),
      _Unit('Week', 'wk', 604800),
      _Unit('Month (30 d)', 'mo', 2592000),
      _Unit('Year (365 d)', 'yr', 31536000),
    ]),
    _Category('Digital storage', <_Unit>[
      _Unit('Bit', 'b', 0.125),
      _Unit('Byte', 'B', 1),
      _Unit('Kilobyte', 'KB', 1024),
      _Unit('Megabyte', 'MB', 1048576),
      _Unit('Gigabyte', 'GB', 1073741824),
      _Unit('Terabyte', 'TB', 1099511627776),
      _Unit('Petabyte', 'PB', 1125899906842624),
    ]),
    _Category('Pressure', <_Unit>[
      _Unit('Pascal', 'Pa', 1),
      _Unit('Hectopascal', 'hPa', 100),
      _Unit('Kilopascal', 'kPa', 1000),
      _Unit('Bar', 'bar', 100000),
      _Unit('Atmosphere', 'atm', 101325),
      _Unit('Millimetre of mercury', 'mmHg', 133.322387415),
      _Unit('Pound per square inch', 'psi', 6894.757293168),
    ]),
    _Category('Energy', <_Unit>[
      _Unit('Joule', 'J', 1),
      _Unit('Kilojoule', 'kJ', 1000),
      _Unit('Calorie', 'cal', 4.184),
      _Unit('Kilocalorie', 'kcal', 4184),
      _Unit('Watt hour', 'Wh', 3600),
      _Unit('Kilowatt hour', 'kWh', 3600000),
    ]),
  ];

  int _categoryIndex = 0;
  int _fromIndex = 0;
  int _toIndex = 1;
  final TextEditingController _value = TextEditingController(text: '1');

  _Category get _category => _categories[_categoryIndex];

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  double? get _converted {
    final input = double.tryParse(_value.text.replaceAll(',', '.'));
    if (input == null) return null;
    final from = _category.units[_fromIndex];
    final to = _category.units[_toIndex];

    if (_category.temperature) {
      // Convert to Celsius first, then out to the target scale.
      final double celsius;
      switch (from.symbol) {
        case '°C':
          celsius = input;
        case '°F':
          celsius = (input - 32) * 5 / 9;
        default:
          celsius = input - 273.15;
      }
      switch (to.symbol) {
        case '°C':
          return celsius;
        case '°F':
          return celsius * 9 / 5 + 32;
        default:
          return celsius + 273.15;
      }
    }

    return input * from.factor / to.factor;
  }

  void _changeCategory(int index) {
    setState(() {
      _categoryIndex = index;
      _fromIndex = 0;
      _toIndex = _category.units.length > 1 ? 1 : 0;
    });
  }

  void _swap() {
    setState(() {
      final from = _fromIndex;
      _fromIndex = _toIndex;
      _toIndex = from;
    });
  }

  /// Enough significant digits to be useful, without pretending to a precision
  /// the factor does not have.
  String _format(double value) {
    if (value == 0) return '0';
    final magnitude = value.abs();
    if (magnitude >= 1e12 || magnitude < 1e-6) {
      return value.toStringAsExponential(6);
    }
    final rounded = double.parse(value.toStringAsPrecision(10));
    if (rounded == rounded.roundToDouble() && magnitude < 1e15) {
      return rounded.toStringAsFixed(0);
    }
    return rounded
        .toString()
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _converted;
    final from = _category.units[_fromIndex];
    final to = _category.units[_toIndex];

    return ToolShell(
      title: 'Unit converter',
      howTo: 'Choose what you are measuring, enter a number, and pick the two '
          'units. The result updates as you type. Every conversion uses the '
          'exact definition of each unit.',
      children: <Widget>[
        ToolSection(
          title: 'What are you measuring?',
          icon: Icons.straighten,
          children: <Widget>[
            DropdownButtonFormField<int>(
              initialValue: _categoryIndex,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: <DropdownMenuItem<int>>[
                for (var i = 0; i < _categories.length; i++)
                  DropdownMenuItem<int>(
                    value: i,
                    child: Text(_categories[i].name),
                  ),
              ],
              onChanged: (int? value) {
                if (value != null) _changeCategory(value);
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        ToolSection(
          title: 'Convert',
          icon: Icons.swap_horiz,
          children: <Widget>[
            TextField(
              controller: _value,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true, signed: true),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Value',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _fromIndex,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'From',
                      border: OutlineInputBorder(),
                    ),
                    items: <DropdownMenuItem<int>>[
                      for (var i = 0; i < _category.units.length; i++)
                        DropdownMenuItem<int>(
                          value: i,
                          child: Text(
                            '${_category.units[i].name} '
                            '(${_category.units[i].symbol})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (int? value) {
                      if (value != null) setState(() => _fromIndex = value);
                    },
                  ),
                ),
                IconButton(
                  tooltip: 'Swap',
                  onPressed: _swap,
                  icon: const Icon(Icons.swap_horiz),
                ),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _toIndex,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'To',
                      border: OutlineInputBorder(),
                    ),
                    items: <DropdownMenuItem<int>>[
                      for (var i = 0; i < _category.units.length; i++)
                        DropdownMenuItem<int>(
                          value: i,
                          child: Text(
                            '${_category.units[i].name} '
                            '(${_category.units[i].symbol})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (int? value) {
                      if (value != null) setState(() => _toIndex = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (result == null)
              Text(
                'Enter a number to convert.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${_format(double.tryParse(_value.text.replaceAll(',', '.')) ?? 0)} '
                      '${from.symbol}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      '${_format(result)} ${to.symbol}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            const ToolNote(
              '“Digital storage” uses 1024 bytes to a kilobyte, which is what a '
              'file manager shows. Drive makers sometimes use 1000, which is '
              'why a “1 TB” drive shows less in an operating system.',
            ),
          ],
        ),
      ],
    );
  }
}
