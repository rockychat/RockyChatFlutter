import 'package:flutter/material.dart';

/// Simple route observer that tracks the navigation stack depth
/// so [MainShell] can hide the bottom bar when a detail page is pushed.
class AppRouteObserver extends RouteObserver<ModalRoute<dynamic>> {
  int get routeStackDepth => _routeStack.length;

  final List<ModalRoute<dynamic>> _routeStack = [];
  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback listener) => _listeners.add(listener);
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void _notify() {
    for (final l in _listeners) {
      l();
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is ModalRoute) _routeStack.add(route);
    _notify();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (_routeStack.isNotEmpty) _routeStack.removeLast();
    _notify();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    if (route is ModalRoute) _routeStack.remove(route);
    _notify();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    // Remove old, then add new — order matters for stack correctness.
    if (oldRoute is ModalRoute) _routeStack.remove(oldRoute);
    if (newRoute is ModalRoute) _routeStack.add(newRoute);
    _notify();
  }
}

final appRouteObserver = AppRouteObserver();
