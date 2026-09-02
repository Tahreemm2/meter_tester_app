// =============================================================================
// FILE: lib/core/services/location_service.dart
// PURPOSE: Thin wrapper around package:geolocator so callers (InspectionBloc)
// never touch the plugin API directly, and get a single typed result
// instead of juggling permission/service-enabled/timeout exceptions.
//
// WHY THIS EXISTS: backend/api/data.php requires every inspection submission
// to include gps.latitude/gps.longitude (validated server-side), and every
// attached image to carry its own lat/lng. This service is the single
// source of the device's current position for both.
// =============================================================================

import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// Outcome of a location capture attempt. [message] is always a
/// user-presentable string (never a raw plugin exception).
class LocationResult {
  final bool isSuccess;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final String? placeName;
  final String? errorMessage;

  const LocationResult._({
    required this.isSuccess,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.placeName,
    this.errorMessage,
  });

  factory LocationResult.success({
    required double latitude,
    required double longitude,
    double? accuracyMeters,
    String? placeName,
  }) =>
      LocationResult._(
        isSuccess: true,
        latitude: latitude,
        longitude: longitude,
        accuracyMeters: accuracyMeters,
        placeName: placeName,
      );

  factory LocationResult.failure(String message) =>
      LocationResult._(isSuccess: false, errorMessage: message);
}

class LocationService {
  LocationService._internal();
  static final LocationService instance = LocationService._internal();

  /// Requests (if needed) and returns the device's current GPS position,
  /// plus a best-effort human-readable place name. Never throws — all
  /// failure paths return a [LocationResult.failure] with a message safe
  /// to show directly in the UI.
  Future<LocationResult> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult.failure(
          'Location services are turned off on this device. Please enable GPS/Location and try again.',
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult.failure(
            'Location permission was denied. Please allow location access to submit an inspection.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult.failure(
          'Location permission is permanently denied. Please enable it from your device Settings > Apps > Permissions.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      // Reverse-geocoding is best-effort: it needs network + a geocoder
      // provider to be available on the device, and can legitimately fail
      // (offline field sites, some Android ROMs with no Google Play
      // Services, etc.). A failure here must NOT fail the whole GPS
      // capture — the coordinates are what the backend actually requires;
      // the place name is a display nicety on top.
      final placeName = await _reverseGeocode(position.latitude, position.longitude);

      return LocationResult.success(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        placeName: placeName,
      );
    } on LocationServiceDisabledException {
      return LocationResult.failure(
        'Location services are turned off on this device. Please enable GPS/Location and try again.',
      );
    } catch (e) {
      return LocationResult.failure(
        'Could not determine your location. Move to an open area and try again. ($e)',
      );
    }
  }

  /// Best-effort reverse geocode. Returns null (never throws) if it fails
  /// for any reason — callers should fall back to showing raw coordinates.
  Future<String?> _reverseGeocode(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude)
          .timeout(const Duration(seconds: 10));
      if (placemarks.isEmpty) return null;

      final p = placemarks.first;
      final parts = <String>[
        if (p.street != null && p.street!.trim().isNotEmpty) p.street!.trim(),
        if (p.subLocality != null && p.subLocality!.trim().isNotEmpty) p.subLocality!.trim(),
        if (p.locality != null && p.locality!.trim().isNotEmpty) p.locality!.trim(),
        if (p.administrativeArea != null && p.administrativeArea!.trim().isNotEmpty)
          p.administrativeArea!.trim(),
      ];

      if (parts.isEmpty) return null;
      // Drop consecutive duplicate segments (small towns often repeat the
      // same name across street/sublocality/locality fields).
      final deduped = <String>[];
      for (final part in parts) {
        if (deduped.isEmpty || deduped.last.toLowerCase() != part.toLowerCase()) {
          deduped.add(part);
        }
      }
      return deduped.join(', ');
    } catch (_) {
      return null;
    }
  }
}
