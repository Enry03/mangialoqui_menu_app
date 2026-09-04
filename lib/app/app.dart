import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/providers.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/auth_flow_service.dart';
import 'router.dart';

class MangialoquiMenuApp extends ConsumerStatefulWidget {
  const MangialoquiMenuApp({super.key});

  @override
  ConsumerState<MangialoquiMenuApp> createState() =>
      _MangialoquiMenuAppState();
}

class _MangialoquiMenuAppState extends ConsumerState<MangialoquiMenuApp>
    with WidgetsBindingObserver {
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _offlineBlocked = false;
  bool _checkingConnection = false;
  bool _networkAvailable = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _connectivitySub = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Connectivity listener failed: $error');

        if (_offlineBlocked && !_checkingConnection) {
          unawaited(_retryConnection());
        }
      },
    );

    unawaited(_initializeConnectivityGuard());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() async {
    return _offlineBlocked;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _offlineBlocked) {
      unawaited(_retryConnection());
    }
  }

  Future<void> _initializeConnectivityGuard() async {
    try {
      final result = await _connectivity.checkConnectivity();
      if (!mounted) return;

      _networkAvailable = !result.contains(ConnectivityResult.none);

      if (!_networkAvailable) {
        _showConnectionBlock();
        return;
      }

      final reachable = await _probeSupabase();
      if (!mounted) return;

      if (!reachable) {
        _showConnectionBlock();
      }
    } catch (error) {
      debugPrint('Connectivity initialization failed: $error');

      final reachable = await _probeSupabase();
      if (!mounted) return;

      if (!reachable) {
        _showConnectionBlock();
      }
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> result) {
    if (!mounted) return;

    _networkAvailable = !result.contains(ConnectivityResult.none);

    if (!_networkAvailable) {
      _showConnectionBlock();
      return;
    }

    if (_offlineBlocked && !_checkingConnection) {
      unawaited(_retryConnection());
    }
  }

  void _showConnectionBlock() {
    if (!mounted) return;

    FocusManager.instance.primaryFocus?.unfocus();

    if (_offlineBlocked) return;

    setState(() {
      _offlineBlocked = true;
    });
  }

  Future<bool> _probeSupabase() async {
    try {
      await Supabase.instance.client
          .from('restaurants')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 5));

      return true;
    } catch (error) {
      debugPrint('Supabase connectivity probe failed: $error');
      return false;
    }
  }

  Future<void> _reconcileApplicationStateAfterReconnect() async {
    await AuthFlowService.reconcileAccountLogoutStateNow();

    final client = ref.read(supabaseClientProvider);

    if (client.auth.currentUser == null) {
      return;
    }

    final profileRepository = ref.read(profileRepositoryProvider);
    final restaurantRepository = ref.read(restaurantRepositoryProvider);

    final profiles = await profileRepository.findActiveProfiles();
    final restaurants = await restaurantRepository.getRestaurantsByIds(
      profiles.map((profile) => profile.restaurantId),
    );

    final restaurantsById = {
      for (final restaurant in restaurants) restaurant.id: restaurant,
    };

    final selectedRestaurantId = ref.read(selectedRestaurantIdProvider);
    final lastCurrentRestaurantId = ref.read(lastCurrentRestaurantIdProvider);
    final restaurantRemoved = ref.read(currentRestaurantRemovedProvider);
    final menuProDisabled = ref.read(
      currentRestaurantMenuProDisabledProvider,
    );

    String? currentRestaurantId = selectedRestaurantId;

    if (currentRestaurantId == null && lastCurrentRestaurantId != null) {
      if (restaurantRemoved || menuProDisabled || profiles.length <= 1) {
        currentRestaurantId = lastCurrentRestaurantId;
      }
    }

    if (currentRestaurantId != null) {
      final hasActiveProfile = profiles.any(
        (profile) => profile.restaurantId == currentRestaurantId,
      );

      if (!hasActiveProfile) {
        ref.read(selectedRestaurantIdProvider.notifier).state = null;
        ref.read(currentRestaurantRemovedProvider.notifier).state = true;
        ref
            .read(currentRestaurantMenuProDisabledProvider.notifier)
            .state = false;
      } else {
        final restaurant = restaurantsById[currentRestaurantId];

        if (restaurant == null || !restaurant.hasMenuPro) {
          ref.read(selectedRestaurantIdProvider.notifier).state = null;
          ref.read(currentRestaurantRemovedProvider.notifier).state = false;
          ref
              .read(currentRestaurantMenuProDisabledProvider.notifier)
              .state = true;
        }
      }
    }

    ref.invalidate(restaurantMembershipsRealtimeProvider);
    ref.invalidate(restaurantsMenuProRealtimeProvider);
    ref.invalidate(menuProPermissionRealtimeProvider);

    ref.invalidate(availableRestaurantMembershipsProvider);
    ref.invalidate(currentRestaurantMembershipProvider);
    ref.invalidate(currentProfileProvider);
    ref.invalidate(currentRestaurantProvider);
    ref.invalidate(currentMenuProAccessProvider);
    ref.invalidate(currentMenuProvider);
    ref.invalidate(currentThemeProvider);

    await ref.read(availableRestaurantMembershipsProvider.future);

    if (currentRestaurantId == null) {
      return;
    }

    if (ref.read(currentRestaurantRemovedProvider) ||
        ref.read(currentRestaurantMenuProDisabledProvider)) {
      return;
    }

    await ref.read(currentRestaurantMembershipProvider.future);
    await ref.read(currentMenuProAccessProvider.future);
  }

  Future<void> _retryConnection() async {
    if (!mounted || _checkingConnection) return;

    setState(() {
      _offlineBlocked = true;
      _checkingConnection = true;
    });

    try {
      final result = await _connectivity.checkConnectivity();
      if (!mounted) return;

      _networkAvailable = !result.contains(ConnectivityResult.none);
      if (!_networkAvailable) return;

      final reachable = await _probeSupabase();
      if (!mounted || !reachable) return;

      await _reconcileApplicationStateAfterReconnect();
      if (!mounted) return;

      final finalResult = await _connectivity.checkConnectivity();
      if (!mounted) return;

      _networkAvailable = !finalResult.contains(ConnectivityResult.none);
      if (!_networkAvailable) return;

      setState(() {
        _offlineBlocked = false;
      });
    } catch (error) {
      debugPrint('Connection retry failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _checkingConnection = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Mangialoqui Menu',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: appRouter,
      builder: (context, child) {
        final app = child ?? const SizedBox.shrink();

        if (!_offlineBlocked) {
          return app;
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            app,
            const ModalBarrier(
              dismissible: false,
              color: AppColors.background,
            ),
            _OfflineConnectionBlockPage(
              checking: _checkingConnection,
              onRetry: () {
                unawaited(_retryConnection());
              },
            ),
          ],
        );
      },
    );
  }
}

class _OfflineConnectionBlockPage extends StatelessWidget {
  final bool checking;
  final VoidCallback onRetry;

  const _OfflineConnectionBlockPage({
    required this.checking,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  size: 72,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Impossibile caricare i dati',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Controlla la connessione e riprova.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: checking ? null : onRetry,
                  icon: checking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: const Text('Riprova'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
