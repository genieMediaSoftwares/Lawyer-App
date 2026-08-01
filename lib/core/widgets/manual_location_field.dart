import 'package:flutter/material.dart';

/// A plain, free-text location/address input.
///
/// **Deliberately has no autocomplete, no dropdown, no API calls and no
/// suggestion list.** The user types whatever they want and that string is the
/// value. This is the field to use on the *profile* screens (client and
/// lawyer), where a person's address is free-form and may be a street, a
/// building name, or anything else a places API would refuse to match.
///
/// This is the counterpart to [LocationAutocompleteField], which *is*
/// suggestion-driven and is used only on the Post-a-Case flow, where the
/// location has to resolve to a real city so cases can be matched to advocates
/// by jurisdiction.
///
/// The two are intentionally separate widgets in separate files with no shared
/// state or providers, so changing one cannot alter the behaviour of the other:
///
/// | Widget                      | Used by                    | Behaviour            |
/// |-----------------------------|----------------------------|----------------------|
/// | `ManualLocationField`       | Client + Lawyer profiles   | Free text only       |
/// | `LocationAutocompleteField` | Post Your Case only        | Live API suggestions |
class ManualLocationField extends StatelessWidget {
  final TextEditingController controller;

  final String labelText;
  final String? hintText;

  /// Optional trailing widget. Note this is *decoration only* — it must not be
  /// wired to a picker or sheet, or this field stops being manual input.
  final Widget? suffixIcon;

  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  /// Addresses are often more than one line; allow the field to grow.
  final int maxLines;

  final TextInputAction textInputAction;

  const ManualLocationField({
    super.key,
    required this.controller,
    this.labelText = 'Address / Location',
    this.hintText = 'Type your address or city',
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.enabled = true,
    this.maxLines = 2,
    this.textInputAction = TextInputAction.next,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      validator: validator,
      onChanged: onChanged,
      maxLines: maxLines,
      minLines: 1,
      textInputAction: textInputAction,
      keyboardType: TextInputType.streetAddress,
      textCapitalization: TextCapitalization.words,
      // Colours, borders and fills all come from the app's
      // InputDecorationTheme so this matches every other field automatically.
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        suffixIcon: suffixIcon,
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }
}
