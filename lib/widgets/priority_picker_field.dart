import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/task_entity.dart';
import '../utils/priority_utils.dart';

/// 优先级选择器：红、黄、蓝、白
class PriorityPickerField extends StatelessWidget {
  const PriorityPickerField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final TaskPriority value;
  final ValueChanged<TaskPriority> onChanged;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Row(
      children: [
        _buildChip(context, TaskPriority.red, loc.priorityRed, onChanged, value),
        const SizedBox(width: 8),
        _buildChip(context, TaskPriority.yellow, loc.priorityYellow, onChanged, value),
        const SizedBox(width: 8),
        _buildChip(context, TaskPriority.blue, loc.priorityBlue, onChanged, value),
        const SizedBox(width: 8),
        _buildChip(context, TaskPriority.white, loc.priorityWhite, onChanged, value),
      ],
    );
  }

  Widget _buildChip(
    BuildContext context,
    TaskPriority p,
    String label,
    ValueChanged<TaskPriority> onChanged,
    TaskPriority current,
  ) {
    final selected = current == p;
    final color = PriorityUtils.colorOf(p);
    return Expanded(
      child: Material(
        color: selected ? color : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 0 : 1,
          ),
        ),
        child: InkWell(
          onTap: () => onChanged(p),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
