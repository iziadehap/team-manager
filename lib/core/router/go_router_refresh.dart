import 'dart:async';

import 'package:flutter/foundation.dart';

/// Notifies [GoRouter] when a [Stream] emits so redirects re-run.
class GoRouterRefresh extends ChangeNotifier {
  GoRouterRefresh(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
