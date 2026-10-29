import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'tool_shell.dart';

/// A Markdown editor with a live preview.
///
/// Write on the left, read on the right. Useful for README files, notes,
/// documentation and anything else that is written once and read many times.
class MarkdownEditorTool extends StatefulWidget {
  const MarkdownEditorTool({super.key});

  @override
  State<MarkdownEditorTool> createState() => _MarkdownEditorToolState();
}

class _MarkdownEditorToolState extends State<MarkdownEditorTool> {
  final TextEditingController _controller = TextEditingController(text:
      '# Title\n\nWrite **bold**, *italic*, `code`, and lists:\n\n- item one\n- item two\n\n> a quote\n');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ToolShell(
      title: 'Markdown editor',
      howTo: 'Write Markdown on the left. The preview on the right updates as '
          'you type. Copy the source or export it when you are done.',
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(labelText: 'Markdown source'),
                  maxLines: null,
                  expands: true,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Markdown(
                    data: _controller.text,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}