/// A utility class to map Firebase Auth error codes to readable messages.
class AvailFirebaseAuthException{
  /// The Firebase error code received from the exception.
  final String code;

  /// Constructor to initialize with the error code.
  AvailFirebaseAuthException(this.code);

  /// Returns a user-friendly message based on the error code.
  String get message {
    switch (code) {
    // Basic authentication errors
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';

    // Registration / sign-up errors
      case 'email-already-in-use':
        return 'This email is already associated with another account.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'weak-password':
        return 'The password is too weak. Please choose a stronger one.';

    // Request / quota issues
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'quota-exceeded':
        return 'The quota for this operation has been exceeded. Try again later.';

    // Token & session errors
      case 'invalid-id-token':
        return 'The user\'s credential is no longer valid. Please sign in again.';
      case 'user-token-expired':
        return 'Your session has expired. Please sign in again.';
      case 'id-token-revoked':
        return 'Your session has been revoked. Please sign in again.';
      case 'requires-recent-login':
        return 'This operation requires recent authentication. Please sign in again.';

    // Provider-related errors
      case 'account-exists-with-different-credential':
        return 'This account exists with a different sign-in method.';
      case 'credential-already-in-use':
        return 'The credential is already associated with another account.';
      case 'invalid-credential':
        return 'The provided authentication credential is invalid.';
      case 'invalid-verification-code':
        return 'The verification code is invalid. Please try again.';
      case 'invalid-verification-id':
        return 'The verification ID is invalid. Please request a new one.';

    // Phone auth errors
      case 'captcha-check-failed':
        return 'The reCAPTCHA verification failed. Please try again.';
      case 'invalid-phone-number':
        return 'The provided phone number is not valid.';
      case 'missing-phone-number':
        return 'Please provide a valid phone number.';
      case 'missing-verification-code':
        return 'Verification code is required. Please enter the code sent to your phone.';
      case 'missing-verification-id':
        return 'Verification ID is missing. Please restart the verification process.';
      case 'session-expired':
        return 'Your SMS verification session has expired. Please resend the code.';

    // Email verification / password reset
      case 'expired-action-code':
        return 'The action link has expired. Please request a new one.';
      case 'invalid-action-code':
        return 'The action code is invalid or already used.';
      case 'user-mismatch':
        return 'The credential does not correspond to the user.';
      case 'invalid-continue-uri':
        return 'The continue URL is not valid.';
      case 'missing-continue-uri':
        return 'A continue URL is required.';
      case 'unauthorized-continue-uri':
        return 'The domain of the continue URL is not authorized.';

    // Multi-factor authentication (MFA)
      case 'mfa-required':
        return 'Multi-factor authentication is required. Please complete verification.';
      case 'second-factor-already-in-use':
        return 'This second factor is already enrolled on your account.';
      case 'maximum-second-factor-count-exceeded':
        return 'You cannot enroll more second factors.';
      case 'unsupported-first-factor':
        return 'The first factor is not supported.';
      case 'missing-multi-factor-info':
        return 'Multi-factor information is missing in the request.';

    // App check / security
      case 'app-not-authorized':
        return 'This app is not authorized to use Firebase Authentication.';
      case 'app-not-installed':
        return 'The app required for sign-in is not installed on your device.';
      case 'web-storage-unsupported':
        return 'Web storage is unsupported or disabled in this environment.';
      case 'popup-blocked':
        return 'The sign-in popup was blocked by the browser.';
      case 'popup-closed-by-user':
        return 'The popup has been closed before finalizing the operation.';

    // Custom token errors
      case 'invalid-custom-token':
        return 'The custom token format is incorrect.';
      case 'custom-token-mismatch':
        return 'The custom token does not match the expected project.';

    // Catch-all
      default:
        return 'An unexpected error occurred. [$code]';
    }
  }
}
