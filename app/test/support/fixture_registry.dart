/// A small registry of parameter-based tools, used as a fixture.
///
/// The shipped catalog is made of applications with their own screens. That is
/// the right shape for people, but a poor fixture for testing the machinery
/// underneath it: argument extraction, validation, the generated runner form
/// and the command palette all need tools that declare parameters.
///
/// These tools exist only in tests. Keeping them here means the parser and
/// palette can be tested properly without the product catalog having to carry
/// a hundred descriptors to support them.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:max_tools/tools/tool_descriptor.dart';
import 'package:max_tools/tools/tool_registry.dart';

/// Ordinary English the fixture vocabulary assumes a person knows, so the
/// corrector does not rewrite it into a tool word.
const List<String> kFixtureExtraWords = <String>[
  'the',
  'numeric',
  'ascending',
  'descending',
];

/// Build the fixture registry.
ToolRegistry buildFixtureRegistry() {
  final registry = ToolRegistry();
  registry.registerAll(<ToolDescriptor>[
    ToolDescriptor(
      id: 'data.csv.parse',
      name: 'Parse CSV',
      description: 'Split CSV text into rows.',
      category: ToolCategory.data,
      parameters: const <ToolParameter>[
        ToolParameter(name: 'text', description: 'CSV text', required: true),
        ToolParameter(
          name: 'useHeaders',
          description: 'Treat the first row as column names',
          defaultValue: false,
        ),
      ],
      tags: const <String>['csv', 'table', 'rows'],
      run: (Map<String, dynamic> args) async {
        final rows = '${args['text']}'
            .split('\n')
            .map((String row) => row.split(','))
            .toList();
        return ToolResult.success(rows);
      },
    ),
    ToolDescriptor(
      id: 'data.json.format',
      name: 'Format JSON',
      description: 'Pretty-print or minify JSON.',
      category: ToolCategory.data,
      parameters: const <ToolParameter>[
        ToolParameter(name: 'text', description: 'JSON text', required: true),
        ToolParameter(
          name: 'pretty',
          description: 'Indent the output',
          defaultValue: true,
        ),
      ],
      tags: const <String>['json'],
      synonyms: const <String>['pretty print json'],
      run: (Map<String, dynamic> args) async {
        try {
          final decoded = jsonDecode('${args['text']}');
          return ToolResult.success(
            args['pretty'] == true
                ? const JsonEncoder.withIndent('  ').convert(decoded)
                : jsonEncode(decoded),
          );
        } on FormatException catch (error) {
          return ToolResult.failure('Invalid JSON: ${error.message}');
        }
      },
    ),
    ToolDescriptor(
      id: 'data.json.inspect',
      name: 'Inspect JSON',
      description: 'Report the keys and the length of a JSON object.',
      category: ToolCategory.data,
      parameters: const <ToolParameter>[
        ToolParameter(name: 'text', description: 'JSON text', required: true),
      ],
      tags: const <String>['json', 'keys'],
      run: (Map<String, dynamic> args) async {
        final decoded = jsonDecode('${args['text']}');
        if (decoded is! Map) {
          return const ToolResult.failure('Not a JSON object.');
        }
        return ToolResult.success(<String, dynamic>{
          'keys': decoded.keys.toList(),
          'length': decoded.length,
        });
      },
    ),
    ToolDescriptor(
      id: 'security.hash',
      name: 'Hash Text',
      description: 'Hash text with a chosen algorithm.',
      category: ToolCategory.security,
      parameters: const <ToolParameter>[
        ToolParameter(name: 'text', description: 'Text to hash', required: true),
        ToolParameter(
          name: 'algorithm',
          description: 'sha256, sha1 or md5',
          defaultValue: 'sha256',
        ),
      ],
      tags: const <String>['hash', 'sha256', 'md5', 'password'],
      synonyms: const <String>['hash my password'],
      run: (Map<String, dynamic> args) async {
        final bytes = utf8.encode('${args['text']}');
        final algorithm = '${args['algorithm']}';
        if (algorithm == 'hmacSha256') {
          return const ToolResult.failure(
            'hmacSha256 needs a secret, and none was given.',
          );
        }
        if (!const <String>['sha256', 'sha1', 'md5'].contains(algorithm)) {
          return ToolResult.failure(
            'Unknown algorithm "$algorithm". Use sha256, sha1 or md5.',
          );
        }
        return ToolResult.success(
          switch (algorithm) {
            'md5' => md5.convert(bytes).toString(),
            'sha1' => sha1.convert(bytes).toString(),
            _ => sha256.convert(bytes).toString(),
          },
        );
      },
    ),
    ToolDescriptor(
      id: 'files.humanSize',
      name: 'Human Size',
      description: 'Format a byte count so a person can read it.',
      category: ToolCategory.file,
      parameters: const <ToolParameter>[
        ToolParameter(
          name: 'bytes',
          description: 'Number of bytes',
          defaultValue: 0,
        ),
      ],
      tags: const <String>['size', 'bytes'],
      run: (_) async => const ToolResult.success('1.0 KB'),
    ),
    ToolDescriptor(
      id: 'files.checksum',
      name: 'File Checksum',
      description: 'Report the checksum of a file on disk.',
      category: ToolCategory.file,
      parameters: const <ToolParameter>[
        ToolParameter(name: 'path', description: 'Path to the file', required: true),
      ],
      tags: const <String>['checksum', 'integrity'],
      run: (Map<String, dynamic> args) async {
        final file = File('${args['path']}');
        if (!file.existsSync()) {
          return ToolResult.failure('File not found: ${args['path']}');
        }
        return ToolResult.success(
          sha256.convert(file.readAsBytesSync()).toString(),
        );
      },
    ),
    ToolDescriptor(
      id: 'files.list',
      name: 'List Files',
      description: 'List the files in a folder.',
      category: ToolCategory.file,
      tags: const <String>['list'],
      run: (_) async => const ToolResult.success('listed'),
    ),
    ToolDescriptor(
      id: 'text.pad',
      name: 'Pad Text',
      description: 'Pad text to a given width.',
      category: ToolCategory.documents,
      parameters: const <ToolParameter>[
        ToolParameter(name: 'text', description: 'Text to pad', required: true),
        ToolParameter(
          name: 'width',
          description: 'Target width',
          defaultValue: 0,
        ),
      ],
      tags: const <String>['pad', 'width'],
      run: (_) async => const ToolResult.success('padded'),
    ),
    ToolDescriptor(
      id: 'text.sortLines',
      name: 'Sort Lines',
      description: 'Sort the lines of a block of text.',
      category: ToolCategory.documents,
      parameters: const <ToolParameter>[
        ToolParameter(name: 'text', description: 'Text to sort', required: true),
        ToolParameter(
          name: 'numeric',
          description: 'Sort numerically rather than alphabetically',
          defaultValue: false,
        ),
        ToolParameter(
          name: 'order',
          description: 'ascending or descending',
          defaultValue: 'ascending',
        ),
      ],
      tags: const <String>['sort', 'lines'],
      run: (_) async => const ToolResult.success('sorted'),
    ),
  ]);
  return registry;
}
