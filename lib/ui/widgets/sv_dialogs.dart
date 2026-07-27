import 'package:flutter/cupertino.dart';

/// Cupertino alert with Cancel + one action. Returns true only on confirm.
Future<bool> showSvConfirm(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'OK',
  bool destructive = false,
}) async {
  final confirmed = await showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: destructive,
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        CupertinoDialogAction(
          isDefaultAction: !destructive,
          isDestructiveAction: destructive,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Cupertino text-entry dialog. Returns the trimmed text, or null on cancel.
Future<String?> showSvTextInput(
  BuildContext context, {
  required String title,
  String? message,
  String? placeholder,
  String initial = '',
  String confirmLabel = 'Save',
}) {
  final controller = TextEditingController(text: initial);
  return showCupertinoDialog<String>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message != null) ...[Text(message), const SizedBox(height: 4)],
          const SizedBox(height: 10),
          CupertinoTextField(
            controller: controller,
            autofocus: true,
            placeholder: placeholder,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
          ),
        ],
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(ctx).pop(null),
          child: const Text('Cancel'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          child: Text(confirmLabel),
        ),
      ],
    ),
  ).whenComplete(() {
    // The route is gone by the time this runs; nothing references it now.
    controller.dispose();
  });
}
