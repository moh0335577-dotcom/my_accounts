import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:my_accounts/core/localization/l10n/app_localizations.dart';
import 'package:my_accounts/features/dashboard/presentation/dashboard_screen.dart';
import 'package:my_accounts/features/transactions/presentation/transactions_screen.dart';
import 'package:my_accounts/features/projects/presentation/projects_screen.dart';
import 'package:my_accounts/features/projects/presentation/project_details_screen.dart';
import 'package:my_accounts/features/reports/presentation/reports_screen.dart';
import 'package:my_accounts/features/settings/presentation/settings_screen.dart';
import 'package:my_accounts/features/settings/presentation/categories_management_screen.dart';
import 'package:my_accounts/features/transactions/presentation/add_transaction_screen.dart';
import 'package:my_accounts/features/transactions/presentation/transaction_details_screen.dart';
import 'package:my_accounts/features/people/presentation/people_screen.dart';
import 'package:my_accounts/features/people/presentation/person_details_screen.dart';
import 'package:my_accounts/features/transactions/presentation/trash_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  initialLocation: '/',
  navigatorKey: _rootNavigatorKey,
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return ScaffoldWithBottomNavBar(child: child);
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/transactions',
          builder: (context, state) => const TransactionsScreen(),
        ),
        GoRoute(
          path: '/projects',
          builder: (context, state) => const ProjectsScreen(),
        ),
        GoRoute(
          path: '/reports',
          builder: (context, state) => const ReportsScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/add-transaction',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final initialProjectId = state.uri.queryParameters['projectId'] != null 
            ? int.tryParse(state.uri.queryParameters['projectId']!) 
            : null;
        return AddTransactionScreen(initialProjectId: initialProjectId);
      },
    ),
    GoRoute(
      path: '/edit-transaction/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return AddTransactionScreen(transactionId: id);
      },
    ),
    GoRoute(
      path: '/transaction/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return TransactionDetailsScreen(transactionId: id);
      },
    ),
    GoRoute(
      path: '/project/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return ProjectDetailsScreen(projectId: id);
      },
    ),
    GoRoute(
      path: '/people',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const PeopleScreen(),
    ),
    GoRoute(
      path: '/person/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return PersonDetailsScreen(personId: id);
      },
    ),
    GoRoute(
      path: '/categories',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CategoriesManagementScreen(),
    ),
    GoRoute(
      path: '/trash',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const TrashScreen(),
    ),
  ],
);

class ScaffoldWithBottomNavBar extends StatelessWidget {
  const ScaffoldWithBottomNavBar({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final location = GoRouterState.of(context).matchedLocation;
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _calculateSelectedIndex(location),
        onDestinationSelected: (index) => _onItemTapped(index, context),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.dashboard_outlined), label: l10n.dashboard),
          NavigationDestination(icon: const Icon(Icons.list_alt), label: l10n.transactions),
          NavigationDestination(icon: const Icon(Icons.work_outline), label: l10n.projects),
          NavigationDestination(icon: const Icon(Icons.bar_chart), label: l10n.reports),
          NavigationDestination(icon: const Icon(Icons.settings_outlined), label: l10n.settings),
        ],
      ),
      floatingActionButton: location == '/' || location == '/transactions' 
        ? FloatingActionButton(
            onPressed: () => context.push('/add-transaction'),
            child: const Icon(Icons.add),
          )
        : null,
    );
  }

  static int _calculateSelectedIndex(String location) {
    if (location.startsWith('/transactions')) return 1;
    if (location.startsWith('/projects')) return 2;
    if (location.startsWith('/reports')) return 3;
    if (location.startsWith('/settings')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0: context.go('/'); break;
      case 1: context.go('/transactions'); break;
      case 2: context.go('/projects'); break;
      case 3: context.go('/reports'); break;
      case 4: context.go('/settings'); break;
    }
  }
}


