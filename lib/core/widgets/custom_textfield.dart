// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import '../constants/app_colors.dart';
//
// // ─────────────────────────────────────────────────────────────────────────────
// // CustomTextField
// //
// // A fully composable text input for the Genie Law App.
// // Supports: label, hint, prefix/suffix icons, password toggle,
// // character counter, phone prefix, OTP mode, search mode,
// // multi-line (textarea), validation, read-only, and loading states.
// // Built on Material 3 — inherits InputDecorationTheme from ThemeData.
// // ─────────────────────────────────────────────────────────────────────────────
//
// enum TextFieldVariant { standard, search, otp, textarea }
//
// class CustomTextField extends StatefulWidget {
//   const CustomTextField({
//     super.key,
//     this.label,
//     this.hint,
//     this.controller,
//     this.focusNode,
//     this.onChanged,
//     this.onSubmitted,
//     this.onTap,
//     this.validator,
//     this.initialValue,
//     this.variant = TextFieldVariant.standard,
//     this.keyboardType,
//     this.textInputAction,
//     this.inputFormatters,
//     this.prefixIcon,
//     this.suffixIcon,
//     this.suffixWidget,
//     this.prefixText,
//     this.isPassword = false,
//     this.isReadOnly = false,
//     this.isEnabled = true,
//     this.isRequired = false,
//     this.autofocus = false,
//     this.maxLines = 1,
//     this.minLines,
//     this.maxLength,
//     this.showCounter = false,
//     this.helperText,
//     this.fillColor,
//     this.borderRadius,
//     this.textCapitalization = TextCapitalization.none,
//     this.autocorrect = true,
//     this.autofillHints,
//   });
//
//   final String? label;
//   final String? hint;
//   final TextEditingController? controller;
//   final FocusNode? focusNode;
//   final ValueChanged<String>? onChanged;
//   final ValueChanged<String>? onSubmitted;
//   final VoidCallback? onTap;
//   final FormFieldValidator<String>? validator;
//   final String? initialValue;
//   final TextFieldVariant variant;
//   final TextInputType? keyboardType;
//   final TextInputAction? textInputAction;
//   final List<TextInputFormatter>? inputFormatters;
//   final IconData? prefixIcon;
//   final IconData? suffixIcon;
//   final Widget? suffixWidget;
//   final String? prefixText;
//   final bool isPassword;
//   final bool isReadOnly;
//   final bool isEnabled;
//   final bool isRequired;
//   final bool autofocus;
//   final int maxLines;
//   final int? minLines;
//   final int? maxLength;
//   final bool showCounter;
//   final String? helperText;
//   final Color? fillColor;
//   final double? borderRadius;
//   final TextCapitalization textCapitalization;
//   final bool autocorrect;
//   final Iterable<String>? autofillHints;
//
//   @override
//   State<CustomTextField> createState() => _CustomTextFieldState();
// }
//
// class _CustomTextFieldState extends State<CustomTextField> {
//   bool _obscure = true;
//   late FocusNode _focusNode;
//   bool _hasFocus = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _focusNode = widget.focusNode ?? FocusNode();
//     _focusNode.addListener(_onFocusChange);
//   }
//
//   @override
//   void dispose() {
//     if (widget.focusNode == null) _focusNode.dispose();
//     _focusNode.removeListener(_onFocusChange);
//     super.dispose();
//   }
//
//   void _onFocusChange() {
//     setState(() => _hasFocus = _focusNode.hasFocus);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (widget.variant == TextFieldVariant.otp) {
//       return _OtpField(
//         length: widget.maxLength ?? 6,
//         onCompleted: widget.onSubmitted,
//         onChanged: widget.onChanged,
//         isEnabled: widget.isEnabled,
//       );
//     }
//
//     return widget.variant == TextFieldVariant.standard ||
//         widget.variant == TextFieldVariant.textarea
//         ? _buildFormField(context)
//         : _buildSearchField(context);
//   }
//
//   Widget _buildFormField(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     final labelText = widget.isRequired && widget.label != null
//         ? widget.label! // asterisk added via labelText below
//         : widget.label;
//
//     return TextFormField(
//       controller: widget.controller,
//       focusNode: _focusNode,
//       initialValue:
//       widget.controller == null ? widget.initialValue : null,
//       onChanged: widget.onChanged,
//       onFieldSubmitted: widget.onSubmitted,
//       onTap: widget.onTap,
//       validator: widget.validator,
//       keyboardType: widget.variant == TextFieldVariant.textarea
//           ? TextInputType.multiline
//           : widget.keyboardType,
//       textInputAction: widget.variant == TextFieldVariant.textarea
//           ? TextInputAction.newline
//           : widget.textInputAction,
//       inputFormatters: widget.inputFormatters,
//       obscureText: widget.isPassword && _obscure,
//       readOnly: widget.isReadOnly,
//       enabled: widget.isEnabled,
//       autofocus: widget.autofocus,
//       maxLines: widget.isPassword ? 1 : widget.maxLines,
//       minLines: widget.minLines,
//       maxLength: widget.maxLength,
//       buildCounter: widget.showCounter ? null : (_,
//           {required currentLength,
//             required isFocused,
//             maxLength}) =>
//       null,
//       textCapitalization: widget.textCapitalization,
//       autocorrect: widget.autocorrect,
//       autofillHints: widget.autofillHints,
//       style: Theme.of(context).textTheme.bodyLarge?.copyWith(
//         color: widget.isReadOnly
//             ? cs.onSurface.withOpacity(0.6)
//             : cs.onSurface,
//         fontSize: 15,
//       ),
//       decoration: _buildDecoration(context, cs, labelText),
//     );
//   }
//
//   InputDecoration _buildDecoration(
//       BuildContext context, ColorScheme cs, String? label) {
//     final radius = widget.borderRadius ?? 12.0;
//     final fill = widget.fillColor ??
//         (Theme.of(context).brightness == Brightness.light
//             ? AppColors.lightSurfaceVariant
//             : AppColors.darkSurfaceVariant);
//
//     return InputDecoration(
//       labelText: widget.isRequired && label != null ? '$label *' : label,
//       labelStyle: TextStyle(
//         fontSize: 14,
//         fontWeight: FontWeight.w500,
//         color: _hasFocus ? cs.primary : cs.onSurfaceVariant,
//       ),
//       hintText: widget.hint,
//       hintStyle: TextStyle(
//         fontSize: 14,
//         color: cs.onSurfaceVariant.withOpacity(0.55),
//       ),
//       helperText: widget.helperText,
//       helperStyle: TextStyle(
//         fontSize: 12,
//         color: cs.onSurfaceVariant.withOpacity(0.7),
//       ),
//       prefixIcon: widget.prefixIcon != null
//           ? Icon(
//         widget.prefixIcon,
//         size: 20,
//         color: _hasFocus ? cs.primary : cs.onSurfaceVariant,
//       )
//           : null,
//       prefixText: widget.prefixText,
//       prefixStyle: TextStyle(
//         fontSize: 15,
//         fontWeight: FontWeight.w500,
//         color: cs.onSurface,
//       ),
//       suffixIcon: _buildSuffix(cs),
//       filled: true,
//       fillColor: widget.isEnabled
//           ? fill
//           : cs.onSurface.withOpacity(0.04),
//       contentPadding: widget.prefixIcon != null
//           ? const EdgeInsets.symmetric(horizontal: 16, vertical: 16)
//           : const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
//       border: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(radius),
//         borderSide: BorderSide(color: cs.outline, width: 1),
//       ),
//       enabledBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(radius),
//         borderSide: BorderSide(color: cs.outline, width: 1),
//       ),
//       focusedBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(radius),
//         borderSide: BorderSide(color: cs.primary, width: 1.8),
//       ),
//       errorBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(radius),
//         borderSide: BorderSide(color: cs.error, width: 1.5),
//       ),
//       focusedErrorBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(radius),
//         borderSide: BorderSide(color: cs.error, width: 1.8),
//       ),
//       disabledBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(radius),
//         borderSide:
//         BorderSide(color: cs.outline.withOpacity(0.4), width: 1),
//       ),
//       errorStyle: TextStyle(fontSize: 12, color: cs.error),
//       isDense: false,
//     );
//   }
//
//   Widget? _buildSuffix(ColorScheme cs) {
//     if (widget.isPassword) {
//       return GestureDetector(
//         onTap: () => setState(() => _obscure = !_obscure),
//         child: Icon(
//           _obscure
//               ? Icons.visibility_outlined
//               : Icons.visibility_off_outlined,
//           size: 20,
//           color: cs.onSurfaceVariant,
//         ),
//       );
//     }
//     if (widget.suffixWidget != null) return widget.suffixWidget;
//     if (widget.suffixIcon != null) {
//       return Icon(widget.suffixIcon, size: 20, color: cs.onSurfaceVariant);
//     }
//     return null;
//   }
//
//   Widget _buildSearchField(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     final isDark = Theme.of(context).brightness == Brightness.dark;
//
//     return TextFormField(
//       controller: widget.controller,
//       focusNode: _focusNode,
//       onChanged: widget.onChanged,
//       onFieldSubmitted: widget.onSubmitted,
//       onTap: widget.onTap,
//       keyboardType: TextInputType.text,
//       textInputAction: TextInputAction.search,
//       style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 15),
//       decoration: InputDecoration(
//         hintText: widget.hint ?? 'Search…',
//         hintStyle: TextStyle(
//           fontSize: 14,
//           color: cs.onSurfaceVariant.withOpacity(0.6),
//         ),
//         prefixIcon: Icon(
//           Icons.search_rounded,
//           size: 20,
//           color: _hasFocus ? cs.primary : cs.onSurfaceVariant,
//         ),
//         suffixIcon: widget.controller?.text.isNotEmpty == true
//             ? GestureDetector(
//           onTap: () {
//             widget.controller?.clear();
//             widget.onChanged?.call('');
//           },
//           child: Icon(
//             Icons.close_rounded,
//             size: 18,
//             color: cs.onSurfaceVariant,
//           ),
//         )
//             : null,
//         filled: true,
//         fillColor: isDark
//             ? AppColors.darkSurfaceVariant
//             : AppColors.lightSurfaceVariant,
//         contentPadding:
//         const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(50),
//           borderSide: BorderSide.none,
//         ),
//         enabledBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(50),
//           borderSide: BorderSide.none,
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(50),
//           borderSide: BorderSide(color: cs.primary, width: 1.5),
//         ),
//         isDense: false,
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // OTP Input Field
// // 6 individual digit boxes — used inside CustomTextField(variant: otp)
// // ─────────────────────────────────────────────────────────────────────────────
//
// class _OtpField extends StatefulWidget {
//   const _OtpField({
//     required this.length,
//     this.onCompleted,
//     this.onChanged,
//     this.isEnabled = true,
//   });
//
//   final int length;
//   final ValueChanged<String>? onCompleted;
//   final ValueChanged<String>? onChanged;
//   final bool isEnabled;
//
//   @override
//   State<_OtpField> createState() => _OtpFieldState();
// }
//
// class _OtpFieldState extends State<_OtpField> {
//   late List<TextEditingController> _controllers;
//   late List<FocusNode> _focusNodes;
//
//   @override
//   void initState() {
//     super.initState();
//     _controllers =
//         List.generate(widget.length, (_) => TextEditingController());
//     _focusNodes = List.generate(widget.length, (_) => FocusNode());
//   }
//
//   @override
//   void dispose() {
//     for (final c in _controllers) c.dispose();
//     for (final f in _focusNodes) f.dispose();
//     super.dispose();
//   }
//
//   String get _otp =>
//       _controllers.map((c) => c.text).join();
//
//   void _onDigitChanged(int index, String value) {
//     if (value.length > 1) {
//       // Handle paste
//       final digits = value.replaceAll(RegExp(r'\D'), '');
//       for (int i = 0; i < widget.length && i < digits.length; i++) {
//         _controllers[i].text = digits[i];
//       }
//       final nextFocus = digits.length < widget.length
//           ? digits.length
//           : widget.length - 1;
//       _focusNodes[nextFocus].requestFocus();
//     } else if (value.isNotEmpty) {
//       if (index < widget.length - 1) {
//         _focusNodes[index + 1].requestFocus();
//       } else {
//         _focusNodes[index].unfocus();
//       }
//     }
//
//     final otp = _otp;
//     widget.onChanged?.call(otp);
//     if (otp.length == widget.length) {
//       widget.onCompleted?.call(otp);
//     }
//   }
//
//   void _onKeyEvent(int index, KeyEvent event) {
//     if (event is KeyDownEvent &&
//         event.logicalKey == LogicalKeyboardKey.backspace &&
//         _controllers[index].text.isEmpty &&
//         index > 0) {
//       _controllers[index - 1].clear();
//       _focusNodes[index - 1].requestFocus();
//       widget.onChanged?.call(_otp);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: List.generate(widget.length, (i) {
//         return SizedBox(
//           width: 48,
//           height: 56,
//           child: KeyboardListener(
//             focusNode: FocusNode(),
//             onKeyEvent: (e) => _onKeyEvent(i, e),
//             child: TextFormField(
//               controller: _controllers[i],
//               focusNode: _focusNodes[i],
//               enabled: widget.isEnabled,
//               keyboardType: TextInputType.number,
//               textInputAction: i < widget.length - 1
//                   ? TextInputAction.next
//                   : TextInputAction.done,
//               textAlign: TextAlign.center,
//               maxLength: 2, // allows paste detection
//               inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//               onChanged: (v) => _onDigitChanged(i, v),
//               buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
//               style: TextStyle(
//                 fontSize: 22,
//                 fontWeight: FontWeight.w700,
//                 color: cs.onSurface,
//                 letterSpacing: 0,
//               ),
//               decoration: InputDecoration(
//                 filled: true,
//                 fillColor: Theme.of(context).brightness == Brightness.light
//                     ? AppColors.lightSurfaceVariant
//                     : AppColors.darkSurfaceVariant,
//                 contentPadding: EdgeInsets.zero,
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(12),
//                   borderSide: BorderSide(color: cs.outline, width: 1),
//                 ),
//                 enabledBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(12),
//                   borderSide: BorderSide(color: cs.outline, width: 1),
//                 ),
//                 focusedBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(12),
//                   borderSide: BorderSide(
//                     color: AppColors.goldPrimary,
//                     width: 2,
//                   ),
//                 ),
//                 counterText: '',
//               ),
//             ),
//           ),
//         );
//       }),
//     );
//   }
// }

import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final String? labelText;
  final TextInputType keyboardType;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.labelText,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        labelText: labelText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
    );
  }
}