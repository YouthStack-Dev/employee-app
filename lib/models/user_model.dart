class User {
  final int? employeeId;
  final String? username;
  final String? tenantId;
  final String? role;
  final String? name;
  final String? email;
  final String? phone;
  final String? department;
  final String? designation;
  final Map<String, dynamic>? rawEmployeeData;

  User({
    this.employeeId, 
    this.username, 
    this.tenantId, 
    this.role, 
    this.name, 
    this.email,
    this.phone,
    this.department,
    this.designation,
    this.rawEmployeeData,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Navigate nested structure if needed based on API response
    final user = json['user'];
    final employee = user?['employee'];
    
    return User(
      employeeId: employee?['employee_id'],
      username: user?['username'],
      tenantId: user?['tenant_id'],
      role: (user?['roles'] as List?)?.isNotEmpty == true ? user!['roles'][0] : null,
      name: employee?['name'],
      email: employee?['email'],
      phone: employee?['contact_number'] ?? employee?['phone_number'] ?? employee?['phone'],
      department: employee?['department'],
      designation: employee?['designation'],
      rawEmployeeData: employee is Map<String, dynamic> ? employee : null,
    );
  }
}
