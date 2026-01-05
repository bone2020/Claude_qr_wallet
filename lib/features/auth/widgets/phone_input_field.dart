import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/constants.dart';
import 'country_codes.dart';

/// Phone input field with country code picker
class PhoneInputField extends StatefulWidget {
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final void Function(String fullNumber)? onChanged;
  final void Function(CountryCode)? onCountryChanged;
  final CountryCode? initialCountry;
  final String? label;
  final bool enabled;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;

  const PhoneInputField({
    super.key,
    this.controller,
    this.validator,
    this.onChanged,
    this.onCountryChanged,
    this.initialCountry,
    this.label,
    this.enabled = true,
    this.focusNode,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  @override
  State<PhoneInputField> createState() => PhoneInputFieldState();
}

class PhoneInputFieldState extends State<PhoneInputField> {
  late CountryCode _selectedCountry;

  /// Get the selected country
  CountryCode get selectedCountry => _selectedCountry;

  /// Get full phone number with country code
  String get fullPhoneNumber {
    return '${_selectedCountry.dialCode}${widget.controller?.text ?? ''}';
  }

  /// Validate the phone number
  String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    if (value.length < 7) {
      return 'Phone number is too short';
    }
    if (value.length > 15) {
      return 'Phone number is too long';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _selectedCountry = widget.initialCountry ?? AfricanCountryCodes.defaultCountry;
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXL),
        ),
      ),
      isScrollControlled: true,
      builder: (context) => _CountryPickerSheet(
        selectedCountry: _selectedCountry,
        onSelect: (country) {
          setState(() => _selectedCountry = country);
          widget.onCountryChanged?.call(country);
          _notifyChange();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _notifyChange() {
    if (widget.onChanged != null && widget.controller != null) {
      final fullNumber = '${_selectedCountry.dialCode}${widget.controller!.text}';
      widget.onChanged!(fullNumber);
    }
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
          keyboardType: TextInputType.phone,
          enabled: widget.enabled,
          focusNode: widget.focusNode,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onFieldSubmitted,
          validator: widget.validator,
          onChanged: (_) => _notifyChange(),
          style: AppTextStyles.inputText(),
          cursorColor: AppColors.primary,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(15),
          ],
          decoration: InputDecoration(
            hintText: 'Enter phone number',
            hintStyle: AppTextStyles.inputHint(),
            prefixIcon: GestureDetector(
              onTap: widget.enabled ? _showCountryPicker : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spaceMD,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedCountry.flag,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: AppDimensions.spaceXXS),
                    Text(
                      _selectedCountry.dialCode,
                      style: AppTextStyles.inputText(),
                    ),
                    const SizedBox(width: AppDimensions.spaceXXS),
                    Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.textSecondaryDark,
                      size: 18,
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
            ),
          ),
        ),
      ],
    );
  }
}

/// Country picker bottom sheet
class _CountryPickerSheet extends StatefulWidget {
  final CountryCode selectedCountry;
  final void Function(CountryCode) onSelect;

  const _CountryPickerSheet({
    required this.selectedCountry,
    required this.onSelect,
  });

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _searchController = TextEditingController();
  List<CountryCode> _filteredCountries = AfricanCountryCodes.countries;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterCountries(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCountries = AfricanCountryCodes.countries;
      } else {
        _filteredCountries = AfricanCountryCodes.countries
            .where((country) =>
                country.name.toLowerCase().contains(query.toLowerCase()) ||
                country.dialCode.contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: AppDimensions.spaceMD),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiaryDark,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.all(AppDimensions.spaceMD),
            child: Text(
              'Select Country',
              style: AppTextStyles.headlineSmall(),
            ),
          ),

          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spaceMD,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _filterCountries,
              style: AppTextStyles.inputText(),
              cursorColor: AppColors.primary,
              decoration: InputDecoration(
                hintText: 'Search country...',
                hintStyle: AppTextStyles.inputHint(),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.textSecondaryDark,
                ),
                filled: true,
                fillColor: AppColors.inputBackgroundDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spaceMD,
                  vertical: AppDimensions.spaceSM,
                ),
              ),
            ),
          ),

          const SizedBox(height: AppDimensions.spaceMD),

          // Country list
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: _filteredCountries.length,
              itemBuilder: (context, index) {
                final country = _filteredCountries[index];
                final isSelected = country.code == widget.selectedCountry.code;

                return ListTile(
                  onTap: () => widget.onSelect(country),
                  leading: Text(
                    country.flag,
                    style: const TextStyle(fontSize: 24),
                  ),
                  title: Text(
                    country.name,
                    style: AppTextStyles.bodyMedium(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimaryDark,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        country.dialCode,
                        style: AppTextStyles.bodyMedium(
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: AppDimensions.spaceXS),
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
