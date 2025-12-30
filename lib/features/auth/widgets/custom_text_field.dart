import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/constants.dart';

/// Custom text field with consistent styling
class CustomTextField extends StatefulWidget {
  final String? label;
  final String? hintText;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final bool obscureText;
  final bool enabled;
  final int maxLines;
  final int? maxLength;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final EdgeInsetsGeometry? contentPadding;

  const CustomTextField({
    super.key,
    this.label,
    this.hintText,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.inputFormatters,
    this.focusNode,
    this.textInputAction,
    this.autofocus = false,
    this.contentPadding,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: AppTextStyles.inputLabel(),
          ),
          const SizedBox(height: AppDimensions.spaceXS),
        ],
        TextFormField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          obscureText: _obscureText,
          enabled: widget.enabled,
          maxLines: widget.obscureText ? 1 : widget.maxLines,
          maxLength: widget.maxLength,
          validator: widget.validator,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          inputFormatters: widget.inputFormatters,
          focusNode: widget.focusNode,
          textInputAction: widget.textInputAction,
          autofocus: widget.autofocus,
          style: AppTextStyles.inputText(),
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: widget.prefixIcon,
            suffixIcon: widget.obscureText
                ? IconButton(
                    icon: Icon(
                      _obscureText
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textSecondaryDark,
                      size: AppDimensions.iconSM,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  )
                : widget.suffixIcon,
            contentPadding: widget.contentPadding,
            counterText: '',
          ),
        ),
      ],
    );
  }
}

/// Phone number text field with country code
class PhoneTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final String countryCode;

  const PhoneTextField({
    super.key,
    this.controller,
    this.validator,
    this.onChanged,
    this.countryCode = '+234',
  });

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      hintText: AppStrings.phoneNumberHint,
      controller: controller,
      keyboardType: TextInputType.phone,
      validator: validator,
      onChanged: onChanged,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(11),
      ],
      prefixIcon: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceMD),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              countryCode,
              style: AppTextStyles.inputText(),
            ),
            const SizedBox(width: AppDimensions.spaceXS),
            Container(
              width: 1,
              height: 24,
              color: AppColors.inputBorderDark,
            ),
          ],
        ),
      ),
    );
  }
}

/// Password text field with visibility toggle
class PasswordTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final TextInputAction? textInputAction;

  const PasswordTextField({
    super.key,
    this.controller,
    this.hintText,
    this.validator,
    this.onChanged,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      hintText: hintText ?? AppStrings.passwordHint,
      controller: controller,
      obscureText: true,
      validator: validator,
      onChanged: onChanged,
      textInputAction: textInputAction,
    );
  }
}
