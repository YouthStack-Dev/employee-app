class User {
  final int? employeeId;
  final String? username;
  final String? tenantId;
  final String? role;
  final String? name;
  final String? email;
  final String? phone;
  final String? address;
  final String? department;
  final String? designation;
  final String? gender;
  final String? tenantName;
  final double? latitude;
  final double? longitude;
  final Map<String, dynamic>? rawEmployeeData;

  User({
    this.employeeId,
    this.username,
    this.tenantId,
    this.role,
    this.name,
    this.email,
    this.phone,
    this.address,
    this.department,
    this.designation,
    this.gender,
    this.tenantName,
    this.latitude,
    this.longitude,
    this.rawEmployeeData,
  });

  /// True when the employee's profile gender is female (case-insensitive).
  bool get isFemale => (gender ?? '').trim().toLowerCase() == 'female';

  factory User.fromJson(Map<String, dynamic> json) {
    // Navigate nested structure if needed based on API response
    final user = json['user'];
    final employee = user?['employee'];
    
    return User(
      employeeId: employee?['employee_id'],
      username: user?['username'],
      tenantId: user?['tenant_id'] ?? employee?['tenant_id'],
      role: (user?['roles'] as List?)?.isNotEmpty == true ? user!['roles'][0] : null,
      name: employee?['name'],
      email: employee?['email'],
      phone: employee?['contact_number'] ?? employee?['phone_number'] ?? employee?['phone'],
      address: employee?['address'] ?? employee?['home_address'],
      department: employee?['department'],
      designation: employee?['designation'],
      gender: employee?['gender']?.toString(),
      tenantName: (user?['tenant'] as Map?)?['name']?.toString(),
      latitude: _toDouble(employee?['latitude'] ?? user?['tenant']?['latitude']),
      longitude: _toDouble(employee?['longitude'] ?? user?['tenant']?['longitude']),
      rawEmployeeData: employee is Map<String, dynamic> ? employee : null,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    final parsed = double.tryParse(value.toString());
    return parsed;
  }
}
