/// First catalog batch: developer tools that wrap the service library.
///
/// Every wrapper here calls an existing, tested service — the catalog only
/// adapts signatures and maps arguments. That keeps tool behaviour identical
/// to the underlying service and makes both sides testable.
library;

import 'dart:io';

import '../../tools/library/data/csv_service.dart';
import '../../tools/library/data/json_service.dart';
import '../../tools/library/files/checksum_service.dart';
import '../../tools/library/security/hash_service.dart';
import '../tool_descriptor.dart';

/// Tools for developers: text, data and integrity helpers.
List<ToolDescriptor> developerTools() => <ToolDescriptor>[
      // ── Data ────────────────────────────────────────────────────────────
      ToolDescriptor(
        id: 'data.csv.parse',
        name: 'Parse CSV',
        description: 'Parse CSV text into rows, optionally keyed by the header row.',
        category: ToolCategory.developer,
        tags: <String>['csv', 'table', 'rows', 'delimited'],
        synonyms: <String>['read csv', 'csv to rows', 'parse table'],
        parameters: <ToolParameter>[
          const ToolParameter(
            name: 'text',
            description: 'The CSV text to parse.',
            required: true,
          ),
          const ToolParameter(
            name: 'useHeaders',
            description: 'Key each row by the first row of headers.',
            defaultValue: false,
          ),
        ],
        run: (args) async {
          const service = CsvService();
          final rows = args['useHeaders'] == true
              ? service.parseWithHeaders(args['text'] as String)
              : service.parse(args['text'] as String);
          return ToolResult.success(rows);
        },
      ),
      ToolDescriptor(
        id: 'data.csv.encode',
        name: 'Build CSV',
        description: 'Join rows back into CSV text.',
        category: ToolCategory.developer,
        tags: <String>['csv', 'table', 'export'],
        synonyms: <String>['make csv', 'rows to csv'],
        parameters: <ToolParameter>[
          const ToolParameter(
            name: 'rows',
            description: 'Rows to encode, each a list of cell values.',
            required: true,
          ),
        ],
        run: (args) async {
          final rows = (args['rows'] as List<dynamic>)
              .map((row) => (row as List<dynamic>).map((c) => '$c').toList())
              .toList();
          return ToolResult.success(const CsvService().encode(rows));
        },
      ),
      ToolDescriptor(
        id: 'data.json.format',
        name: 'Format JSON',
        description: 'Pretty-print or minify JSON text.',
        category: ToolCategory.developer,
        tags: <String>['json', 'pretty', 'minify', 'format'],
        synonyms: <String>['pretty print json', 'beautify json', 'minify json'],
        parameters: <ToolParameter>[
          const ToolParameter(
            name: 'text',
            description: 'The JSON text to reformat.',
            required: true,
          ),
          const ToolParameter(
            name: 'pretty',
            description: 'Pretty-print when true, minify when false.',
            defaultValue: true,
          ),
        ],
        run: (args) async {
          try {
            final value = JsonService().decode(args['text'] as String);
            final output = JsonService()
                .encode(value, pretty: args['pretty'] != false);
            return ToolResult.success(output);
          } on FormatException catch (error) {
            return ToolResult.failure('Invalid JSON: ${error.message}');
          }
        },
      ),
      ToolDescriptor(
        id: 'data.json.inspect',
        name: 'Inspect JSON',
        description: 'Report the shape of JSON: type, keys and array length.',
        category: ToolCategory.developer,
        tags: <String>['json', 'inspect', 'structure'],
        synonyms: <String>['what is in this json', 'json shape'],
        parameters: <ToolParameter>[
          const ToolParameter(
            name: 'text',
            description: 'The JSON text to inspect.',
            required: true,
          ),
        ],
        run: (args) async {
          try {
            final value = JsonService().decode(args['text'] as String);
            final summary = <String, dynamic>{
              'type': value.runtimeType.toString(),
              if (value is Map)
                'keys': value.keys.map((key) => '$key').toList(),
              'length': switch (value) {
                final Map<dynamic, dynamic> map => map.length,
                final List<dynamic> list => list.length,
                _ => 0,
              },
            };
            return ToolResult.success(summary);
          } on FormatException catch (error) {
            return ToolResult.failure('Invalid JSON: ${error.message}');
          }
        },
      ),

      // ── Security / integrity ────────────────────────────────────────────
      ToolDescriptor(
        id: 'security.hash',
        name: 'Hash Text',
        description: 'Hash text with SHA-256, MD5 or HMAC-SHA256.',
        category: ToolCategory.security,
        tags: <String>['hash', 'sha256', 'md5', 'hmac', 'digest'],
        synonyms: <String>['checksum text', 'sha256 of string'],
        parameters: <ToolParameter>[
          const ToolParameter(
            name: 'text',
            description: 'The text to hash.',
            required: true,
          ),
          const ToolParameter(
            name: 'algorithm',
            description: 'One of: sha256, md5, hmacSha256.',
            defaultValue: 'sha256',
          ),
          const ToolParameter(
            name: 'secret',
            description: 'Secret key, required for hmacSha256.',
          ),
        ],
        run: (args) async {
          final service = HashService();
          final algorithm = (args['algorithm'] as String? ?? 'sha256').toLowerCase();
          final text = args['text'] as String;
          switch (algorithm) {
            case 'sha256':
              return ToolResult.success(service.sha256(text));
            case 'md5':
              return ToolResult.success(service.md5(text));
            case 'hmacsha256':
            case 'hmac':
              final secret = args['secret'];
              if (secret == null || '$secret'.isEmpty) {
                return const ToolResult.failure(
                  'hmacSha256 needs a "secret" parameter.',
                );
              }
              return ToolResult.success(service.hmacSha256(text, '$secret'));
            default:
              return ToolResult.failure(
                'Unknown algorithm "$algorithm". Use sha256, md5 or hmacSha256.',
              );
          }
        },
      ),
      ToolDescriptor(
        id: 'security.verifyTextHash',
        name: 'Verify Text Hash',
        description: 'Check whether text matches an expected hash.',
        category: ToolCategory.security,
        tags: <String>['verify', 'hash', 'integrity'],
        synonyms: <String>['check hash matches'],
        parameters: <ToolParameter>[
          const ToolParameter(
            name: 'text',
            description: 'The text to verify.',
            required: true,
          ),
          const ToolParameter(
            name: 'expected',
            description: 'The expected hash.',
            required: true,
          ),
        ],
        run: (args) async {
          final matches = HashService().verify(
            args['text'] as String,
            args['expected'] as String,
          );
          return ToolResult.success(<String, bool>{'matches': matches});
        },
      ),
      ToolDescriptor(
        id: 'files.checksum',
        name: 'File Checksum',
        description: 'Compute the SHA-256 checksum of a file.',
        category: ToolCategory.file,
        tags: <String>['checksum', 'sha256', 'file', 'integrity'],
        synonyms: <String>['hash a file', 'file integrity'],
        parameters: <ToolParameter>[
          const ToolParameter(
            name: 'path',
            description: 'Absolute or working-directory-relative file path.',
            required: true,
          ),
        ],
        run: (args) async {
          final file = File(args['path'] as String);
          if (!await file.exists()) {
            return ToolResult.failure('File not found: ${file.path}');
          }
          try {
            return ToolResult.success(await ChecksumService().sha256File(file));
          } on FileSystemException catch (error) {
            return ToolResult.failure('Could not read file: ${error.message}');
          }
        },
      ),
      ToolDescriptor(
        id: 'files.verifyChecksum',
        name: 'Verify File Checksum',
        description: 'Check whether a file matches an expected SHA-256 checksum.',
        category: ToolCategory.file,
        tags: <String>['verify', 'checksum', 'file', 'integrity'],
        synonyms: <String>['verify file hash', 'file integrity check'],
        parameters: <ToolParameter>[
          const ToolParameter(
            name: 'path',
            description: 'Path of the file to verify.',
            required: true,
          ),
          const ToolParameter(
            name: 'expected',
            description: 'The expected SHA-256 checksum.',
            required: true,
          ),
        ],
        run: (args) async {
          final file = File(args['path'] as String);
          if (!await file.exists()) {
            return ToolResult.failure('File not found: ${file.path}');
          }
          final matches =
              await ChecksumService().verifyFile(file, args['expected'] as String);
          return ToolResult.success(<String, bool>{'matches': matches});
        },
      ),
    ];
