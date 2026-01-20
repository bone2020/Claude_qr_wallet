import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/smile_id_service.dart';
import '../../../providers/auth_provider.dart';
import '../widgets/kyc_verification_card.dart';

/// KYC Selection Screen - Choose ID type for verification
class KycScreen extends ConsumerStatefulWidget {
  const KycScreen({super.key});

  @override
  ConsumerState<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends ConsumerState<KycScreen> {
  final _smileIdService = SmileIDService.instance;
  String? _userCountryCode;
  List<Map<String, dynamic>> _idTypes = [];

  @override
  void initState() {
    super.initState();
    _loadUserCountry();
  }

  void _loadUserCountry() {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      _userCountryCode = user.country;

      if (_userCountryCode == null || _userCountryCode!.isEmpty) {
        _userCountryCode = _smileIdService.extractCountryCode(user.phoneNumber);
      }
    }

    _userCountryCode ??= 'GH';

    setState(() {
      _idTypes = _smileIdService.getIdTypesForCountry(_userCountryCode);
    });
  }

  void _navigateToVerification(String idType) {
    switch (idType) {
      case 'PASSPORT':
        context.push(AppRoutes.kycPassport, extra: {'countryCode': _userCountryCode});
        break;
      case 'NIN':
        context.push(AppRoutes.kycNin, extra: {'countryCode': _userCountryCode});
        break;
      case 'BVN':
        context.push(AppRoutes.kycBvn, extra: {'countryCode': _userCountryCode});
        break;
      case 'DRIVERS_LICENSE':
        context.push(AppRoutes.kycDriversLicense, extra: {'countryCode': _userCountryCode});
        break;
      case 'VOTERS_ID':
        context.push(AppRoutes.kycVotersCard, extra: {'countryCode': _userCountryCode});
        break;
      case 'NATIONAL_ID':
        context.push(AppRoutes.kycNationalId, extra: {'countryCode': _userCountryCode});
        break;
      case 'SSNIT':
        context.push(AppRoutes.kycSsnit, extra: {'countryCode': _userCountryCode});
        break;
    }
  }

  IconData _getIconForIdType(String idType) {
    switch (idType) {
      case 'PASSPORT':
        return Icons.book_rounded;
      case 'NIN':
        return Icons.badge_rounded;
      case 'BVN':
        return Icons.account_balance_rounded;
      case 'DRIVERS_LICENSE':
        return Icons.drive_eta_rounded;
      case 'VOTERS_ID':
        return Icons.how_to_vote_rounded;
      case 'NATIONAL_ID':
        return Icons.credit_card_rounded;
      case 'SSNIT':
        return Icons.security_rounded;
      default:
        return Icons.badge_rounded;
    }
  }

  String _getDescriptionForIdType(Map<String, dynamic> idType) {
    final value = idType['value'] as String;
    switch (value) {
      case 'PASSPORT':
        return AppStrings.passportDescription;
      case 'NIN':
        return AppStrings.ninDescription;
      case 'BVN':
        return AppStrings.bvnDescription;
      case 'DRIVERS_LICENSE':
        return AppStrings.driversLicenseDescription;
      case 'VOTERS_ID':
        return AppStrings.votersCardDescription;
      case 'NATIONAL_ID':
        return AppStrings.nationalIdDescription;
      case 'SSNIT':
        return AppStrings.ssnitDescription;
      default:
        return 'Verify your identity';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.spaceLG),

              _buildHeader()
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: -0.2, end: 0, duration: 400.ms),

              const SizedBox(height: AppDimensions.spaceXXL),

              ..._idTypes.asMap().entries.map((entry) {
                final index = entry.key;
                final idType = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.spaceMD),
                  child: KycIdTypeCard(
                    title: idType['label'] as String,
                    description: _getDescriptionForIdType(idType),
                    icon: _getIconForIdType(idType['value'] as String),
                    onTap: () => _navigateToVerification(idType['value'] as String),
                  ).animate().fadeIn(
                    delay: Duration(milliseconds: 100 + (index * 50)),
                    duration: 400.ms,
                  ),
                );
              }),

              const SizedBox(height: AppDimensions.spaceXXL),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.selectVerificationMethod,
          style: AppTextStyles.displaySmall(),
        ),
        const SizedBox(height: AppDimensions.spaceXS),
        Text(
          AppStrings.selectVerificationMethodSubtitle,
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
        ),
      ],
    );
  }
}
