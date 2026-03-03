import 'package:flutter/material.dart';

/// 纯文本描述输入框（不包含 Markdown 预览/全屏编辑功能）。
///
/// 保留了 `onFullscreenChanged` 和 `flushRequested` 参数用于兼容旧调用，
/// 但在当前实现中不会使用。
class DescriptionField extends StatelessWidget {
  const DescriptionField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.flushRequested,
  });

  final TextEditingController controller;
  final String hintText;
  final VoidCallback? onChanged;
  final Listenable? flushRequested;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        onChanged: (_) => onChanged?.call(),
        maxLines: 6,
        minLines: 3,
        decoration: InputDecoration(
          hintText: hintText,
          contentPadding: const EdgeInsets.all(12),
          border: InputBorder.none,
        ),
        style: const TextStyle(fontSize: 14, height: 1.4),
      ),
    );
  }
}
