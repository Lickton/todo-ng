import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:doable_todo_list_app/l10n/app_localizations.dart';

/// 换行时自动在行尾添加两个空格（Markdown 软换行）
class MarkdownNewlineFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length != oldValue.text.length + 1) {
      return newValue;
    }
    int diffIndex = 0;
    while (diffIndex < oldValue.text.length &&
        diffIndex < newValue.text.length &&
        oldValue.text[diffIndex] == newValue.text[diffIndex]) {
      diffIndex++;
    }
    if (diffIndex < newValue.text.length && newValue.text[diffIndex] == '\n') {
      final newText =
          '${newValue.text.substring(0, diffIndex)}  \n${newValue.text.substring(diffIndex + 1)}';
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: diffIndex + 3),
      );
    }
    return newValue;
  }
}

class MarkdownEditorSheet extends StatefulWidget {
  final String initialText;
  final void Function(String) onSave;

  const MarkdownEditorSheet({
    super.key,
    required this.initialText,
    required this.onSave,
  });

  @override
  State<MarkdownEditorSheet> createState() => _MarkdownEditorSheetState();
}

class _MarkdownEditorSheetState extends State<MarkdownEditorSheet> {
  late TextEditingController _controller;
  bool _isPreviewMode = false;
  Timer? _autoSaveTimer;

  static const String _draftKey = 'markdown_draft';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _controller.addListener(_onTextChanged);
    _loadDraftIfNeeded();
  }

  Future<void> _loadDraftIfNeeded() async {
    if (widget.initialText.isNotEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final draft = prefs.getString(_draftKey);
    if (draft == null || draft.isEmpty) return;

    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final shouldLoad = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.draftFound),
        content: Text(l10n.draftLoadPrompt),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.ignore),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.load),
          ),
        ],
      ),
    );
    if (shouldLoad == true && mounted) {
      _controller.text = draft;
    }
  }

  void _onTextChanged() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), _saveDraft);
    setState(() {});
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftKey, _controller.text);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _autoSaveTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.editDescription),
        actions: [
          IconButton(
            icon: Icon(_isPreviewMode ? Icons.edit : Icons.visibility),
            tooltip: _isPreviewMode ? l10n.edit : l10n.preview,
            onPressed: () {
              setState(() => _isPreviewMode = !_isPreviewMode);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_isPreviewMode) _buildMarkdownToolbar(l10n),
          Expanded(
            child: _isPreviewMode ? _buildPreview(l10n) : _buildEditor(l10n),
          ),
          _buildCharacterCount(l10n),
          _buildSaveButton(l10n),
        ],
      ),
    );
  }

  Widget _buildMarkdownToolbar(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _toolbarButton(
              icon: Icons.format_bold,
              tooltip: l10n.markdownHintBold,
              onPressed: () => _insertMarkdown('**', '**'),
            ),
            _toolbarButton(
              icon: Icons.format_italic,
              tooltip: l10n.markdownHintItalic,
              onPressed: () => _insertMarkdown('*', '*'),
            ),
            _toolbarButton(
              icon: Icons.format_strikethrough,
              tooltip: l10n.markdownHintStrikethrough,
              onPressed: () => _insertMarkdown('~~', '~~'),
            ),
            VerticalDivider(width: 1, color: Colors.grey.shade400),
            _toolbarButton(
              icon: Icons.title,
              tooltip: l10n.markdownHintHeading,
              onPressed: () => _insertMarkdown('# ', ''),
            ),
            _toolbarButton(
              icon: Icons.format_quote,
              tooltip: l10n.markdownHintQuote,
              onPressed: () => _insertMarkdown('> ', ''),
            ),
            _toolbarButton(
              icon: Icons.code,
              tooltip: l10n.markdownHintCode,
              onPressed: () => _insertMarkdown('`', '`'),
            ),
            VerticalDivider(width: 1, color: Colors.grey.shade400),
            _toolbarButton(
              icon: Icons.format_list_bulleted,
              tooltip: l10n.markdownHintList,
              onPressed: () => _insertMarkdown('- ', ''),
            ),
            _toolbarButton(
              icon: Icons.format_list_numbered,
              tooltip: l10n.markdownHintOrderedList,
              onPressed: () => _insertMarkdown('1. ', ''),
            ),
            _toolbarButton(
              icon: Icons.check_box,
              tooltip: l10n.markdownHintTask,
              onPressed: () => _insertMarkdown('- [ ] ', ''),
            ),
            VerticalDivider(width: 1, color: Colors.grey.shade400),
            _toolbarButton(
              icon: Icons.table_chart,
              tooltip: l10n.markdownHintTable,
              onPressed: _insertTable,
            ),
            VerticalDivider(width: 1, color: Colors.grey.shade400),
            _toolbarButton(
              icon: Icons.link,
              tooltip: l10n.markdownHintLink,
              onPressed: () => _insertMarkdown('[', '](url)'),
            ),
            _toolbarButton(
              icon: Icons.image,
              tooltip: l10n.markdownHintImage,
              onPressed: () => _insertMarkdown('![', '](url)'),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              tooltip: l10n.insertTemplate,
              onSelected: _insertTemplate,
              itemBuilder: (ctx) => [
                PopupMenuItem(value: 'meeting_notes', child: Text(l10n.meetingNotes)),
                PopupMenuItem(value: 'todo_list', child: Text(l10n.todoList)),
                PopupMenuItem(value: 'daily_log', child: Text(l10n.dailyLog)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(),
    );
  }

  void _insertMarkdown(String before, String after) {
    final text = _controller.text;
    final selection = _controller.selection;

    if (selection.start == -1) {
      _controller.text = text + before + after;
      _controller.selection = TextSelection.collapsed(
        offset: text.length + before.length,
      );
    } else {
      final selectedText = text.substring(selection.start, selection.end);
      final newText = text.substring(0, selection.start) +
          before +
          selectedText +
          after +
          text.substring(selection.end);

      _controller.text = newText;
      _controller.selection = TextSelection.collapsed(
        offset: selection.start + before.length + selectedText.length,
      );
    }
  }

  void _insertTable() {
    const table = '''
| 列1 | 列2 | 列3 |
|-----|-----|-----|
| 内容 | 内容 | 内容 |
| 内容 | 内容 | 内容 |
''';
    final text = _controller.text;
    final selection = _controller.selection;
    _controller.text =
        text.substring(0, selection.start) + table + text.substring(selection.end);
  }

  void _insertTemplate(String template) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    String text;
    switch (template) {
      case 'meeting_notes':
        text = l10n.templateMeetingNotes(
            DateTime.now().toString().substring(0, 16));
        break;
      case 'todo_list':
        text = l10n.templateTodoList;
        break;
      case 'daily_log':
        text = l10n.templateDailyLog(
            DateTime.now().toString().substring(0, 10));
        break;
      default:
        return;
    }
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
  }

  Widget _buildEditor(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
          controller: _controller,
          inputFormatters: [MarkdownNewlineFormatter()],
          decoration: InputDecoration(
            hintText: l10n.markdownHintPlaceholder,
            border: InputBorder.none,
          ),
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
    );
  }

  Widget _buildPreview(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: MarkdownBody(
          data: _controller.text.isEmpty
              ? l10n.previewEmpty
              : _controller.text,
          selectable: true,
          styleSheet: MarkdownStyleSheet(
            h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            h3: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            p: TextStyle(fontSize: 16, height: 1.5, color: Colors.grey.shade800),
            code: TextStyle(
              backgroundColor: Colors.grey.shade200,
              fontFamily: 'monospace',
            ),
            codeblockDecoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCharacterCount(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(8),
      alignment: Alignment.centerRight,
      child: Text(
        l10n.characterCount(_controller.text.length),
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
    );
  }

  Widget _buildSaveButton(AppLocalizations l10n) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: () async {
              widget.onSave(_controller.text);
              final navigator = Navigator.of(context);
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove(_draftKey);
              if (mounted) navigator.pop();
            },
            child: Text(l10n.saveDraft),
          ),
        ),
      ),
    );
  }
}
