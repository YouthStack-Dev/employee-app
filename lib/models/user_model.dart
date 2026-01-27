class User {
  final int? employeeId;
  final String? username;
  final String? tenantId;
  final String? role;
  final String? name;
  final String? email;

  User({this.employeeId, this.username, this.tenantId, this.role, this.name, this.email});

  factory User.fromJson(Map<String, dynamic> json) {
    // Navigate nested structure if needed based on API response
    // Example: based on authService.js, user data is in res.data.data.user
    final user = json['user'];
    final employee = user?['employee'];
    
    return User(
      employeeId: employee?['employee_id'],
      username: user?['username'],
      tenantId: user?['tenant_id'],
      role: (user?['roles'] as List?)?.isNotEmpty == true ? user!['roles'][0] : null,
      name: employee?['name'],
      email: employee?['email'],
    );
  }
}
