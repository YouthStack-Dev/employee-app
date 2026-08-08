import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import '../services/connectivity_service.dart';

/// A persistent banner that appears at the top when offline.
/// Wraps the app's scaffold body — place it high in the widget tree.
class ConnectivityBanner extends StatelessWidget {
  final Widget child;
  const ConnectivityBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ConnectivityService(),
      builder: (context, _) {
        final service = ConnectivityService();
        return Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: service.isOnline ? 0 : null,
              child: service.isOnline
                  ? const SizedBox.shrink()
                  : MaterialBanner(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      backgroundColor: FxColors.error.withOpacity(0.95),
                      content: Row(
                        children: [
                          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'No Internet Connection',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  service.statusMessage,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => service.checkConnectivity(),
                          child: const Text('RETRY', style: TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ],
                    ),
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

/// A full-screen error state with retry button — use inside screens
/// when a critical load fails.
class FxErrorView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  const FxErrorView({
    super.key,
    this.title = 'Something went wrong',
    this.message = 'Please check your internet connection and try again.',
    this.onRetry,
    this.icon = Icons.cloud_off_rounded,
  });

  factory FxErrorView.noInternet({VoidCallback? onRetry}) {
    return FxErrorView(
      title: 'No Internet',
      message: 'Your device is connected to WiFi but there\'s no internet access. Please check your router or try mobile data.',
      icon: Icons.wifi_off_rounded,
      onRetry: onRetry,
    );
  }

  factory FxErrorView.timeout({VoidCallback? onRetry}) {
    return FxErrorView(
      title: 'Connection Timeout',
      message: 'The server is taking too long to respond. Please try again in a moment.',
      icon: Icons.hourglass_empty_rounded,
      onRetry: onRetry,
    );
  }

  factory FxErrorView.serverError({VoidCallback? onRetry}) {
    return FxErrorView(
      title: 'Server Error',
      message: 'Our servers are experiencing issues. Please try again later.',
      icon: Icons.error_outline_rounded,
      onRetry: onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: FxColors.errorContainer.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: FxColors.error),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: FxColors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: FxColors.onSurfaceVariant,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FxColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Inline error message with retry — for use inside lists/cards
class FxInlineError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const FxInlineError({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: FxColors.error.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FxColors.error.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: FxColors.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: FxColors.error, height: 1.3),
            ),
          ),
          if (onRetry != null)
            IconButton(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              color: FxColors.error,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
        ],
      ),
    );
  }
}

/// A smart snackbar helper that shows appropriate messages
class FxSnackbar {
  static void showError(BuildContext context, String message, {VoidCallback? onRetry}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
        backgroundColor: FxColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        action: onRetry != null
            ? SnackBarAction(
                label: 'RETRY',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
        backgroundColor: FxColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void showNoInternet(BuildContext context, {VoidCallback? onRetry}) {
    showError(
      context,
      'No internet connection. Please check your WiFi or mobile data.',
      onRetry: onRetry,
    );
  }

  static void showTimeout(BuildContext context, {VoidCallback? onRetry}) {
    showError(
      context,
      'Request timed out. Please try again.',
      onRetry: onRetry,
    );
  }
}
