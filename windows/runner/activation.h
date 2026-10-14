#ifndef RUNNER_ACTIVATION_H_
#define RUNNER_ACTIVATION_H_

// The window message a second launch posts to the running instance, which then
// shows and focuses its own window. The second process makes no window calls
// itself: the show state of its launch (a shortcut set to "Normal window", the
// taskbar's jump list) would otherwise be applied to the running window.
constexpr wchar_t kActivateMessageName[] = L"WorkNexus.ActivateWindow";

#endif  // RUNNER_ACTIVATION_H_
