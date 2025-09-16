import 'package:uuid/uuid.dart';

class VoiceNote {
  final String id;
  final String audioPath;
  final String transcription;
  final String? intentDescription;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final int? durationSeconds; // Duration of the recording in seconds

  VoiceNote({
    String? id,
    required this.audioPath,
    required this.transcription,
    this.intentDescription,
    DateTime? createdAt,
    this.latitude,
    this.longitude,
    this.locationName,
    this.durationSeconds,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'audioPath': audioPath,
      'transcription': transcription,
      'intentDescription': intentDescription,
      'createdAt': createdAt.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
      'durationSeconds': durationSeconds,
    };
  }

  factory VoiceNote.fromMap(Map<String, dynamic> map) {
    return VoiceNote(
      id: map['id'],
      audioPath: map['audioPath'],
      transcription: map['transcription'],
      intentDescription: map['intentDescription'],
      createdAt: DateTime.parse(map['createdAt']),
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      locationName: map['locationName'],
      durationSeconds: map['durationSeconds']?.toInt(),
    );
  }
}
