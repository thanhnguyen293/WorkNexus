#ifndef RUNNER_PANIC_SWITCH_CHANNEL_H_
#define RUNNER_PANIC_SWITCH_CHANNEL_H_

#include <flutter_linux/flutter_linux.h>

// The native side of the panic switch ("Thay vo",
// lib/features/panic_switch/data/datasources/panic_switch_channel.dart) on
// Linux: only the floating button. Raising and hiding other apps is done from
// Dart with wmctrl / xdotool / gtk-launch (LinuxAppSwitcher).
void panic_switch_channel_register(FlView* view);

#endif  // RUNNER_PANIC_SWITCH_CHANNEL_H_
