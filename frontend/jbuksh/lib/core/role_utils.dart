class RoleUtils {
  static const superAdmin = 'SUPER_ADMIN';
  static const rsm = 'RSM';
  static const mpo = 'MPO';
  static const salesDept = 'SALES_DEPT';
  static const accounting = 'ACCOUNTING';
  static const stockKeeper = 'STOCK_KEEPER';

  static String normalize(String raw) {
    final role = raw.trim().toUpperCase();
    if (role == 'AREA_MANAGER') return rsm;
    if (role == 'SALES_DEPARTMENT') return salesDept;
    if (role == 'ACCOUNTING_DEPARTMENT') return accounting;
    return role;
  }

  static bool canAccess(String rawRole, Set<String> allowed) {
    final role = normalize(rawRole);
    if (role == superAdmin) return true;
    return allowed.contains(role);
  }
}
