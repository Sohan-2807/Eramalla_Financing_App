import 'package:flutter/material.dart';
import 'dashboard_view.dart';
import 'customers_view.dart';
import 'collections_view.dart';
import 'reports_view.dart';
import 'settings_view.dart';

class NavigationShell extends StatefulWidget {
  const NavigationShell({super.key});
  @override
  State<NavigationShell> createState() => NavigationShellState();
}

// Public state so dashboard can call goTo(index)
class NavigationShellState extends State<NavigationShell> {
  int _idx = 0;

  void goTo(int index) => setState(() => _idx = index);

  static const _pages = [
    DashboardView(),
    CustomersView(),
    CollectionsView(),
    ReportsView(),
    SettingsView(),
  ];

  static const _items = [
    _NavItem(Icons.grid_view_rounded, Icons.grid_view_rounded, 'Home'),
    _NavItem(Icons.people_alt_outlined, Icons.people_alt, 'Customers'),
    _NavItem(Icons.payments_outlined, Icons.payments_rounded, 'Collections'),
    _NavItem(Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Reports'),
    _NavItem(Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _idx, children: _pages),
      bottomNavigationBar: _BottomNav(
        selectedIndex: _idx,
        onTap: goTo,
        items: _items,
      ),
    );
  }
}

class _NavItem {
  final IconData icon, activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}

class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final List<_NavItem> items;
  const _BottomNav(
      {required this.selectedIndex,
        required this.onTap,
        required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1621),
        border: const Border(top: BorderSide(color: Color(0xFF1A2540))),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, -4))
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(items.length, (i) {
              final item = items[i];
              final sel = i == selectedIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                        child: Icon(
                          sel ? item.activeIcon : item.icon,
                          key: ValueKey(sel),
                          color: sel
                              ? const Color(0xFF00E5A0)
                              : const Color(0xFF3D4F6B),
                          size: sel ? 24 : 22,
                        ),
                      ),
                      const SizedBox(height: 3),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          color: sel
                              ? const Color(0xFF00E5A0)
                              : const Color(0xFF3D4F6B),
                          fontSize: sel ? 10 : 9.5,
                          fontWeight: sel
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                        child: Text(item.label),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutBack,
                        height: 3,
                        width: sel ? 22 : 0,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5A0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
