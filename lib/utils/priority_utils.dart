import 'package:flutter/material.dart';

import '../models/task_entity.dart';

/// 优先级颜色：红、黄、蓝、白
class PriorityUtils {
  static Color colorOf(TaskPriority p) {
    switch (p) {
      case TaskPriority.red:
        return const Color(0xFFEF4444); // red-500
      case TaskPriority.yellow:
        return const Color(0xFFEAB308); // yellow-500
      case TaskPriority.blue:
        return const Color(0xFF3B82F6); // blue-500
      case TaskPriority.white:
        return const Color(0xFFE5E7EB); // gray-200
    }
  }

  /// 排序权重：红最高(0)，白最低(3)
  static int sortOrder(TaskPriority p) {
    switch (p) {
      case TaskPriority.red: return 0;
      case TaskPriority.yellow: return 1;
      case TaskPriority.blue: return 2;
      case TaskPriority.white: return 3;
    }
  }
}
