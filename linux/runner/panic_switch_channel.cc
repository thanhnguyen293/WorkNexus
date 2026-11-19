#include "panic_switch_channel.h"

#include <gtk/gtk.h>

#include <cstdlib>
#include <string>

namespace {

// The button's width in pixels when none is given.
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

  // Clicks in a row, for the double/triple click.
  int clicks = 0;
  gint64 last_click_us = 0;

  // When the button went down, for the long press.
  gint64 pressed_us = 0;
  // "double", "triple" or "hold".
  std::string gesture = "triple";

  // The right-click menu (demo mode only): made once, relabelled on show.
  std::string demo_label;
  GtkWidget* menu = nullptr;
  GtkWidget* menu_item = nullptr;
};

// A press at least this long (µs) is a long press.
constexpr gint64 kHoldUs = 800 * 1000;

PanicSwitch* g_panic_switch = nullptr;

gint DoubleClickMs() {
  gint ms = 400;
  g_object_get(gtk_settings_get_default(), "gtk-double-click-time", &ms,
               nullptr);
  return ms;
}

// Tells Dart the button went off: "release" or "demo".
void send_trigger(PanicSwitch* self, bool demo) {
  g_autoptr(FlValue) which = fl_value_new_string(demo ? "demo" : "release");
  fl_method_channel_invoke_method(self->channel, "overlayTriggered", which,
                                  nullptr, nullptr, nullptr);
}

void on_demo_chosen(GtkMenuItem*, gpointer data) {
  send_trigger(static_cast<PanicSwitch*>(data), true);
}

// Opens the right-click menu with its one item, "Demo"; nothing outside demo
// mode.
void show_demo_menu(PanicSwitch* self, GdkEventButton* event) {
  if (self->demo_label.empty()) return;
  if (self->menu == nullptr) {
    self->menu = gtk_menu_new();
    self->menu_item = gtk_menu_item_new_with_label("");
    g_signal_connect(self->menu_item, "activate", G_CALLBACK(on_demo_chosen),
                     self);
    gtk_menu_shell_append(GTK_MENU_SHELL(self->menu), self->menu_item);
    gtk_menu_attach_to_widget(GTK_MENU(self->menu), self->window, nullptr);
  }
  gtk_menu_item_set_label(GTK_MENU_ITEM(self->menu_item),
                          self->demo_label.c_str());
  gtk_widget_show_all(self->menu);
  gtk_menu_popup_at_pointer(GTK_MENU(self->menu),
                            reinterpret_cast<GdkEvent*>(event));
}

gboolean on_press(GtkWidget*, GdkEventButton* event, gpointer data) {
  auto* self = static_cast<PanicSwitch*>(data);
  // GTK also sends 2BUTTON/3BUTTON presses; the release count is ours.
  if (event->type != GDK_BUTTON_PRESS) return TRUE;
  if (event->button == 3) {
    show_demo_menu(self, event);
    return TRUE;
  }
  if (event->button != 1) return TRUE;
  self->pressed_us = g_get_monotonic_time();
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
  self->clicks = 0;
  gtk_window_begin_move_drag(GTK_WINDOW(self->window), 1,
                             static_cast<gint>(event->x_root),
                             static_cast<gint>(event->y_root), event->time);
  return TRUE;
}

// Counts a left click; on the chosen gesture sends "release".
void count_click(PanicSwitch* self) {
  const gint64 now = g_get_monotonic_time();
  bool fires = false;
  if (self->gesture == "hold") {
    fires = self->pressed_us != 0 && now - self->pressed_us >= kHoldUs;
    self->pressed_us = 0;
  } else {
    const int needed = self->gesture == "double" ? 2 : 3;
    self->clicks = (self->clicks > 0 &&
                    now - self->last_click_us <=
                        static_cast<gint64>(DoubleClickMs()) * 1000)
                       ? self->clicks + 1
                       : 1;
    self->last_click_us = now;
    if (self->clicks >= needed) {
      self->clicks = 0;
      fires = true;
    }
  }
  if (fires) send_trigger(self, false);
}

gboolean on_release(GtkWidget*, GdkEventButton* event, gpointer data) {
  auto* self = static_cast<PanicSwitch*>(data);
  if (event->button != 1 || !self->pressed) return TRUE;
  self->pressed = false;
  count_click(self);
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

// Shows |bytes| (PNG/JPEG) as the button, |width| pixels wide and |opacity|
// (0-1) opaque; false when it cannot be decoded.
bool show_overlay(PanicSwitch* self, const uint8_t* bytes, size_t length,
                  int width, double opacity) {
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
  const int height = width * gdk_pixbuf_get_height(source) /
                     gdk_pixbuf_get_width(source);
  GdkPixbuf* scaled = gdk_pixbuf_scale_simple(source, width,
                                              height > 0 ? height : 1,
                                              GDK_INTERP_BILINEAR);
  g_object_unref(loader);
  if (scaled == nullptr) return false;

  ensure_window(self);
  gtk_image_set_from_pixbuf(GTK_IMAGE(self->image), scaled);
  g_object_unref(scaled);
  // Shrinks too: a non-resizable window keeps its old size otherwise.
  gtk_window_resize(GTK_WINDOW(self->window), 1, 1);
  gtk_widget_set_opacity(self->window, opacity);
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
    FlValue* size = image != nullptr ? fl_value_lookup_string(args, "size")
                                     : nullptr;
    FlValue* opacity = image != nullptr
                           ? fl_value_lookup_string(args, "opacity")
                           : nullptr;
    FlValue* gesture = image != nullptr
                           ? fl_value_lookup_string(args, "gesture")
                           : nullptr;
    if (gesture != nullptr && fl_value_get_type(gesture) == FL_VALUE_TYPE_STRING) {
      self->gesture = fl_value_get_string(gesture);
    }
    FlValue* demo = image != nullptr
                        ? fl_value_lookup_string(args, "demoLabel")
                        : nullptr;
    self->demo_label =
        demo != nullptr && fl_value_get_type(demo) == FL_VALUE_TYPE_STRING
            ? fl_value_get_string(demo)
            : "";
    const int width =
        size != nullptr && fl_value_get_type(size) == FL_VALUE_TYPE_INT
            ? static_cast<int>(fl_value_get_int(size))
            : kWidth;
    const double alpha =
        opacity != nullptr && fl_value_get_type(opacity) == FL_VALUE_TYPE_FLOAT
            ? fl_value_get_float(opacity)
            : 1.0;
    if (image != nullptr &&
        fl_value_get_type(image) == FL_VALUE_TYPE_UINT8_LIST &&
        show_overlay(self, fl_value_get_uint8_list(image),
                     fl_value_get_length(image), width, alpha)) {
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
