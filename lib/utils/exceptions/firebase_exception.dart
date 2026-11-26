/// A utility class to map general Firebase exception codes to readable messages.
class AvailFirebaseException implements Exception {
  /// The Firebase error code received from the exception.
  final String code;

  /// Constructor to initialize with the error code.
  AvailFirebaseException(this.code);

  /// Returns a user-friendly message based on the error code.
  String get message {
    switch (code) {
    // Permission & access issues
      case 'permission-denied':
        return 'You do not have permission to perform this action.';
      case 'unauthenticated':
        return 'You must be signed in to perform this action.';
      case 'unauthorized':
        return 'You are not authorized to access this resource.';

    // Resource & availability issues
      case 'unavailable':
        return 'The service is currently unavailable. Please try again later.';
      case 'not-found':
        return 'The requested resource was not found.';
      case 'already-exists':
        return 'The resource already exists.';
      case 'deadline-exceeded':
        return 'The operation timed out. Please check your connection.';
      case 'cancelled':
        return 'The operation was cancelled.';
      case 'resource-exhausted':
        return 'Quota exceeded. Please wait before retrying.';

    // Invalid requests
      case 'invalid-argument':
        return 'Invalid input provided. Please check your data.';
      case 'failed-precondition':
        return 'The operation was rejected due to failed preconditions.';
      case 'aborted':
        return 'The operation was aborted. Please retry.';
      case 'out-of-range':
        return 'The value provided is out of range.';

    // Data & internal issues
      case 'data-loss':
        return 'Data loss occurred. Please retry or contact support.';
      case 'internal':
        return 'An internal error occurred. Please try again.';
      case 'unknown':
        return 'An unknown error occurred. Please try again.';

    // Firestore specific
      case 'firestore/permission-denied':
        return 'You do not have Firestore permission for this action.';
      case 'firestore/unavailable':
        return 'Firestore service is unavailable at the moment.';
      case 'firestore/aborted':
        return 'The Firestore operation was aborted.';
      case 'firestore/cancelled':
        return 'The Firestore operation was cancelled.';
      case 'firestore/not-found':
        return 'The requested Firestore document was not found.';
      case 'firestore/already-exists':
        return 'The Firestore document already exists.';
      case 'firestore/deadline-exceeded':
        return 'Firestore request timed out.';

    // Realtime Database specific
      case 'database/permission-denied':
        return 'You do not have permission to access the Realtime Database.';
      case 'database/disconnected':
        return 'Disconnected from the database. Please reconnect.';
      case 'database/expired-token':
        return 'Your database session has expired. Please sign in again.';
      case 'database/invalid-token':
        return 'Invalid authentication token for database access.';
      case 'database/network-error':
        return 'Network error while accessing the database.';

    // Firebase Storage specific
      case 'storage/object-not-found':
        return 'The requested file does not exist in storage.';
      case 'storage/bucket-not-found':
        return 'The storage bucket was not found.';
      case 'storage/project-not-found':
        return 'The storage project does not exist.';
      case 'storage/quota-exceeded':
        return 'Storage quota exceeded. Please try again later.';
      case 'storage/unauthenticated':
        return 'You must be signed in to access storage.';
      case 'storage/unauthorized':
        return 'You are not authorized to access this file.';
      case 'storage/retry-limit-exceeded':
        return 'Storage operation retry limit exceeded.';
      case 'storage/canceled':
        return 'The storage operation was cancelled.';

    // Firebase Functions specific
      case 'functions/invalid-argument':
        return 'Invalid argument passed to a cloud function.';
      case 'functions/deadline-exceeded':
        return 'The cloud function took too long to respond.';
      case 'functions/not-found':
        return 'The requested cloud function was not found.';
      case 'functions/internal':
        return 'An internal error occurred in the cloud function.';
      case 'functions/unavailable':
        return 'Cloud Functions service is temporarily unavailable.';

    // Firebase Messaging specific
      case 'messaging/invalid-argument':
        return 'Invalid argument for Firebase Messaging.';
      case 'messaging/registration-token-not-registered':
        return 'This messaging token is no longer valid.';
      case 'messaging/quota-exceeded':
        return 'Too many messages sent. Quota exceeded.';
      case 'messaging/unauthorized':
        return 'You are not authorized to send this message.';
      case 'messaging/unavailable':
        return 'Messaging service is currently unavailable.';

    // Dynamic Links specific
      case 'dynamic-links/expired':
        return 'The dynamic link has expired.';
      case 'dynamic-links/invalid':
        return 'The dynamic link is invalid.';
      case 'dynamic-links/not-found':
        return 'The dynamic link was not found.';

    // Installations / App Check
      case 'installations/invalid-key':
        return 'Invalid Firebase installation key.';
      case 'installations/too-many-requests':
        return 'Too many installation requests. Please slow down.';
      case 'app-check/failed-precondition':
        return 'App Check enforcement failed.';
      case 'app-check/unavailable':
        return 'App Check service is unavailable.';

    // Remote Config
      case 'config-update-failed':
        return 'Failed to update remote config values.';
      case 'config-unavailable':
        return 'Remote config is currently unavailable.';

    // Catch-all
      default:
        return 'An unexpected Firebase error occurred. [$code]';
    }
  }
}
