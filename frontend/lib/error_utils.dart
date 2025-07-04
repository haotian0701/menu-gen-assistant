import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class UserFacingError {
  final String message;
  final bool userError;
  const UserFacingError(this.message, this.userError);
}

UserFacingError parseErrorResponse(int statusCode, String body) {
  try {
    final data = jsonDecode(body) as Map<String, dynamic>;
    final msg = data['error'] as String? ?? 'Unknown error';
    final userErr = data['user_error'] == true || (statusCode >= 400 && statusCode < 500);
    return UserFacingError(msg, userErr);
  } catch (_) {
    // Fallback
    return UserFacingError('Unexpected error (code $statusCode).', statusCode >= 400 && statusCode < 500);
  }
}

Future<Map<String, dynamic>?> handleJsonPost({
  required Future<http.Response> future,
  required BuildContext context,
  bool showSnackBarOnError = true,
}) async {
  try {
    final resp = await future;
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    final parsed = parseErrorResponse(resp.statusCode, resp.body);
    if (showSnackBarOnError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(parsed.message)),
      );
    }
    throw Exception(parsed.message);
  } on Exception {
    rethrow;
  } catch (_) {
    if (showSnackBarOnError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error – check your connection.')),
      );
    }
    rethrow;
  }
} 