import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import '../models/user_model.dart';
import '../widgets/fx_widgets.dart';

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

  String _displayValue(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? '—' : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final tenantName = user?.tenantName ?? user?.tenantId ?? '';
    final employeeId = _field('employee_code', user?.employeeId?.toString());
    final phone = user?.phone;
    final email = user?.email;
    final office = _field('office', tenantName);
    final teamName = _field('team_name', _field('team_id', null));
    final name = _displayValue(user?.name);

    final details = <_DetailField>[
      _DetailField(
        label: 'Employee ID',
        value: _displayValue(employeeId),
        icon: Icons.badge_outlined,
      ),
      _DetailField(
        label: 'Mobile Number',
        value: _displayValue(phone),
        icon: Icons.phone_outlined,
      ),
      _DetailField(
        label: 'Email ID',
        value: _displayValue(email),
        icon: Icons.mail_outline,
      ),
      _DetailField(
        label: 'Office',
        value: _displayValue(office),
        icon: Icons.business_outlined,
      ),
      _DetailField(
        label: 'Team Name',
        value: _displayValue(teamName),
        icon: Icons.groups_outlined,
      ),
    ];

    final detailRows = <Widget>[];
    for (var i = 0; i < details.length; i++) {
      if (i > 0) {
        detailRows.add(const Divider(
          height: 1,
          thickness: 1,
          color: FxColors.surfaceContainer,
          indent: 46,
        ));
      }
      detailRows.add(details[i]);
    }

    return Scaffold(
      backgroundColor: FxColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: FxColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: FxColors.surfaceContainer),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: FxColors.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Personal Details',
                      style: FxText.headlineLg().copyWith(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  Center(
                    child: Container(
                      width: 92,
                      height: 92,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: FxColors.primary.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: FxColors.primaryContainer.withValues(alpha: 0.45),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        _initials,
                        style: FxText.headlineLg().copyWith(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: FxColors.primary,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: FxText.headlineLg().copyWith(
                      fontSize: 27,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FxCard(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Details',
                          style: FxText.headlineMd().copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...detailRows,
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
  final IconData icon;

  const _DetailField({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: FxColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              size: 18,
              color: FxColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: FxText.body(color: FxColors.onSurfaceVariant).copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: FxText.bodyLg(color: FxColors.onSurface).copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
