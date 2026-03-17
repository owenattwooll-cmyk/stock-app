import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/dashboard_screen.dart';
import '../screens/item_detail_screen.dart';
import '../screens/items_screen.dart';
import '../screens/login_screen.dart';
import '../screens/purchase_history_screen.dart';
import '../screens/sales_screen.dart';
import '../screens/stock_screen.dart';
import '../widgets/app_shell.dart';

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(Supabase.instance.client.auth.onAuthStateChange),
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLogin = state.uri.toString() == '/login';
      if (session == null && !isLogin) {
        return '/login';
      }
      if (session != null && isLogin) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/items',
            builder: (context, state) => const ItemsScreen(),
          ),
          GoRoute(
            path: '/items/:itemId',
            builder: (context, state) => ItemDetailScreen(
              itemId: state.pathParameters['itemId']!,
            ),
          ),
          GoRoute(
            path: '/purchase-history',
            builder: (context, state) => const PurchaseHistoryScreen(),
          ),
          GoRoute(
            path: '/purchases',
            redirect: (context, state) => '/purchase-history',
          ),
          GoRoute(
            path: '/stock',
            builder: (context, state) => const StockScreen(),
          ),
          GoRoute(
            path: '/sales',
            builder: (context, state) => const SalesScreen(),
          ),
        ],
      ),
    ],
  );
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
