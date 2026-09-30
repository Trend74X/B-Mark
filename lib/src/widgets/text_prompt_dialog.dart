import 'package:flutter/material.dart';

/// A small text-entry dialog that owns its own [TextEditingController].
///
/// Disposing a controller while the dialog's exit animation is still running
/// trips Flutter's `_dependents.isEmpty` assertion in
/// `InheritedElement.debugDeactivated`, because the TextField still has live
/// InheritedWidget dependencies at that point. Letting the dialog State own
/// the controller guarantees it is disposed only after the subtree unmounts.
class TextPromptDialog extends StatefulWidget {
  const TextPromptDialog({
    super.key,
    required this.title,
    required this.label,
    this.initialText = '',
    this.hintText,
    this.confirmLabel = 'Add',
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
    this.autofocus = true,
  });

  final String title;
  final String label;
  final String initialText;
  final String? hintText;
  final String confirmLabel;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool autofocus;

  @override
  State<TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<TextPromptDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    if (widget.initialText.isNotEmpty) {
      // Select the existing text so typing replaces it immediately.
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.initialText.length,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: widget.autofocus,
        keyboardType: widget.keyboardType,
        textCapitalization: widget.textCapitalization,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hintText,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}