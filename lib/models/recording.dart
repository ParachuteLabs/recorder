import 'dart:convert';

class Recording {
  final String id;
  final String title;
  final String filePath;
  final DateTime timestamp;
  final Duration duration;
  final List<String> tags;
  final String transcript;
  final double fileSizeKB;

  Recording({
    required this.id,
    required this.title,
    required this.filePath,
    required this.timestamp,
    required this.duration,
    required this.tags,
    required this.transcript,
    required this.fileSizeKB,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'filePath': filePath,
    'timestamp': timestamp.toIso8601String(),
    'duration': duration.inMilliseconds,
    'tags': tags,
    'transcript': transcript,
    'fileSizeKB': fileSizeKB,
  };

  factory Recording.fromJson(Map<String, dynamic> json) => Recording(
    id: json['id'],
    title: json['title'],
    filePath: json['filePath'],
    timestamp: DateTime.parse(json['timestamp']),
    duration: Duration(milliseconds: json['duration']),
    tags: List<String>.from(json['tags']),
    transcript: json['transcript'],
    fileSizeKB: json['fileSizeKB'],
  );

  String get durationString {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedSize {
    if (fileSizeKB < 1024) {
      return '${fileSizeKB.toStringAsFixed(1)}KB';
    }
    return '${(fileSizeKB / 1024).toStringAsFixed(1)}MB';
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}