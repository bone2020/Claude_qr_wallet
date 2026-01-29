/// Centralized error handling utility for user-friendly error messages
class ErrorHandler {
  ErrorHandler._();

  /// Check if the error is a SmileID "already enrolled" error
  /// This error means the user has already been verified, so we should treat it as success
  static bool isAlreadyEnrolledError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('already enrolled') ||
        errorString.contains('user is already enrolled') ||
        errorString.contains('wrong job type') && errorString.contains('enrolled');
  }

  /// Check if the error is a MoMo service not configured error
  static bool isMomoNotConfiguredError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('momo') &&
        (errorString.contains('not configured') ||
         errorString.contains('coming soon') ||
         errorString.contains('not yet available'));
  }

  /// Get user-friendly message for MoMo/Mobile Money errors
  static String getMomoUserFriendlyMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Service not configured
    if (isMomoNotConfiguredError(error) ||
        errorString.contains('config_missing') ||
        errorString.contains('service unavailable')) {
      return 'Mobile Money is coming soon! This feature is not yet available. Please use Card or Bank Transfer instead.';
    }

    // Payment rejected/failed
    if (errorString.contains('rejected') || errorString.contains('declined')) {
      return 'Payment was declined. Please check your Mobile Money balance and try again.';
    }

    // Insufficient funds
    if (errorString.contains('insufficient') || errorString.contains('not enough')) {
      return 'Insufficient funds in your Mobile Money account.';
    }

    // Invalid phone number
    if (errorString.contains('invalid') && errorString.contains('phone')) {
      return 'Invalid phone number. Please check and try again.';
    }

    // Timeout/pending
    if (errorString.contains('timeout') || errorString.contains('timed out')) {
      return 'Payment request timed out. Please check your phone for approval prompt and try again.';
    }

    // Default
    return getUserFriendlyMessage(error);
  }

  /// Convert technical error messages to user-friendly messages
  static String getUserFriendlyMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Network errors
    if (_isNetworkError(errorString)) {
      return 'Unable to connect. Please check your internet connection and try again.';
    }

    // Permission errors
    if (_isPermissionError(errorString)) {
      return 'Camera access is required for verification. Please enable camera permissions in your device settings.';
    }

    // User cancelled
    if (_isUserCancelled(errorString)) {
      return 'Verification was cancelled. You can try again when ready.';
    }

    // Face detection errors
    if (_isFaceDetectionError(errorString)) {
      return 'We couldn\'t detect your face clearly. Please ensure good lighting and position your face within the frame.';
    }

    // Face mismatch
    if (_isFaceMismatchError(errorString)) {
      return 'Face verification failed. The selfie doesn\'t match the ID photo. Please ensure you\'re using your own ID document.';
    }

    // ID verification errors
    if (_isIdVerificationError(errorString)) {
      return 'ID verification failed. Please ensure your ID is valid, not expired, and the information entered is correct.';
    }

    // Document capture errors
    if (_isDocumentError(errorString)) {
      return 'We couldn\'t read your document clearly. Please ensure the document is well-lit, flat, and all text is visible.';
    }

    // Server/API errors
    if (_isServerError(errorString)) {
      return 'Our verification service is temporarily unavailable. Please try again in a few minutes.';
    }

    // Timeout errors
    if (_isTimeoutError(errorString)) {
      return 'The request took too long. Please check your connection and try again.';
    }

    // Authentication errors
    if (_isAuthError(errorString)) {
      return 'Your session has expired. Please sign in again to continue.';
    }

    // Firebase errors
    if (_isFirebaseError(errorString)) {
      return _getFirebaseUserFriendlyMessage(errorString);
    }

    // Default message for unknown errors
    return 'Something went wrong. Please try again or contact support if the problem persists.';
  }

  /// Get a user-friendly message for Smile ID specific errors
  static String getSmileIdUserFriendlyMessage(String? resultCode, String? error) {
    // Handle Smile ID result codes
    if (resultCode != null) {
      switch (resultCode) {
        case '0810':
          return 'Verification successful!';
        case '0811':
          return 'Face verification failed. The selfie doesn\'t match the ID photo.';
        case '0812':
          return 'ID document could not be verified. Please try with a different document.';
        case '0813':
          return 'Liveness check failed. Please follow the on-screen instructions carefully.';
        case '0814':
          return 'Document is expired. Please use a valid, non-expired ID.';
        case '0815':
          return 'ID information mismatch. Please ensure you entered the correct details.';
        case '0816':
          return 'Document not supported. Please try with a different ID type.';
        case '0820':
          return 'Face not detected. Please ensure your face is clearly visible and well-lit.';
        case '0821':
          return 'Multiple faces detected. Please ensure only your face is in the frame.';
        case '0822':
          return 'Poor image quality. Please ensure good lighting and a clear photo.';
        default:
          // If we have an error message, process it
          if (error != null) {
            return getUserFriendlyMessage(error);
          }
          return 'Verification could not be completed. Please try again.';
      }
    }

    // Process the error message if no result code
    if (error != null) {
      return getUserFriendlyMessage(error);
    }

    return 'Verification could not be completed. Please try again.';
  }

  /// Get specific error messages for KYC/verification flows
  static String getKycErrorMessage(String operation, dynamic error) {
    final errorString = error.toString().toLowerCase();

    // ID number specific errors
    if (operation == 'id_validation') {
      if (errorString.contains('nin') || errorString.contains('national identification')) {
        return 'Invalid NIN format. NIN must be exactly 11 digits.';
      }
      if (errorString.contains('bvn') || errorString.contains('bank verification')) {
        return 'Invalid BVN format. BVN must be exactly 11 digits.';
      }
      if (errorString.contains('ssnit')) {
        return 'Invalid SSNIT format. SSNIT must be 1 letter followed by 12 digits.';
      }
    }

    // Document upload errors
    if (operation == 'document_upload') {
      if (_isNetworkError(errorString)) {
        return 'Failed to upload document. Please check your connection and try again.';
      }
      if (errorString.contains('size') || errorString.contains('large')) {
        return 'Image file is too large. Please use a smaller image.';
      }
      return 'Failed to upload document. Please try again.';
    }

    // Biometric errors
    if (operation == 'biometric_kyc') {
      return getSmileIdUserFriendlyMessage(null, error.toString());
    }

    return getUserFriendlyMessage(error);
  }

  // ============================================================
  // PRIVATE HELPER METHODS
  // ============================================================

  static bool _isNetworkError(String error) {
    return error.contains('socketexception') ||
        error.contains('network') ||
        error.contains('connection') ||
        error.contains('unreachable') ||
        error.contains('no internet') ||
        error.contains('host lookup') ||
        error.contains('failed host lookup');
  }

  static bool _isPermissionError(String error) {
    return error.contains('permission') ||
        error.contains('camera_access') ||
        error.contains('denied') && error.contains('camera');
  }

  static bool _isUserCancelled(String error) {
    return error.contains('cancelled') ||
        error.contains('canceled') ||
        error.contains('user_cancelled') ||
        error.contains('user aborted') ||
        error.contains('dismissed');
  }

  static bool _isFaceDetectionError(String error) {
    return error.contains('face not detected') ||
        error.contains('no face') ||
        error.contains('face_not_found') ||
        error.contains('unable to detect');
  }

  static bool _isFaceMismatchError(String error) {
    return error.contains('face mismatch') ||
        error.contains('faces do not match') ||
        error.contains('face_mismatch') ||
        error.contains('comparison failed');
  }

  static bool _isIdVerificationError(String error) {
    return error.contains('id verification failed') ||
        error.contains('id not found') ||
        error.contains('invalid id') ||
        error.contains('id_verification_failed') ||
        error.contains('id number not found');
  }

  static bool _isDocumentError(String error) {
    return error.contains('document') &&
        (error.contains('blur') ||
         error.contains('unclear') ||
         error.contains('unreadable') ||
         error.contains('not detected'));
  }

  static bool _isServerError(String error) {
    return error.contains('500') ||
        error.contains('502') ||
        error.contains('503') ||
        error.contains('internal server') ||
        error.contains('service unavailable') ||
        error.contains('server error');
  }

  static bool _isTimeoutError(String error) {
    return error.contains('timeout') ||
        error.contains('timed out') ||
        error.contains('request timeout');
  }

  static bool _isAuthError(String error) {
    return error.contains('unauthenticated') ||
        error.contains('unauthorized') ||
        error.contains('session expired') ||
        error.contains('token expired');
  }

  static bool _isFirebaseError(String error) {
    return error.contains('firebase') ||
        error.contains('firestore') ||
        error.contains('auth/');
  }

  static String _getFirebaseUserFriendlyMessage(String error) {
    if (error.contains('auth/network-request-failed')) {
      return 'Unable to connect. Please check your internet connection.';
    }
    if (error.contains('auth/too-many-requests')) {
      return 'Too many attempts. Please wait a few minutes and try again.';
    }
    if (error.contains('auth/user-not-found')) {
      return 'Account not found. Please check your credentials or sign up.';
    }
    if (error.contains('auth/wrong-password')) {
      return 'Incorrect password. Please try again.';
    }
    if (error.contains('auth/email-already-in-use')) {
      return 'This email is already registered. Please sign in instead.';
    }
    if (error.contains('auth/invalid-email')) {
      return 'Please enter a valid email address.';
    }
    if (error.contains('auth/weak-password')) {
      return 'Password is too weak. Please use at least 6 characters.';
    }
    if (error.contains('auth/invalid-phone-number')) {
      return 'Please enter a valid phone number.';
    }
    if (error.contains('auth/invalid-verification-code')) {
      return 'Invalid verification code. Please check and try again.';
    }
    if (error.contains('auth/quota-exceeded')) {
      return 'Service temporarily unavailable. Please try again later.';
    }
    if (error.contains('permission-denied')) {
      return 'You don\'t have permission to perform this action.';
    }
    return 'Something went wrong. Please try again.';
  }
}

/// Extension on dynamic to easily get user-friendly error messages
extension ErrorExtension on Object {
  String get userFriendlyMessage => ErrorHandler.getUserFriendlyMessage(this);
}
