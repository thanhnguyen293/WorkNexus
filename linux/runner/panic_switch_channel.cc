#include "panic_switch_channel.h"

#include <gtk/gtk.h>

#include <cstdlib>

namespace {

// The button's width in pixels.
constexpr int kWidth = 120;

// How far (in pixels) the pointer may move before a press becomes a drag.
constexpr double kDragSlop = 3;

struct PanicSwitch {
  FlMethodChannel* channel = nullptr;
  GtkWidget* window = nullptr;
  GtkWidget* image = nullptr;

  // Drag state: where the button went down, and whether the window is being
  // dragged (handed to the window manager) rather than clicked.
  bool pressed = false;
  bool dragged = false;
  double press_x = 0;
  double press_y = 0;

  // Clicks in a row, for the triple click, of each button (left, right).
  int clicks[2] = {0, 0};
  gint64 last_click_us[2] = {0, 0};
};

PanicSwitch* g_panic_switch = nullptr;

gint DoubleClickMs() {
  gint ms = 400;
  g_object_get(gtk_settings_get_default(), "gtk-double-click-time", &ms,
               nullptr);
  return ms;
}

gboolean on_press(GtkWidget*, GdkEventButton* event, gpointer data) {
  auto* self = static_cast<PanicSwitch*>(data);
  // GTK also sends 2BUTTON/3BUTTON presses; the release count is ours.
  if (event->button != 1 || event->type != GDK_BUTTON_PRESS) return TRUE;
  self->pressed = true;
  self->dragged = false;
  self->press_x = event->x_root;
  self->press_y = event->y_root;
  return TRUE;
}

gboolean on_motion(GtkWidget*, GdkEventMotion* event, gpointer data) {
  auto* self = static_cast<PanicSwitch*>(data);
  if (!self->pressed || self->dragged) return TRUE;
  if (std::abs(event->x_root - self->press_x) <= kDragSlop &&
      std::abs(event->y_root - self->press_y) <= kDragSlop) {
    return TRUE;
  }
  // The window manager moves it: the only way that also works on Wayland.
  self->dragged = true;
  self->pressed = false;
  self->clicks[0] = 0;
  gtk_window_begin_move_drag(GTK_WINDOW(self->window), 1,
                             static_cast<gint>(event->x_root),
                             static_cast<gint>(event->y_root), event->time);
  return TRUE;
}

// Counts a click; three in a row of the left button send "release", of the
// right button "demo".
void count_click(PanicSwitch* self, bool demo) {
  const int b = demo ? 1 : 0;
  const gint64 now = g_get_monotonic_time();
  self->clicks[b] = (self->clicks[b] > 0 &&
                     now - self->last_click_us[b] <=
                         static_cast<gint64>(DoubleClickMs()) * 1000)
                        ? self->clicks[b] + 1
                        : 1;
  self->last_click_us[b] = now;
  if (self->clicks[b] < 3) return;
  self->clicks[b] = 0;
  g_autoptr(FlValue) which = fl_value_new_string(demo ? "demo" : "release");
  fl_method_channel_invoke_method(self->channel, "overlayTriggered", which,
                                  nullptr, nullptr, nullptr);
}

gboolean on_release(GtkWidget*, GdkEventButton* event, gpointer data) {
  auto* self = static_cast<PanicSwitch*>(data);
  if (event->button == 3) {
    count_click(self, true);
    return TRUE;
  }
  if (event->button != 1 || !self->pressed) return TRUE;
  self->pressed = false;
  count_click(self, false);
  return TRUE;
}

void ensure_window(PanicSwitch* self) {
  if (self->window != nullptr) return;
  GtkWidget* window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_decorated(GTK_WINDOW(window), FALSE);
  gtk_window_set_keep_above(GTK_WINDOW(window), TRUE);
  gtk_window_set_skip_taskbar_hint(GTK_WINDOW(window), TRUE);
  gtk_window_set_skip_pager_hint(GTK_WINDOW(window), TRUE);
  gtk_window_set_accept_focus(GTK_WINDOW(window), FALSE);
  gtk_window_set_focus_on_map(GTK_WINDOW(window), FALSE);
  gtk_window_set_resizable(GTK_WINDOW(window), FALSE);
  gtk_window_set_type_hint(GTK_WINDOW(window), GDK_WINDOW_TYPE_HINT_UTILITY);
  gtk_window_stick(GTK_WINDOW(window));
  gtk_window_set_position(GTK_WINDOW(window), GTK_WIN_POS_CENTER);
  // Transparent around the sticker where the compositor allows it.
  GdkScreen* screen = gtk_widget_get_screen(window);
  if (GdkVisual* visual = gdk_screen_get_rgba_visual(screen)) {
    gtk_widget_set_visual(window, visual);
    gtk_widget_set_app_paintable(window, TRUE);
  }

  GtkWidget* box = gtk_event_box_new();
  gtk_event_box_set_visible_window(GTK_EVENT_BOX(box), FALSE);
  gtk_widget_add_events(box, GDK_BUTTON_PRESS_MASK | GDK_BUTTON_RELEASE_MASK |
                                 GDK_POINTER_MOTION_MASK);
  g_signal_connect(box, "button-press-event", G_CALLBACK(on_press), self);
  g_signal_connect(box, "button-release-event", G_CALLBACK(on_release), self);
  g_signal_connect(box, "motion-notify-event", G_CALLBACK(on_motion), self);

  self->image = gtk_image_new();
  gtk_container_add(GTK_CONTAINER(box), self->image);
  gtk_container_add(GTK_CONTAINER(window), box);
  // Closing it from the window manager only hides it; Dart decides.
  g_signal_connect(window, "delete-event",
                   G_CALLBACK(gtk_widget_hide_on_delete), nullptr);
  self->window = window;
}

// Shows |bytes| (PNG/JPEG) as the button; false when it cannot be decoded.
bool show_overlay(PanicSwitch* self, const uint8_t* bytes, size_t length) {
  GdkPixbufLoader* loader = gdk_pixbuf_loader_new();
  const gboolean written =
      gdk_pixbuf_loader_write(loader, bytes, length, nullptr) &&
      gdk_pixbuf_loader_close(loader, nullptr);
  GdkPixbuf* source =
      written ? gdk_pixbuf_loader_get_pixbuf(loader) : nullptr;
  if (source == nullptr || gdk_pixbuf_get_width(source) <= 0) {
    g_object_unref(loader);
    return false;
  }
  const int height = kWidth * gdk_pixbuf_get_height(source) /
                     gdk_pixbuf_get_width(source);
  GdkPixbuf* scaled = gdk_pixbuf_scale_simple(source, kWidth,
                                              height > 0 ? height : 1,
                                              GDK_INTERP_BILINEAR);
  g_object_unref(loader);
  if (scaled == nullptr) return false;

  ensure_window(self);
  gtk_image_set_from_pixbuf(GTK_IMAGE(self->image), scaled);
  g_object_unref(scaled);
  gtk_widget_show_all(self->window);
  return true;
}

void method_call_cb(FlMethodChannel*, FlMethodCall* call, gpointer data) {
  auto* self = static_cast<PanicSwitch*>(data);
  const gchar* method = fl_method_call_get_name(call);
  g_autoptr(FlMethodResponse) response = nullptr;
  if (g_strcmp0(method, "showOverlay") == 0) {
    FlValue* args = fl_method_call_get_args(call);
    FlValue* image = (args != nullptr &&
                      fl_value_get_type(args) == FL_VALUE_TYPE_MAP)
                         ? fl_value_lookup_string(args, "image")
                         : nullptr;
    if (image != nullptr &&
        fl_value_get_type(image) == FL_VALUE_TYPE_UINT8_LIST &&
        show_overlay(self, fl_value_get_uint8_list(image),
                     fl_value_get_length(image))) {
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
    } else {
      response = FL_METHOD_RESPONSE(fl_method_error_response_new(
          "overlay_failed", "Could not show the button", nullptr));
    }
  } else if (g_strcmp0(method, "hideOverlay") == 0) {
    if (self->window != nullptr) gtk_widget_hide(self->window);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }
  fl_method_call_respond(call, response, nullptr);
}

}  // namespace

void panic_switch_channel_register(FlView* view) {
  if (g_panic_switch != nullptr) return;
  g_panic_switch = new PanicSwitch();
  FlEngine* engine = fl_view_get_engine(view);
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_panic_switch->channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(engine), "worknexus/panic_switch",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      g_panic_switch->channel, method_call_cb, g_panic_switch, nullptr);
}
