/// The tools Max Tools ships with.
///
/// Every entry here is a working application: it has its own screen, it
/// explains itself on that screen, and it does something real. Nothing is
/// listed that is not implemented, and nothing that only works on one platform
/// pretends to work on another — each tool says so itself.
///
/// The previous catalog registered a hundred descriptors that mostly reshuffled
/// text through one generated form. This one is deliberately short.
library;

import 'package:flutter/material.dart';

import '../apps/api_tester_tool.dart';
import '../apps/colour_toolkit_tool.dart';
import '../apps/developer_toolkit_tool.dart';
import '../apps/disk_analyser_tool.dart';
import '../apps/duplicate_finder_tool.dart';
import '../apps/hash_tool.dart';
import '../apps/notes_tool.dart';
import '../apps/reading_aid_tool.dart';
import '../apps/security_scan_tool.dart';
import '../apps/text_toolkit_tool.dart';
import '../apps/unit_converter_tool.dart';
import '../apps/wealth_tool.dart';
import '../tool_descriptor.dart';
import '../tool_registry.dart';

/// A screen tool's runner. The browser and the palette open [screen] instead of
/// calling this, so it exists only so a programmatic caller gets an honest
/// answer rather than a crash.
Future<ToolResult> _opensScreen(Map<String, dynamic> arguments) async =>
    const ToolResult.success('This tool opens its own screen.');

/// Build the registry the application runs with.
ToolRegistry buildDefaultRegistry() {
  final registry = ToolRegistry();
  registry.registerAll(<ToolDescriptor>[
    ToolDescriptor(
      id: 'security.scan',
      name: 'Antivirus & scan',
      description: 'Check a folder with your system antivirus, or review it '
          'for disguised and hidden programs.',
      category: ToolCategory.security,
      icon: Icons.security,
      howTo: 'Choose a folder, then run your system antivirus or a quick '
          'pattern check.',
      tags: const <String>[
        'antivirus', 'virus', 'malware', 'scan', 'security', 'defender',
        'clamav', 'trojan', 'unsafe', 'check',
      ],
      synonyms: const <String>[
        'scan my computer for viruses',
        'is this file safe',
        'check for malware',
        'run an antivirus scan',
      ],
      run: _opensScreen,
      screen: (BuildContext context) => const SecurityScanTool(),
    ),
    ToolDescriptor(
      id: 'money.wealth',
      name: 'Wealth',
      description: 'Net worth, money in and out, budgets and three financial '
          'calculators, with charts.',
      category: ToolCategory.money,
      icon: Icons.savings_outlined,
      howTo: 'Record what you own and owe, then log money in and out to see '
          'where it goes.',
      tags: const <String>[
        'money', 'wealth', 'net worth', 'budget', 'savings', 'investment',
        'loan', 'interest', 'compound', 'finance', 'income', 'expense',
        'assets', 'liabilities', 'chart',
      ],
      synonyms: const <String>[
        'how much am i worth',
        'track my spending',
        'savings calculator',
        'compound interest',
        'loan repayment',
        'budget planner',
      ],
      run: _opensScreen,
      screen: (BuildContext context) => const WealthTool(),
    ),
    ToolDescriptor(
      id: 'developer.toolkit',
      name: 'Developer toolkit',
      description: 'Base64, URL, JSON, HTML entities, UUIDs, timestamps, '
          'regular expressions and CSV.',
      category: ToolCategory.developer,
      icon: Icons.terminal,
      howTo: 'Pick a task, paste the text, and read the result. Bad input is '
          'reported as an error.',
      tags: const <String>[
        'developer', 'base64', 'url', 'encode', 'decode', 'json', 'format',
        'minify', 'html', 'entities', 'uuid', 'timestamp', 'epoch', 'regex',
        'csv', 'convert', 'programmer',
      ],
      synonyms: const <String>[
        'encode base64',
        'decode base64',
        'format json',
        'pretty print json',
        'generate a uuid',
        'convert timestamp',
        'test a regular expression',
        'csv to json',
      ],
      run: _opensScreen,
      screen: (BuildContext context) => const DeveloperToolkitTool(),
    ),
    ToolDescriptor(
      id: 'file.checksum',
      name: 'Hash & checksum',
      description: 'Fingerprint text or a file and verify a published '
          'checksum.',
      category: ToolCategory.file,
      icon: Icons.fingerprint,
      howTo: 'Choose a file or type text, then paste the checksum a publisher '
          'listed to confirm the download is intact.',
      tags: const <String>[
        'hash', 'checksum', 'sha256', 'sha1', 'sha512', 'md5', 'digest',
        'verify', 'integrity', 'download', 'fingerprint', 'compare',
      ],
      synonyms: const <String>[
        'sha256 of this file',
        'verify a checksum',
        'check the download is complete',
        'hash some text',
      ],
      run: _opensScreen,
      screen: (BuildContext context) => const HashTool(),
    ),
    ToolDescriptor(
      id: 'everyday.units',
      name: 'Unit converter',
      description: 'Length, mass, temperature, area, volume, speed, time, '
          'storage, pressure and energy.',
      category: ToolCategory.everyday,
      icon: Icons.straighten,
      howTo: 'Choose what you are measuring, enter a number and pick the two '
          'units.',
      tags: const <String>[
        'unit', 'convert', 'converter', 'length', 'mass', 'weight',
        'temperature', 'celsius', 'fahrenheit', 'kelvin', 'area', 'volume',
        'speed', 'time', 'bytes', 'storage', 'pressure', 'energy', 'metric',
        'imperial',
      ],
      synonyms: const <String>[
        'convert centimetres to inches',
        'celsius to fahrenheit',
        'kilograms to pounds',
        'kilometres to miles',
        'megabytes to gigabytes',
      ],
      run: _opensScreen,
      screen: (BuildContext context) => const UnitConverterTool(),
    ),
    ToolDescriptor(
      id: 'documents.text',
      name: 'Text & documents',
      description: 'Word and character counts, case changes, tidy-up and find '
          'and replace.',
      category: ToolCategory.documents,
      icon: Icons.article_outlined,
      howTo: 'Paste your text; counts update as you type and the buttons '
          'reshape the whole text.',
      tags: const <String>[
        'text', 'word count', 'character count', 'case', 'uppercase',
        'lowercase', 'title case', 'sort lines', 'deduplicate', 'find',
        'replace', 'slug', 'documents', 'writing', 'essay', 'copy',
      ],
      synonyms: const <String>[
        'count the words',
        'how many characters',
        'make this uppercase',
        'sort these lines',
        'remove duplicate lines',
        'find and replace',
      ],
      run: _opensScreen,
      screen: (BuildContext context) => const TextToolkitTool(),
    ),
    ToolDescriptor(
      id: 'documents.notes',
      name: 'Notes',
      description: 'Write, search, pin and edit notes that stay on this '
          'device.',
      category: ToolCategory.documents,
      icon: Icons.sticky_note_2_outlined,
      howTo: 'Press Write a note. The first line becomes the title if you '
          'leave the title empty. Pin the notes you need often.',
      tags: const <String>[
        'note', 'notes', 'notepad', 'memo', 'write', 'writing', 'list',
        'todo', 'shopping', 'reminder', 'search', 'pin', 'journal', 'draft',
      ],
      synonyms: const <String>[
        'write a note',
        'keep a note',
        'notepad',
        'save a memo',
        'make a shopping list',
      ],
      run: _opensScreen,
      screen: (BuildContext context) => const NotesTool(),
    ),
    ToolDescriptor(
      id: 'documents.reading',
      name: 'Accessibility & reading',
      description: 'Measure how hard text is to read and reshape the page for '
          'comfortable reading.',
      category: ToolCategory.documents,
      icon: Icons.accessibility_new,
      howTo: 'Paste text to see its reading ease and grade, then adjust size, '
          'spacing and line length until the preview is comfortable.',
      tags: const <String>[
        'accessibility', 'reading', 'readability', 'flesch', 'dyslexia',
        'font size', 'line spacing', 'contrast', 'plain english', 'grade',
        'reading time', 'legibility', 'large text', 'easy read',
      ],
      synonyms: const <String>[
        'is this easy to read',
        'how readable is this',
        'make text easier to read',
        'reading level',
        'accessibility check',
        'dyslexia friendly text',
      ],
      run: _opensScreen,
      screen: (BuildContext context) => const ReadingAidTool(),
    ),
    ToolDescriptor(
      id: 'media.colour',
      name: 'Colour & design',
      description: 'Hex, RGB and HSL, WCAG readability checks and a palette '
          'built from one colour.',
      category: ToolCategory.media,
      icon: Icons.palette_outlined,
      howTo: 'Type a colour to see it in every notation; add a second colour '
          'to check contrast.',
      tags: const <String>[
        'colour', 'color', 'hex', 'rgb', 'hsl', 'palette', 'contrast',
        'accessibility', 'wcag', 'design', 'swatch', 'harmony', 'tint',
        'shade',
      ],
      synonyms: const <String>[
        'hex to rgb',
        'is this text readable',
        'check colour contrast',
        'make a colour palette',
      ],
      run: _opensScreen,
      screen: (BuildContext context) => const ColourToolkitTool(),
    ),
    ToolDescriptor(
      id: 'file.diskUsage',
      name: 'Disk analyser',
      description: 'Measure a folder and show which of its contents is using '
          'the space.',
      category: ToolCategory.file,
      icon: Icons.pie_chart_outline,
      howTo: 'Choose a folder and press Analyse. Its immediate contents are '
          'listed largest first, so the top line is where to look.',
      tags: const <String>[
        'disk', 'space', 'storage', 'size', 'folder', 'drive', 'full',
        'cleanup', 'analyse', 'analyze', 'usage', 'big files', 'largest',
      ],
      synonyms: const <String>[
        'what is taking up space',
        'why is my drive full',
        'which folder is biggest',
        'analyse disk usage',
      ],
      run: _opensScreen,
      screen: (BuildContext context) => const DiskAnalyserTool(),
    ),
    ToolDescriptor(
      id: 'file.duplicates',
      name: 'Duplicate finder',
      description: 'Find files with identical contents and show every copy of '
          'each.',
      category: ToolCategory.file,
      icon: Icons.content_copy_outlined,
      howTo: 'Choose a folder and press Find duplicates. Matching copies are '
          'grouped. Nothing is deleted here — you remove the extras yourself.',
      tags: const <String>[
        'duplicate', 'duplicates', 'copies', 'same file', 'wasted space',
        'cleanup', 'dedupe', 'tidy', 'storage', 'identical',
      ],
      synonyms: const <String>[
        'find duplicate files',
        'same file twice',
        'how much space am i wasting',
        'remove copies of the same file',
      ],
      run: _opensScreen,
      screen: (BuildContext context) => const DuplicateFinderTool(),
    ),
    ToolDescriptor(
      id: 'network.api',
      name: 'HTTP / API tester',
      description: 'Send one HTTP request and see the status, headers and body '
          'the server actually returned.',
      category: ToolCategory.network,
      icon: Icons.api,
      howTo: 'Choose a method, type the full address, add headers one per line '
          'and press Send. The response is shown unedited, with the time it '
          'took.',
      tags: const <String>[
        'http', 'api', 'request', 'rest', 'json', 'endpoint', 'get', 'post',
        'put', 'patch', 'delete', 'headers', 'status code', 'curl', 'webhook',
        'server', 'response',
      ],
      synonyms: const <String>[
        'test an api endpoint',
        'send a get request',
        'send a post request',
        'check what a server returns',
        'debug an http request',
      ],
      run: _opensScreen,
      screen: (BuildContext context) => const ApiTesterTool(),
    ),
  ]);
  return registry;
}
