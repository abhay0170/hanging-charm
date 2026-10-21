/// Messages between the Customize window and the charm (the overlay). The
/// two run in separate processes; each map travels as a JSON string through
/// the native side (windows/runner/app_messages.h), which never looks inside.
///
/// - Customize → overlay `{type: hello}`: ready; send me the state.
/// - Customize → overlay `{type: update, changes: {...}}`: settings fields
///   to change, using the keys of `AppSettings.toJson`.
/// - Overlay → Customize `{type: state, settings: {...}}`: the settings as
///   they are now, after any change from anywhere (tray, charm menu, here).
abstract final class CustomizeProtocol {
  static const type = 'type';
  static const hello = 'hello';
  static const update = 'update';

  /// Customize → overlay: delete everything saved and go back to the
  /// defaults (settings, the user's charms, the log, launch at login).
  static const resetAll = 'resetAll';
  static const changes = 'changes';
  static const state = 'state';
  static const settings = 'settings';
}
