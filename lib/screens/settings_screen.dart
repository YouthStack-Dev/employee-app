import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../providers/time_format_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _tripReminderEnabled = false;
  bool _snoozeEnabled = false;

  double _reminderMins = 5;
  double _snoozeMins = 2;

  static const _royalBlue = FxColors.primary;
  static const _navy = FxColors.onSurface;
  static const _border = FxColors.surfaceContainerHigh;
  static const _pageBg = FxColors.background;

  String get _reminderLabel =>
      '${_reminderMins.round()} min${_reminderMins.round() == 1 ? '' : 's'}';
  String get _snoozeLabel =>
      '${_snoozeMins.round()} min${_snoozeMins.round() == 1 ? '' : 's'}';

  Future<void> _save() async {
    final is24 = context.read<TimeFormatProvider>().is24Hour;
    await context.read<TimeFormatProvider>().setFormat(is24Hour: is24);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Settings saved'),
          backgroundColor: _royalBlue,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1200),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: _navy),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Settings',
                    style: FxText.headlineLg(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                children: [
                  _settingsCard(
                    children: [
                      _toggleSection(
                        title: 'Trip Reminder',
                        value: _tripReminderEnabled,
                        onChanged: (v) => setState(() => _tripReminderEnabled = v),
                      ),
                      const SizedBox(height: 6),
                      _sliderRow(
                        value: _reminderMins,
                        max: 30,
                        label: _reminderLabel,
                        onChanged: (v) => setState(() => _reminderMins = v),
                      ),
                      const SizedBox(height: 30),
                      _toggleSection(
                        title: 'Snooze',
                        value: _snoozeEnabled,
                        onChanged: (v) => setState(() => _snoozeEnabled = v),
                      ),
                      const SizedBox(height: 6),
                      _sliderRow(
                        value: _snoozeMins,
                        max: 15,
                        label: _snoozeLabel,
                        onChanged: (v) => setState(() => _snoozeMins = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _settingsCard(
                    children: [
                      Text(
                        'Time Format',
                        style: FxText.headlineMd().copyWith(fontSize: 19),
                      ),
                      const SizedBox(height: 6),
                      _radioOption('12 Hour (AM/PM)', is24Hour: false),
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: FxColors.surfaceContainerHigh,
                        indent: 0,
                        endIndent: 8,
                      ),
                      _radioOption('24 Hours (00:00)', is24Hour: true),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: FxColors.surfaceContainerHigh, width: 1)),
          boxShadow: const [
            BoxShadow(
              color: FxColors.primaryContainer,
              blurRadius: 12,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(30, 14, 30, 16),
          child: SizedBox(
            height: 72,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _royalBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(48),
                ),
              ),
              child: Text(
                'Save Changes',
                style: FxText.headlineLg().copyWith(fontSize: 20, letterSpacing: 0.2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _settingsCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _toggleSection({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: FxText.headlineMd().copyWith(fontSize: 20),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: _royalBlue,
          activeThumbColor: Colors.white,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: FxColors.surfaceContainerHighest,
          trackOutlineColor: WidgetStatePropertyAll(Colors.transparent),
        ),
      ],
    );
  }

  Widget _sliderRow({
    required double value,
    required double max,
    required String label,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              activeTrackColor: _royalBlue,
              inactiveTrackColor: FxColors.surfaceContainerLow,
              thumbColor: _royalBlue,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 13),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
              overlayColor: FxColors.primary.withValues(alpha: 0.13),
              trackShape: const RoundedRectSliderTrackShape(),
            ),
            child: Slider(
              value: value,
              min: 1,
              max: max,
              divisions: max.round() - 1,
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 58,
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: FxText.headlineSm().copyWith(fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _radioOption(String label, {required bool is24Hour}) {
    final selected = context.watch<TimeFormatProvider>().is24Hour == is24Hour;
    return InkWell(
      onTap: () => context.read<TimeFormatProvider>().setFormat(is24Hour: is24Hour),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 26,
              color: selected ? _royalBlue : _border,
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: FxText.headlineMd(),
            ),
          ],
        ),
      ),
    );
  }
}