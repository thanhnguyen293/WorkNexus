import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/panic_button_look.dart';

/// The name a [PanicGesture] is shown under.
String gestureLabel(AppL10n l, PanicGesture gesture) => switch (gesture) {
  PanicGesture.doubleClick => l.panicSwitchGestureDouble,
  PanicGesture.tripleClick => l.panicSwitchGestureTriple,
  PanicGesture.hold => l.panicSwitchGestureHold,
};
