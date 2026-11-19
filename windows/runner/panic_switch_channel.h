#ifndef RUNNER_PANIC_SWITCH_CHANNEL_H_
#define RUNNER_PANIC_SWITCH_CHANNEL_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <memory>

#include "panic_overlay_window.h"

// The native side of the panic switch ("Thay vo",
// lib/features/panic_switch/data/datasources/panic_switch_channel.dart):
// lists the apps with windows, brings one forward, minimises others, and owns
// the floating button. Apps are identified by their executable's full path.
class PanicSwitchChannel {
 public:
  explicit PanicSwitchChannel(flutter::BinaryMessenger* messenger);

 private:
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::unique_ptr<PanicOverlayWindow> overlay_;
};

#endif  // RUNNER_PANIC_SWITCH_CHANNEL_H_
