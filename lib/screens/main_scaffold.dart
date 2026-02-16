import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:doable_todo_list_app/l10n/app_localizations.dart';
import 'package:doable_todo_list_app/screens/calendar_page.dart';
import 'package:doable_todo_list_app/screens/completed_tasks_page.dart';
import 'package:doable_todo_list_app/screens/home_page.dart';

/// 主框架：macOS 任务栏风格底部导航 + 右侧独立添加按钮
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  int _refreshTrigger = 0;
  late final PageController _pageController;
  void Function()? _calendarGoToToday;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _onAddTask() async {
    final saved = await Navigator.pushNamed(context, 'add_task');
    if (saved == true && mounted) {
      setState(() => _refreshTrigger++);
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      if (index == 1 || index == 2) _refreshTrigger++;
    });
  }

  void _onNavTap(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          HomePage(refreshTrigger: _refreshTrigger),
          CalendarPage(
            refreshTrigger: _refreshTrigger,
            onGoToTodayRequested: (goToToday) {
              _calendarGoToToday = goToToday;
            },
          ),
          CompletedTasksPage(refreshTrigger: _refreshTrigger),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // macOS 任务栏风格：毛玻璃圆角导航栏
            Expanded(
              child: _DockNavBar(
                currentIndex: _currentIndex,
                onTap: _onNavTap,
                onSettingsTap: () => Navigator.of(context).pushNamed('settings'),
                todayLabel: AppLocalizations.of(context)!.today,
                calendarLabel: AppLocalizations.of(context)!.calendar,
                completedLabel: AppLocalizations.of(context)!.completedTasks,
                settingsLabel: AppLocalizations.of(context)!.settings,
              ),
            ),
            const SizedBox(width: 12),
            // 日历页：定位按钮 + 添加按钮（上下排列）；其他页：仅添加按钮
            _RightButtons(
              currentIndex: _currentIndex,
              onAddTask: _onAddTask,
              onGoToToday: () {
                _calendarGoToToday?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// macOS 任务栏风格：毛玻璃、圆角药丸形、半透明
class _DockNavBar extends StatelessWidget {
  const _DockNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.onSettingsTap,
    required this.todayLabel,
    required this.calendarLabel,
    required this.completedLabel,
    required this.settingsLabel,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onSettingsTap;
  final String todayLabel;
  final String calendarLabel;
  final String completedLabel;
  final String settingsLabel;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.8),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NavItem(
                icon: _TodayIcon(),
                label: todayLabel,
                selected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: const Icon(Icons.calendar_month, size: 24),
                label: calendarLabel,
                selected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: const Icon(Icons.check_circle_outline, size: 24),
                label: completedLabel,
                selected: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _NavItem(
                icon: const Icon(Icons.settings, size: 24),
                label: settingsLabel,
                selected: false,
                onTap: onSettingsTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? Colors.black87 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 右侧按钮组：日历页显示定位+添加，其他页仅添加
class _RightButtons extends StatelessWidget {
  const _RightButtons({
    required this.currentIndex,
    required this.onAddTask,
    required this.onGoToToday,
  });

  final int currentIndex;
  final VoidCallback onAddTask;
  final VoidCallback onGoToToday;

  static const double _buttonSize = 56;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isCalendarPage = currentIndex == 1;

    if (isCalendarPage) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _CircleButton(
            size: _buttonSize,
            icon: Icons.my_location,
            tooltip: loc.goToToday,
            onPressed: onGoToToday,
            backgroundColor: Colors.white,
            iconColor: Colors.black87,
          ),
          const SizedBox(height: 12),
          _CircleButton(
            size: _buttonSize,
            icon: Icons.add,
            tooltip: loc.createTodo,
            onPressed: onAddTask,
            backgroundColor: Colors.black,
            iconColor: Colors.white,
          ),
        ],
      );
    }

    return _CircleButton(
      size: _buttonSize,
      icon: Icons.add,
      tooltip: loc.createTodo,
      onPressed: onAddTask,
      backgroundColor: Colors.black,
      iconColor: Colors.white,
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.size,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.backgroundColor,
    required this.iconColor,
  });

  final double size;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(size / 2),
          child: Tooltip(
            message: tooltip,
            child: Container(
              decoration: BoxDecoration(
                color: backgroundColor,
                shape: BoxShape.circle,
                border: backgroundColor == Colors.white
                    ? Border.all(color: Colors.grey.shade300)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: iconColor, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}

/// Today 图标：随当前日期变化，显示当天日期数字（类似日历格）
class _TodayIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final day = now.day;
    return SizedBox(
      width: 28,
      height: 28,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black87, width: 1.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            '$day',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
