import 'package:flutter/material.dart';

/// Global RouteObserver to track route changes across the app
/// This allows screens to be notified when they become active again
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

