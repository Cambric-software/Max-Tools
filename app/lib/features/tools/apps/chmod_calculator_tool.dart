import 'package:flutter/material.dart';

import 'tool_shell.dart';

/// Converts between numeric (octal) and symbolic (rwx) file permissions.
///
/// Type 755 to see rwxr-xr-x, or tick the boxes to get the octal value.
/// Useful when writing Dockerfiles, CI configs or shell scripts.
class ChmodCalculatorTool extends StatefulWidget {
  const ChmodCalculatorTool({super.key});

  @override
  State<ChmodCalculatorTool> createState() => _ChmodCalculatorToolState();
}

class _ChmodCalculatorToolState extends State<ChmodCalculatorTool> {
  final TextEditingController _octal = TextEditingController(text: '755');
  bool _uR = true, _uW = true, _uX = true;
  bool _gR = true, _gW = false, _gX = true;
  bool _oR = true, _oW = false, _oX = true;
  String? _error;

  @override
  void dispose() {
    _octal.dispose();
    super.dispose();
  }

  int _bits(bool r, bool w, bool x) => (r ? 4 : 0) | (w ? 2 : 0) | (x ? 1 : 0);

  void _fromOctal() {
    final raw = _octal.text.trim();
    if (raw.isEmpty) return;
    final n = int.tryParse(raw, radix: 8);
    if (n == null || n < 0 || n > 0777) {
      setState(() => _error = 'Enter an octal value 0-777.');
      return;
    }
    setState(() {
      _error = null;
      _uR = (n & 0400) != 0;
      _uW = (n & 0200) != 0;
      _uX = (n & 0100) != 0;
      _gR = (n & 0040) != 0;
      _gW = (n & 0020) != 0;
      _gX = (n & 0010) != 0;
      _oR = (n & 0004) != 0;
      _oW = (n & 0002) != 0;
      _oX = (n & 0001) != 0;
    });
  }

  void _fromBoxes() {
    final n = (_bits(_uR, _uW, _uX) << 6) |
        (_bits(_gR, _gW, _gX) << 3) |
        _bits(_oR, _oW, _oX);
    setState(() {
      _error = null;
      _octal.text = n.toRadixString(8).padLeft(3, '0');
    });
  }

  String _symbolic() {
    String tri(bool r, bool w, bool x) =>
        '${r ? 'r' : '-'}${w ? 'w' : '-'}${x ? 'x' : '-'}';
    return 'rwxrwxrwx'.substring(0, 0) +
        tri(_uR, _uW, _uX) +
        tri(_gR, _gW, _gX) +
        tri(_oR, _oW, _oX);
  }

  Widget _row(String label, bool r, bool w, bool x, void Function(bool, bool, bool) set) {
    return Row(
      children: [
        SizedBox(width: 80, child: Text(label)),
        Checkbox(value: r, onChanged: (v) { set(v ?? false, w, x); _fromBoxes(); }),
        const Text('r'),
        Checkbox(value: w, onChanged: (v) { set(r, v ?? false, x); _fromBoxes(); }),
        const Text('w'),
        Checkbox(value: x, onChanged: (v) { set(r, w, v ?? false); _fromBoxes(); }),
        const Text('x'),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _fromOctal();
  }

  @override
  Widget build(BuildContext context) {
    return ToolShell(
      title: 'Chmod calculator',
      howTo: 'Type an octal mode (e.g. 755) or tick the permission boxes. '
          'The symbolic form (rwxr-xr-x) is shown below.',
      children: [
        TextField(
          controller: _octal,
          decoration: const InputDecoration(labelText: 'Octal mode'),
          onChanged: (_) => _fromOctal(),
        ),
        const SizedBox(height: 8),
        if (_error != null)
          Text(_error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        _row('Owner', _uR, _uW, _uX, (r, w, x) {
          _uR = r; _uW = w; _uX = x;
        }),
        _row('Group', _gR, _gW, _gX, (r, w, x) {
          _gR = r; _gW = w; _gX = x;
        }),
        _row('Other', _oR, _oW, _oX, (r, w, x) {
          _oR = r; _oW = w; _oX = x;
        }),
        const SizedBox(height: 8),
        Text('Symbolic: ${_symbolic()}',
            style: const TextStyle(fontFamily: 'monospace')),
        Text('Octal: ${_octal.text}',
            style: const TextStyle(fontFamily: 'monospace')),
      ],
    );
  }
}