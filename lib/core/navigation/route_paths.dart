/// Route locations shared by features and the router.
abstract final class RoutePaths {
  static const configure = '/configure';
  static const login = '/login';
  static const home = '/app/home';
  static const tomogramPattern = 'tomogram/:opid';
  static String tomogram(int opid) => '$home/tomogram/$opid';
  static const permissionPattern = 'permission';
  static const permission = '$home/permission';
  static const settings = '/app/settings';
  static const aboutPattern = 'about';
  static const about = '$settings/about';
}
