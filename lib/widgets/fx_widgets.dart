import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/app_theme.dart';

/// Soft elevated card — surfaceContainerLowest with branded soft shadow.
class FxCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final BorderRadius borderRadius;
  final bool showShadow;
  final Border? border;
  final VoidCallback? onTap;

  const FxCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.color,
    this.borderRadius = FxRadii.card,
    this.showShadow = true,
    this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inner = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? FxColors.surfaceContainerLowest,
        borderRadius: borderRadius,
        boxShadow: showShadow ? FxShadows.soft : null,
        border: border,
      ),
      child: child,
    );

    return Container(
      margin: margin,
      child: onTap == null
          ? inner
          : Material(
              color: Colors.transparent,
              borderRadius: borderRadius,
              child: InkWell(
                borderRadius: borderRadius,
                onTap: onTap,
                child: inner,
              ),
            ),
    );
  }
}

/// Tonal-shift card (no shadow) — surfaceContainerLow.
/// Used for grouped content where shadows would be too heavy.
class FxTonalCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;

  const FxTonalCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.color,
    this.borderRadius = FxRadii.card,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FxCard(
      padding: padding,
      margin: margin,
      color: color ?? FxColors.surfaceContainerLow,
      borderRadius: borderRadius,
      showShadow: false,
      onTap: onTap,
      child: child,
    );
  }
}

/// Primary CTA button with the indigo gradient + soft branded shadow.
class FxPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? trailingIcon;
  final IconData? leadingIcon;
  final VoidCallback? onPressed;
  final bool loading;
  final double height;
  final double radius;

  const FxPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.trailingIcon,
    this.leadingIcon,
    this.loading = false,
    this.height = 56,
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 120),
      opacity: enabled ? 1 : 0.6,
      child: GestureDetector(
        onTap: enabled ? onPressed : null,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            gradient: FxGradients.indigo,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: FxShadows.button,
          ),
          alignment: Alignment.center,
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: FxColors.onPrimary),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (leadingIcon != null) ...[
                      Icon(leadingIcon, color: FxColors.onPrimary, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(label, style: FxText.title(color: FxColors.onPrimary)),
                    if (trailingIcon != null) ...[
                      const SizedBox(width: 8),
                      Icon(trailingIcon, color: FxColors.onPrimary, size: 18),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// Secondary button — `surfaceContainerHigh` background, primary text. No border.
class FxSecondaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color? background;
  final Color? foreground;
  final double height;

  const FxSecondaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.background,
    this.foreground,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? FxColors.primary;
    return Material(
      color: background ?? FxColors.surfaceContainerLowest,
      borderRadius: FxRadii.button,
      child: InkWell(
        borderRadius: FxRadii.button,
        onTap: onPressed,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: fg, size: 16),
                const SizedBox(width: 6),
              ],
              Text(label, style: FxText.titleSm(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// "SOS" red pill button used in headers.
class FxSosButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  const FxSosButton({super.key, this.onPressed, this.label = 'SOS'});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: FxColors.error,
          borderRadius: BorderRadius.circular(14),
          boxShadow: FxShadows.sosButton,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emergency_rounded, color: FxColors.onError, size: 16),
            const SizedBox(width: 6),
            Text(label, style: FxText.titleSm(color: FxColors.onError)),
          ],
        ),
      ),
    );
  }
}

/// Glassmorphic header — translucent surface with backdrop blur.
class FxGlassHeader extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const FxGlassHeader({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding.copyWith(top: padding.top + MediaQuery.of(context).padding.top),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x99F5F7FA), Colors.transparent],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Lightweight pill used for status badges, count chips, etc.
class FxPill extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;
  final IconData? icon;
  final bool pulse;

  const FxPill({
    super.key,
    required this.text,
    this.color = FxColors.primary,
    this.background = const Color(0x1A4C40DF),
    this.icon,
    this.pulse = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: FxRadii.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pulse) ...[
            _PulsingDot(color: color),
            const SizedBox(width: 6),
          ] else if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(text, style: FxText.titleSm(color: color)),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1).animate(_ctrl),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

/// All-caps small label used everywhere as metadata.
class FxMetaLabel extends StatelessWidget {
  final String text;
  final Color? color;
  const FxMetaLabel(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: FxText.labelSm(color: color ?? FxColors.onSurfaceVariant),
    );
  }
}

/// Vertical timeline used for pickup → drop visualisation.
class FxRouteTimeline extends StatelessWidget {
  final String pickup;
  final String drop;
  final String pickupLabel;
  final String dropLabel;
  final bool isActive;

  const FxRouteTimeline({
    super.key,
    required this.pickup,
    required this.drop,
    this.pickupLabel = 'Pickup',
    this.dropLabel = 'Drop-off',
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isActive ? FxColors.primary : FxColors.onSurfaceVariant;
    return Stack(
      children: [
        Positioned(
          left: 5,
          top: 16,
          bottom: 36,
          child: Container(
            width: 2,
            color: activeColor.withOpacity(isActive ? 0.3 : 0.12),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4, right: 14),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive ? FxColors.primary : Colors.transparent,
                    border: Border.all(color: activeColor, width: 2),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pickup, style: FxText.titleSm()),
                      Text(pickupLabel, style: FxText.bodySm()),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4, right: 14),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: activeColor, width: 2),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(drop, style: FxText.titleSm()),
                      Text(dropLabel, style: FxText.bodySm()),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// Segmented toggle (two options) — surfaceContainerLow background, white pill
/// for the selected option.
class FxSegmented extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  const FxSegmented({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: FxColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = i == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? FxColors.surfaceContainerLowest : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: selected ? FxShadows.soft : null,
                ),
                child: Center(
                  child: Text(
                    labels[i],
                    style: FxText.titleSm(
                      color: selected ? FxColors.primary : FxColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Tonal input field — surfaceContainerLow background, no border.
class FxTextField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hint;
  final String? label;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final bool obscure;
  final TextInputType? keyboardType;
  final int? maxLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final VoidCallback? onTap;
  final String? errorText;

  const FxTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hint,
    this.label,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.obscure = false,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.onChanged,
    this.readOnly = false,
    this.onTap,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: FxMetaLabel(label!),
          ),
        ],
        Container(
          decoration: BoxDecoration(
            color: errorText != null ? FxColors.onError : FxColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: errorText != null ? FxColors.error.withOpacity(0.5) : Colors.transparent,
            ),
          ),
          child: TextField(
            focusNode: focusNode,
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            maxLines: obscure ? 1 : maxLines,
            maxLength: maxLength,
            readOnly: readOnly,
            onTap: onTap,
            onChanged: onChanged,
            style: FxText.bodyLg(),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: FxText.bodyLg(color: FxColors.outline),
              filled: false,
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: prefixIcon != null ? 0 : 18,
                vertical: 18,
              ),
              prefixIcon: prefixIcon != null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Icon(prefixIcon, color: FxColors.onSurfaceVariant, size: 20),
                    )
                  : null,
              prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 0),
              suffixIcon: suffixIcon != null
                  ? GestureDetector(
                      onTap: onSuffixTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Icon(suffixIcon, color: FxColors.onSurfaceVariant, size: 20),
                      ),
                    )
                  : null,
              counterText: '',
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text(errorText!,
                style: FxText.bodySm(color: FxColors.error).copyWith(fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}

/// Floating bottom nav (4 items) used on the dashboard / main flows.
class FxBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<FxBottomNavItem> items;
  const FxBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: FxColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: FxShadows.bottomNav,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final selected = i == currentIndex;
          final item = items[i];
          return GestureDetector(
            onTap: () => onTap(i),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? FxColors.surfaceContainerLow : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.icon,
                    color: selected ? FxColors.primary : FxColors.outline,
                    size: 22,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    style: FxText.labelSm(
                      color: selected ? FxColors.primary : FxColors.outline,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class FxBottomNavItem {
  final IconData icon;
  final String label;
  const FxBottomNavItem(this.icon, this.label);
}
