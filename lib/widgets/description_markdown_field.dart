import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'package:doable_todo_list_app/l10n/app_localizations.dart';
import 'package:doable_todo_list_app/widgets/markdown_editor_sheet.dart'
    show MarkdownEditorSheet, MarkdownNewlineFormatter;

/// 任务描述输入区域：默认仅预览，点击编辑后显示编辑器
/// - 预览模式：Markdown 预览 + 编辑按钮
/// - 编辑模式：内联编辑器 + 全屏按钮（点击全屏后放大）
/// - 返回/完成时：保存并展示预览
class DescriptionMarkdownField extends StatefulWidget {
  const DescriptionMarkdownField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.onFullscreenChanged,
    this.flushRequested,
  });

  final TextEditingController controller;
  final String hintText;
  final VoidCallback? onChanged;
  /// 进入/退出全屏编辑时回调，用于父级隐藏保存按钮等
  final void Function(bool isFullscreen)? onFullscreenChanged;
  /// 父级保存前调用 notifyListeners()，以将内联未暂存内容同步到 controller
  final Listenable? flushRequested;

  @override
  State<DescriptionMarkdownField> createState() =>
      _DescriptionMarkdownFieldState();
}

class _DescriptionMarkdownFieldState extends State<DescriptionMarkdownField> {
  bool _isEditing = false;
  TextEditingController? _inlineController;

  @override
  void initState() {
    super.initState();
    widget.flushRequested?.addListener(_flushInlineToController);
  }

  @override
  void didUpdateWidget(DescriptionMarkdownField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flushRequested != widget.flushRequested) {
      oldWidget.flushRequested?.removeListener(_flushInlineToController);
      widget.flushRequested?.addListener(_flushInlineToController);
    }
  }

  @override
  void dispose() {
    widget.flushRequested?.removeListener(_flushInlineToController);
    _disposeInlineController();
    super.dispose();
  }

  void _flushInlineToController() {
    if (_inlineController != null) {
      widget.controller.text = _inlineController!.text;
      _disposeInlineController();
      if (mounted) setState(() => _isEditing = false);
      widget.onChanged?.call();
    }
  }

  void _ensureInlineController() {
    if (_inlineController == null) {
      _inlineController = TextEditingController(text: widget.controller.text);
    }
  }

  void _disposeInlineController() {
    _inlineController?.dispose();
    _inlineController = null;
  }

  Future<void> _openFullscreenEditor(BuildContext context) async {
    widget.onFullscreenChanged?.call(true);
    final initialText = _inlineController?.text ?? widget.controller.text;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.95,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: MarkdownEditorSheet(
          initialText: initialText,
          onSave: (text) {
            if (kDebugMode && text.isNotEmpty) {
              final hasTrailingSpaces = text.contains('  \n') || text.endsWith('  ');
              debugPrint('[MarkdownEditorSheet.onSave] 长度=${text.length}, '
                  '含行尾双空格=$hasTrailingSpaces');
            }
            widget.controller.text = text;
            widget.onChanged?.call();
          },
        ),
      ),
    );
    if (mounted) {
      widget.onFullscreenChanged?.call(false);
      _disposeInlineController();
      setState(() => _isEditing = false);
    }
  }

  void _exitEditAndSave() {
    if (_inlineController != null) {
      widget.controller.text = _inlineController!.text;
      _disposeInlineController();
    }
    setState(() => _isEditing = false);
    widget.onChanged?.call();
  }


  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildToolBar(),
                if (_isEditing) _buildInlineEditor() else _buildPreviewContent(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildToolBar() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.visibility, size: 20),
              tooltip: l10n.preview,
              onPressed: _exitEditAndSave,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 24),
              style: IconButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          const Spacer(),
          if (_isEditing)
            IconButton(
              icon: Icon(Icons.fullscreen, size: 18, color: Colors.blue.shade600),
              tooltip: l10n.fullscreenEdit,
              onPressed: () => _openFullscreenEditor(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 24),
              style: IconButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.edit, size: 18, color: Colors.blue.shade600),
              tooltip: l10n.edit,
              onPressed: () {
                _ensureInlineController();
                setState(() => _isEditing = true);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 24),
              style: IconButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInlineEditor() {
    _ensureInlineController();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _inlineController!,
        inputFormatters: [MarkdownNewlineFormatter()],
        decoration: InputDecoration(
          hintText: widget.hintText,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        maxLines: 6,
        minLines: 3,
        style: const TextStyle(fontSize: 14, height: 1.4),
      ),
    );
  }

  Widget _buildPreviewContent() {
    final text = widget.controller.text;
    return InkWell(
      onTap: () {
        _ensureInlineController();
        setState(() => _isEditing = true);
      },
      child: text.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Text(
                widget.hintText,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                  height: 1.4,
                ),
              ),
            )
          : Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
              ),
              child: MarkdownBody(
        data: text,
        styleSheet: MarkdownStyleSheet(
          p: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            height: 1.4,
          ),
          code: TextStyle(
            fontSize: 12,
            backgroundColor: Colors.grey.shade200,
          ),
        ),
      ),
    ),
    );
  }

}
