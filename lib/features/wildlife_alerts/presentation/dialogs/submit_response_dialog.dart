import 'package:flutter/material.dart';
import '../../domain/models/wildlife_alert.dart';

class SubmitResponseDialog extends StatefulWidget {
  const SubmitResponseDialog({
    required this.alert,
    required this.rangerId,
    this.rangerName,
    super.key,
  });

  final WildlifeAlert alert;
  final String rangerId;
  final String? rangerName;

  @override
  State<SubmitResponseDialog> createState() => _SubmitResponseDialogState();
}

class _SubmitResponseDialogState extends State<SubmitResponseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _actionController = TextEditingController();
  final _observationsController = TextEditingController();
  bool _followUpRequired = false;

  final List<String> _quickActionTemplates = [
    'Dispatched mobile patrol unit to sweep sector.',
    'Repelled elephant herd back across buffer boundary.',
    'Dismantled illegal wire snares and documented footprints.',
    'Veterinary team treated minor wound; animal stable.',
    'Conducted perimeter drone surveillance sweep.',
  ];

  @override
  void dispose() {
    _actionController.dispose();
    _observationsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.verified, color: Color(0xFF17613F)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Submit Response & Resolve Alert',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 500,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Alert ID: ${widget.alert.alertId}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Text(
                  widget.alert.title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const Divider(height: 24),

                // Quick action templates
                const Text(
                  'Quick Action Presets:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _quickActionTemplates.map((template) {
                    return ActionChip(
                      label: Text(
                        template.length > 32
                            ? '${template.substring(0, 32)}...'
                            : template,
                        style: const TextStyle(fontSize: 10),
                      ),
                      onPressed: () {
                        setState(() {
                          _actionController.text = template;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _actionController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Action Taken *',
                    hintText: 'e.g. Dispatched squad, mobilized vet, checked snares...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter the response action taken.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _observationsController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Field Observations & Wildlife Status *',
                    hintText: 'e.g. Animal moved unharmed toward northern valley...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please describe the field observations.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),

                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _followUpRequired,
                  onChanged: (val) =>
                      setState(() => _followUpRequired = val ?? false),
                  title: const Text(
                    'Requires Follow-Up Monitoring',
                    style: TextStyle(fontSize: 13),
                  ),
                  subtitle: const Text(
                    'Schedule subsequent check on this animal or sensor',
                    style: TextStyle(fontSize: 11),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF17613F),
          ),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop({
                'actionTaken': _actionController.text.trim(),
                'observations': _observationsController.text.trim(),
                'followUpRequired': _followUpRequired,
              });
            }
          },
          icon: const Icon(Icons.done_all, size: 18),
          label: const Text('Confirm Resolution'),
        ),
      ],
    );
  }
}
