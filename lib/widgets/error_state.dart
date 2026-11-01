import 'dart:async';

import 'package:flutter/material.dart';

import 'loading_dots.dart';

/// Экран ошибки загрузки: сообщение и кнопка «Повторить».
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final String? secondaryActionText;
  final VoidCallback? onSecondaryAction;

  const ErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.secondaryActionText,
    this.onSecondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Повторить'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green,
              side: const BorderSide(color: Colors.green),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
            ),
          ),
          if (secondaryActionText != null && onSecondaryAction != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onSecondaryAction,
              child: Text(secondaryActionText!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Пустое состояние списка: иконка, заголовок и опциональное действие.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionText;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 72,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: Text(actionText!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Лоадер с таймаутом: если загрузка не уложилась в [timeout],
/// показывает ErrorState с «Повторить» вместо вечного LoadingDots.
class LoadingError extends StatefulWidget {
  final bool loading;
  final String message;
  final VoidCallback onRetry;
  final Duration timeout;

  const LoadingError({
    super.key,
    required this.loading,
    required this.message,
    required this.onRetry,
    this.timeout = const Duration(seconds: 20),
  });

  @override
  State<LoadingError> createState() => _LoadingErrorState();
}

class _LoadingErrorState extends State<LoadingError> {
  Timer? _timer;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    if (widget.loading) _startTimer();
  }

  @override
  void didUpdateWidget(LoadingError oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loading && !oldWidget.loading) {
      _timedOut = false;
      _startTimer();
    } else if (!widget.loading && oldWidget.loading) {
      _timer?.cancel();
      _timedOut = false;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(widget.timeout, () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  void _handleRetry() {
    setState(() {
      _timedOut = false;
    });
    if (widget.loading) {
      _startTimer();
    }
    widget.onRetry();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading && !_timedOut) {
      return const Center(child: LoadingDots());
    }
    return ErrorState(message: widget.message, onRetry: _handleRetry);
  }
}
