import 'package:flutter/widgets.dart';

import '../player/player_controller.dart';
import 'app_state.dart';
import 'library.dart';
import 'paging.dart';

/// Hands the long-lived controllers to every screen. [AppState] is exposed
/// through an [InheritedNotifier], so any widget that reads `context.app`
/// rebuilds (and gets `didChangeDependencies`) when the app state changes.
class AppScope extends StatelessWidget {
  const AppScope({
    super.key,
    required this.state,
    required this.player,
    required this.library,
    required this.epg,
    required this.child,
  });

  final AppState state;
  final PlayerController player;
  final LibraryApi library;
  final EpgCache epg;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _Services(
      player: player,
      library: library,
      epg: epg,
      child: _AppStateScope(notifier: state, child: child),
    );
  }
}

class _Services extends InheritedWidget {
  const _Services({required this.player, required this.library, required this.epg, required super.child});

  final PlayerController player;
  final LibraryApi library;
  final EpgCache epg;

  @override
  bool updateShouldNotify(_Services old) => player != old.player || library != old.library || epg != old.epg;
}

class _AppStateScope extends InheritedNotifier<AppState> {
  const _AppStateScope({required super.notifier, required super.child});
}

extension AppScopeX on BuildContext {
  AppState get app => dependOnInheritedWidgetOfExactType<_AppStateScope>()!.notifier!;
  PlayerController get player => getInheritedWidgetOfExactType<_Services>()!.player;
  LibraryApi get library => getInheritedWidgetOfExactType<_Services>()!.library;
  EpgCache get epg => getInheritedWidgetOfExactType<_Services>()!.epg;
}
