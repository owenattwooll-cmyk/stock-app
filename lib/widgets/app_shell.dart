import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/update_checker.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static bool _checkedForUpdatesThisRun = false;
  bool _checkingForUpdates = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdatesIfNeeded());
  }

  Future<void> _checkForUpdatesIfNeeded() async {
    if (!mounted || _checkedForUpdatesThisRun || _checkingForUpdates) {
      return;
    }

    _checkingForUpdates = true;
    final result = await UpdateChecker.checkForUpdate();
    _checkedForUpdatesThisRun = true;
    _checkingForUpdates = false;

    if (!mounted || result == null) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update available'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are on ${result.currentVersion}. Version ${result.latestVersion} is available.'),
            if (result.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: SingleChildScrollView(
                  child: Text(
                    result.releaseNotes,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () async {
              final uri = Uri.parse(result.downloadUrl);
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Download update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900;
        final outerPadding = isMobile ? 12.0 : 24.0;
        final contentPadding = isMobile ? 16.0 : 24.0;

        return Scaffold(
          drawer: isMobile
              ? Drawer(
                  child: SafeArea(
                    child: _Sidebar(isDrawer: true),
                  ),
                )
              : null,
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF050B16),
                  Color(0xFF0B1220),
                  Color(0xFF08111F),
                ],
              ),
            ),
            child: isMobile
                ? SafeArea(
                    child: Padding(
                      padding: EdgeInsets.all(outerPadding),
                      child: Column(
                        children: [
                          const _TopBar(showMenuButton: true),
                          const SizedBox(height: 12),
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(contentPadding),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0E1728).withValues(alpha: 0.96),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF22304A)),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color.fromRGBO(1, 6, 20, 0.34),
                                    blurRadius: 40,
                                    offset: Offset(0, 20),
                                  ),
                                ],
                              ),
                              child: widget.child,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Row(
                    children: [
                      const _Sidebar(),
                      Expanded(
                        child: SafeArea(
                          child: Padding(
                            padding: EdgeInsets.all(outerPadding),
                            child: Column(
                              children: [
                                const _TopBar(),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: Container(
                                    padding: EdgeInsets.all(contentPadding),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0E1728).withValues(alpha: 0.96),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: const Color(0xFF22304A)),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color.fromRGBO(1, 6, 20, 0.34),
                                          blurRadius: 40,
                                          offset: Offset(0, 20),
                                        ),
                                      ],
                                    ),
                                    child: widget.child,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({this.showMenuButton = false});

  final bool showMenuButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = Supabase.instance.client.auth.currentUser;
    final isCompact = MediaQuery.sizeOf(context).width < 700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showMenuButton) ...[
                IconButton(
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: const Icon(Icons.menu_rounded),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reseller Command Center', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      'Track stock, purchases, and sales in one place.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: isCompact ? WrapAlignment.start : WrapAlignment.end,
            children: [
              if (user != null && user.email != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111C2C),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF26364F)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person, size: 16, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: isCompact ? 190 : 260),
                        child: Text(
                          user.email!,
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({this.isDrawer = false});

  final bool isDrawer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: isDrawer ? double.infinity : 260,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF090F1A),
            Color(0xFF101A2B),
            Color(0xFF0A1321),
          ],
          stops: [0.0, 0.6, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Inventory Workspace',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              shrinkWrap: true,
              children: const [
                _NavItem(label: 'Dashboard', route: '/', icon: Icons.home_outlined),
                _NavItem(label: 'Items', route: '/items', icon: Icons.inventory_2_outlined),
                _NavItem(label: 'Purchase History', route: '/purchase-history', icon: Icons.history),
                _NavItem(label: 'Stock', route: '/stock', icon: Icons.storage_outlined),
                _NavItem(label: 'Sales', route: '/sales', icon: Icons.shopping_cart_outlined),
                _NavItem(label: 'Livestreaming', route: '/livestreaming', icon: Icons.live_tv_outlined),
              ],
            ),
          ),
          Text(
            'Inventory, stock, purchases, and sales in one workspace.',
            style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFFE5E7EB)),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.label, required this.route, required this.icon});

  final String label;
  final String route;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = GoRouterState.of(context).uri.toString() == route;
    final color = isActive ? Colors.white : const Color(0xFFE5E7EB);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: isActive ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.go(route),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                        color: color,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
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
