import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import '../models/user_model.dart';

class PersonalDetailsScreen extends StatelessWidget {
  final User? user;

  const PersonalDetailsScreen({super.key, this.user});

  String get _initials {
    final raw = (user?.name ?? 'E').trim();
    if (raw.isEmpty) return 'E';
    final parts = raw.split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'E';
    return parts.take(2).map((s) => s[0].toUpperCase()).join();
  }

  String? _field(String key, String? fallback) {
    final raw = user?.rawEmployeeData;
    if (raw == null) return fallback;
    final v = raw[key];
    if (v == null || v.toString().isEmpty) return fallback;
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final tenantName = user?.tenantName ?? user?.tenantId ?? '';
    final employeeId = _field('employee_code', user?.employeeId?.toString());
    final phone = user?.phone;
    final email = user?.email;
    final office = _field('office', tenantName);
    final teamName = _field('team_name', _field('team_id', null));

    final rows = <Widget>[];
    void addRow(String label, String? value) {
      if (value == null || value.isEmpty) return;
      rows.add(_DetailField(label: label, value: value));
    }

    addRow('Employee ID', employeeId);
    addRow('Mobile Number', phone);
    addRow('Email ID', email);
    addRow('Office', office);
    addRow('Team Name', teamName);

    return Scaffold(
      backgroundColor: FxColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: FxColors.onSurface),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Personal Details',
                    style: FxText.headlineLg(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
                children: [
                  Center(
                    child: Container(
                      width: 110,
                      height: 110,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: FxColors.surfaceContainerLow,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        _initials,
                        style: FxText.displaySm().copyWith(fontSize: 44, fontWeight: FontWeight.w600, color: FxColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    (user?.name ?? '').toUpperCase(),
                    textAlign: TextAlign.center,
                    style: FxText.headlineLg().copyWith(fontSize: 32, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 34),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: FxColors.surfaceContainerLow),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Details',
                          style: FxText.headlineMd(),
                        ),
                        const SizedBox(height: 20),
                        ...rows,
                        if (rows.isEmpty)
                          Text(
                            'No details available',
                            style: FxText.bodySm(),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailField extends StatelessWidget {
  final String label;
  final String value;

  const _DetailField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: FxText.body(color: FxColors.onSurfaceVariant).copyWith(fontSize: 14),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: FxText.headlineMd(),
          ),
        ],
      ),
    );
  }
}