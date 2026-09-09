/// Route locations shared by features and the router.
abstract final class RoutePaths {
  static const configure = '/configure';
  static const login = '/login';

  /// Dashboard: the Home tab root.
  static const dashboard = '/app/home';
  static const home = dashboard;

  /// Tomogram module.
  static const tomogramEntry = '/app/tomogram';
  /// Digit-constrained so it cannot swallow the literal `permission` segment.
  static const tomogramPattern = r':opid(\d+)';
  static String tomogram(int opid) => '$tomogramEntry/$opid';
  static const permissionPattern = 'permission';
  static const permission = '$tomogramEntry/permission';

  static const settings = '/app/settings';
  static const aboutPattern = 'about';
  static const about = '$settings/about';
}
