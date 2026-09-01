import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'members_screen.dart';
import 'leads_screen.dart';
import 'diet_screen.dart';
import 'plans_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'subscription_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.dashboard_rounded,      label: 'Home'),
    _NavItem(icon: Icons.people_alt_rounded,      label: 'Members'),
    _NavItem(icon: Icons.person_add_alt_1_rounded, label: 'Leads'),
    _NavItem(icon: Icons.restaurant_menu_rounded,  label: 'Diet Plans'),
    _NavItem(icon: Icons.card_membership_rounded,  label: 'Plans'),
    _NavItem(icon: Icons.bar_chart_rounded,        label: 'Reports'),
    _NavItem(icon: Icons.settings_rounded,         label: 'Settings'),
    _NavItem(icon: Icons.verified_rounded,         label: 'Subscription'),
  ];

  final List<Widget> _screens = const [
    DashboardScreen(),
    MembersScreen(),
    LeadsScreen(),
    DietScreen(),
    PlansScreen(),
    ReportsScreen(),
    SettingsScreen(),
    SubscriptionScreen(),
  ];

  void _onMenuSelected(int index) {
    setState(() => _currentIndex = index);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor  = isDark ? AppTheme.darkSurface  : AppTheme.lightSurface;
    final bg2Color = isDark ? AppTheme.darkBg        : AppTheme.lightBg;
    final txtPrimary   = isDark ? AppTheme.darkTextPrimary   : AppTheme.lightTextPrimary;
    final txtSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final borderColor  = isDark ? AppTheme.darkBorder        : AppTheme.lightBorder;

    return Scaffold(
      backgroundColor: bg2Color,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurfaceAlt : AppTheme.lightSurfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Icon(Icons.menu_rounded, size: 20, color: txtPrimary),
            ),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.fitness_center_rounded, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Text(
              _navItems[_currentIndex].label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          // Pro Plan badge
          GestureDetector(
            onTap: () => setState(() => _currentIndex = 7),
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: AppTheme.accentGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 3),
                  Text(
                    'PRO',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurfaceAlt : AppTheme.lightSurfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Icon(Icons.notifications_none_rounded, size: 20, color: txtPrimary),
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),

      // ── Premium Drawer ──
      drawer: Drawer(
        width: MediaQuery.of(context).size.width * 0.82,
        backgroundColor: bgColor,
        child: Column(
          children: [
            // ── Gradient Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
              decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2.5),
                    ),
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      child: const Icon(Icons.fitness_center_rounded, size: 30, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'FitnexGym',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Gym Management Pro',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => _onMenuSelected(7),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: AppTheme.success, size: 7),
                          SizedBox(width: 6),
                          Text(
                            'Active Plan • View Details →',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Menu Items ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  _drawerSection('MAIN'),
                  _drawerItem(context, Icons.dashboard_rounded, 'Home', 0, isDark, txtPrimary, txtSecondary),
                  _drawerItem(context, Icons.people_alt_rounded, 'Members', 1, isDark, txtPrimary, txtSecondary),
                  _drawerItem(context, Icons.person_add_alt_1_rounded, 'Leads / Inquiries', 2, isDark, txtPrimary, txtSecondary),
                  const SizedBox(height: 8),
                  _drawerSection('MANAGEMENT'),
                  _drawerItem(context, Icons.restaurant_menu_rounded, 'Diet Plans', 3, isDark, txtPrimary, txtSecondary),
                  _drawerItem(context, Icons.card_membership_rounded, 'Membership Plans', 4, isDark, txtPrimary, txtSecondary),
                  _drawerItem(context, Icons.bar_chart_rounded, 'Reports', 5, isDark, txtPrimary, txtSecondary),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(height: 1, color: borderColor),
                  ),
                  const SizedBox(height: 8),
                  _drawerSection('ACCOUNT'),
                  _drawerItem(context, Icons.settings_rounded, 'Settings', 6, isDark, txtPrimary, txtSecondary),
                  _drawerItem(context, Icons.verified_rounded, 'Subscription & Billing', 7, isDark, txtPrimary, txtSecondary),
                ],
              ),
            ),

            // ── Footer ──
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.fitness_center_rounded, size: 14, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'FitnexGym SaaS v1.0',
                    style: TextStyle(color: txtSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: _screens[_currentIndex],
        ),
      ),
    );
  }

  Widget _drawerSection(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
      child: Text(
        label,
        style: TextStyle(
          color: AppTheme.primary.withValues(alpha: 0.7),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context,
    IconData icon,
    String title,
    int index,
    bool isDark,
    Color txtPrimary,
    Color txtSecondary,
  ) {
    final selected = _currentIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _onMenuSelected(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.primary.withValues(alpha: isDark ? 0.15 : 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: selected
                  ? Border.all(color: AppTheme.primary.withValues(alpha: 0.3))
                  : null,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.primary.withValues(alpha: 0.15)
                        : (isDark ? AppTheme.darkSurfaceAlt : AppTheme.lightSurfaceAlt),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: selected ? AppTheme.primary : txtSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: selected ? AppTheme.primary : txtPrimary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
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

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
