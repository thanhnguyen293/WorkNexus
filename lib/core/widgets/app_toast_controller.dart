import 'package:flutter/foundation.dart';

/// One toast on screen.
typedef AppToast = ({int id, String message, bool isError});

/// The toasts on screen, newest first, at most [maxShown]. Showing a message
/// that is already up moves it to the top instead of repeating it.
class AppToastController extends ChangeNotifier {
  static const maxShown = 3;

  List<AppToast> _toasts = const [];
  int _nextId = 0;

  List<AppToast> get toasts => _toasts;

  void show(String message, {bool isError = false}) {
    _toasts = [
      (id: _nextId++, message: message, isError: isError),
      ..._toasts.where((t) => t.message != message),
    ].take(maxShown).toList(growable: false);
    notifyListeners();
  }

  void dismiss(int id) {
    final left = _toasts.where((t) => t.id != id).toList(growable: false);
    if (left.length == _toasts.length) return;
    _toasts = left;
    notifyListeners();
  }
}
