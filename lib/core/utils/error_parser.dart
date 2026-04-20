import 'dart:io';
import 'dart:async';

/// Convierte cualquier excepción de red o API en un mensaje amigable.
/// Úsalo en TODOS los providers: AuthProvider, BatchProvider, etc.
///
/// Uso:
///   } catch (e) {
///     _errorMessage = AppErrorParser.parse(e);
///   }
class AppErrorParser {
  AppErrorParser._();

  static String parse(Object e) {
    // ── Sin conexión / DNS fallido / timeout ──────────────────────────────
    if (e is SocketException || e is HandshakeException) {
      return 'Sin conexión. Revisa tu red e intenta de nuevo.';
    }

    if (e is TimeoutException) {
      return 'El servidor tardó demasiado en responder. Intenta más tarde.';
    }

    // ── Errores lanzados como Exception("mensaje") desde los services ─────
    final msg = e.toString();
    final clean = msg.startsWith('Exception: ') ? msg.substring(11) : msg;

    // Si el mensaje interno también es un error de red (viene del http client)
    if (_isNetworkError(clean)) {
      return 'Sin conexión. Revisa tu red e intenta de nuevo.';
    }

    return clean;
  }

  static bool _isNetworkError(String msg) {
    final lower = msg.toLowerCase();
    return lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('no address associated') ||
        lower.contains('connection refused') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection timed out') ||
        lower.contains('errno = 7') ||
        lower.contains('clientexception');
  }
}
