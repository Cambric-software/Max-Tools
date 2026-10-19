import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'tool_shell.dart';

/// Sends one HTTP request and shows exactly what came back.
///
/// This is the tool for the moment when an API is misbehaving and the question
/// is "what did the server actually say?" — the status line, the headers, the
/// body and how long it took, unedited. Nothing is cached, retried or
/// interpreted: if the request fails, the failure is the result.
class ApiTesterTool extends StatefulWidget {
  /// Create the tool.
  const ApiTesterTool({super.key});

  @override
  State<ApiTesterTool> createState() => _ApiTesterToolState();
}

class _ApiTesterToolState extends State<ApiTesterTool> {
  static const List<String> _methods = <String>[
    'GET',
    'POST',
    'PUT',
    'PATCH',
    'DELETE',
    'HEAD',
  ];

  final TextEditingController _url =
      TextEditingController(text: 'https://example.com');
  final TextEditingController _headers = TextEditingController();
  final TextEditingController _body = TextEditingController();

  String _method = 'GET';
  bool _running = false;
  String? _error;

  int? _statusCode;
  String? _reason;
  Duration? _elapsed;
  Map<String, String> _responseHeaders = <String, String>{};
  String _responseBody = '';
  int _responseBytes = 0;
  bool _truncated = false;

  @override
  void dispose() {
    _url.dispose();
    _headers.dispose();
    _body.dispose();
    super.dispose();
  }

  bool get _hasBody => _method != 'GET' && _method != 'HEAD';

  /// Parse a header block of `Name: value` lines.
  ///
  /// Returns null and fills [error] when a line cannot be understood, rather
  /// than silently dropping a header the person believed they were sending.
  Map<String, String>? _parseHeaders(String raw, void Function(String) error) {
    final result = <String, String>{};
    for (final line in const LineSplitter().convert(raw)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final colon = trimmed.indexOf(':');
      if (colon <= 0) {
        error('Header "$trimmed" is missing its colon. Write it as '
            'Name: value.');
        return null;
      }
      final name = trimmed.substring(0, colon).trim();
      final value = trimmed.substring(colon + 1).trim();
      if (name.isEmpty) {
        error('A header has a value but no name: "$trimmed".');
        return null;
      }
      result[name] = value;
    }
    return result;
  }

  Future<void> _send() async {
    final rawUrl = _url.text.trim();
    final uri = Uri.tryParse(rawUrl);
    if (uri == null ||
        !uri.hasScheme ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty) {
      setState(() {
        _error = 'Enter a full address starting with http:// or https://.';
        _statusCode = null;
      });
      return;
    }

    String? headerError;
    final headers = _parseHeaders(
      _headers.text,
      (String message) => headerError = message,
    );
    if (headers == null) {
      setState(() => _error = headerError);
      return;
    }

    if (_hasBody && _body.text.isNotEmpty) {
      final hasContentType = headers.keys
          .any((String key) => key.toLowerCase() == 'content-type');
      if (!hasContentType) {
        headers['content-type'] = 'text/plain; charset=utf-8';
      }
    }

    final bodyBytes = _hasBody ? utf8.encode(_body.text) : <int>[];
    final request = http.Request(_method, uri)
      ..followRedirects = true
      ..headers.addAll(headers);
    if (_hasBody) request.bodyBytes = bodyBytes;

    setState(() {
      _running = true;
      _error = null;
      _statusCode = null;
      _reason = null;
      _elapsed = null;
      _responseHeaders = <String, String>{};
      _responseBody = '';
      _responseBytes = 0;
      _truncated = false;
    });

    final stopwatch = Stopwatch()..start();
    final client = http.Client();
    try {
      final streamed =
          await client.send(request).timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed).timeout(
        const Duration(seconds: 30),
      );
      stopwatch.stop();

      // A 5 MB ceiling keeps a stray download from freezing the app. The
      // status, the headers and the fact of truncation are still shown.
      const maxShown = 5 * 1024 * 1024;
      final bytes = response.bodyBytes;
      final cut = bytes.length > maxShown;
      final shown = cut ? bytes.sublist(0, maxShown) : bytes;

      if (!mounted) return;
      setState(() {
        _running = false;
        _statusCode = response.statusCode;
        _reason = response.reasonPhrase;
        _elapsed = stopwatch.elapsed;
        _responseHeaders = response.headers;
        _responseBytes = bytes.length;
        _truncated = cut;
        _responseBody = _decode(shown, response.headers);
      });
    } on TimeoutException {
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _running = false;
        _error = 'The request timed out after 30 seconds. The server did not '
            'answer.';
        _elapsed = stopwatch.elapsed;
      });
    } on Object catch (error) {
      stopwatch.stop();
      if (!mounted) return;
      // The message from the platform is the useful part: "Connection
      // refused", "Failed host lookup", a TLS failure. Show it verbatim.
      setState(() {
        _running = false;
        _error = 'The request could not be completed: $error';
        _elapsed = stopwatch.elapsed;
      });
    } finally {
      client.close();
    }
  }

  /// Decode the body using the charset the server declared when `dart:convert`
  /// knows it, falling back to UTF-8 with replacement so a mislabelled body is
  /// still shown rather than discarded.
  static String _decode(List<int> bytes, Map<String, String> headers) {
    var contentType = '';
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == 'content-type') {
        contentType = entry.value;
        break;
      }
    }
    final match = RegExp(r'charset=([^;]+)', caseSensitive: false)
        .firstMatch(contentType);
    final charset = match?.group(1)?.trim();
    if (charset != null && charset.isNotEmpty) {
      final encoding = Encoding.getByName(charset);
      if (encoding != null) {
        try {
          return encoding.decode(bytes);
        } on Object {
          // Fall through to the lossy UTF-8 decode.
        }
      }
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ToolShell(
      title: 'HTTP / API tester',
      howTo: 'Pick a method, enter the full address, add any headers one per '
          'line as “Name: value”, and press Send. The status line, the '
          'headers, the body and the time taken are shown exactly as the '
          'server returned them.',
      maxWidth: 980,
      children: <Widget>[
        ToolSection(
          title: 'Request',
          icon: Icons.send_outlined,
          children: <Widget>[
            Row(
              children: <Widget>[
                SizedBox(
                  width: 116,
                  child: DropdownButtonFormField<String>(
                    initialValue: _method,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Method',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: <DropdownMenuItem<String>>[
                      for (final method in _methods)
                        DropdownMenuItem<String>(
                          value: method,
                          child: Text(method),
                        ),
                    ],
                    onChanged: _running
                        ? null
                        : (String? value) {
                            if (value != null) setState(() => _method = value);
                          },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _url,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    onSubmitted: (_) => _running ? null : _send(),
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      hintText: 'https://api.example.com/things',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _headers,
              minLines: 2,
              maxLines: 6,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Headers (one per line)',
                hintText: 'Accept: application/json',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            if (_hasBody) ...<Widget>[
              const SizedBox(height: 12),
              TextField(
                controller: _body,
                minLines: 4,
                maxLines: 14,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Body',
                  hintText: '{"name": "value"}',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _running ? null : _send,
                  icon: const Icon(Icons.send),
                  label: const Text('Send'),
                ),
                if (_running) const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                OutlinedButton.icon(
                  onPressed: _running
                      ? null
                      : () => setState(() {
                            _headers.clear();
                            _body.clear();
                          }),
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear headers and body'),
                ),
              ],
            ),
            const ToolNote(
              'The request goes straight from this computer to the address '
              'you typed. Headers you add here can include secrets, so only '
              'send them to a server you trust, and remember that anything in '
              'this form is visible on screen.',
            ),
          ],
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: 16),
          ToolSection(
            title: 'The request failed',
            icon: Icons.error_outline,
            children: <Widget>[
              SelectableText(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              if (_elapsed != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Gave up after ${_elapsed!.inMilliseconds} ms.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ],
        if (_statusCode != null) ...<Widget>[
          const SizedBox(height: 16),
          ToolSection(
            title: 'Response',
            icon: Icons.receipt_long_outlined,
            children: <Widget>[
              Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        _statusCode! >= 200 && _statusCode! < 300
                            ? Icons.check_circle_outline
                            : Icons.warning_amber_outlined,
                        color: _statusCode! >= 200 && _statusCode! < 300
                            ? Colors.green.shade700
                            : Colors.orange.shade800,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$_statusCode ${_reason ?? ''}'.trim(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${_elapsed?.inMilliseconds ?? 0} ms',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    _responseBytes >= 1024
                        ? '${(_responseBytes / 1024).toStringAsFixed(1)} KB'
                        : '$_responseBytes bytes',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
              if (_truncated)
                const ToolNote(
                  'This response is larger than 5 MB. Only the first 5 MB is '
                  'shown; the size above is the whole response.',
                  warning: true,
                ),
              if (_responseHeaders.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                Text('Headers', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                for (final entry in _responseHeaders.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: SelectableText(
                      '${entry.key}: ${entry.value}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
              ],
              if (_responseBody.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                Text('Body', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 420),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _responseBody,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _responseBody));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Body copied.'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_all_outlined),
                    label: const Text('Copy the body'),
                  ),
                ),
              ] else if (_statusCode != null) ...<Widget>[
                const SizedBox(height: 14),
                Text(
                  'The server returned an empty body.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
