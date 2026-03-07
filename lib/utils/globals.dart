import 'package:flutter/material.dart';

/// Global key to access the Navigator State from anywhere in the app
/// (e.g., from background services like Notification tracking)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
