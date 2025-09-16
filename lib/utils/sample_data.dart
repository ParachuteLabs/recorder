import 'package:parachute/models/recording.dart';

class SampleData {
  static List<Recording> getSampleRecordings() {
    return [
      Recording(
        id: '1',
        title: 'Home automation notes',
        filePath: '/sample/path1.aac',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        duration: const Duration(minutes: 2, seconds: 15),
        tags: ['Project A', 'Ideas'],
        transcript: '''Notes about setting up home automation system. 
Key points:
- Smart thermostats need WiFi connection
- Motion sensors for automatic lighting
- Voice control integration with existing speakers
- Security considerations for IoT devices''',
        fileSizeKB: 580.5,
      ),
      Recording(
        id: '2',
        title: 'Class overview notes',
        filePath: '/sample/path2.aac',
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
        duration: const Duration(minutes: 4, seconds: 32),
        tags: ['Meeting', 'Important'],
        transcript: '''Discussion about upcoming class assignments and project deadlines.

Professor mentioned:
- Final project due in 3 weeks
- Midterm exam next Tuesday
- Office hours extended for project help
- Study group formation encouraged''',
        fileSizeKB: 1245.2,
      ),
      Recording(
        id: '3',
        title: 'Client meeting recap',
        filePath: '/sample/path3.aac',
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
        duration: const Duration(minutes: 1, seconds: 45),
        tags: ['Meeting', 'To Do'],
        transcript: '''Quick recap of client meeting today.

Action items:
- Send revised proposal by Friday
- Schedule follow-up call for next week
- Update project timeline
- Review budget considerations''',
        fileSizeKB: 420.8,
      ),
      Recording(
        id: '4',
        title: 'Interview preparation',
        filePath: '/sample/path4.aac',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        duration: const Duration(minutes: 6, seconds: 18),
        tags: ['Interview', 'Important'],
        transcript: '''Practice answers for upcoming job interview.

Common questions to prepare:
- Tell me about yourself
- Why do you want this position?
- What are your strengths and weaknesses?
- Where do you see yourself in 5 years?
- Do you have any questions for us?

Remember to research the company thoroughly and prepare specific examples.''',
        fileSizeKB: 1850.3,
      ),
    ];
  }

  static void addSampleDataIfEmpty() async {
    // This would be called on first launch to populate with sample data
    // In a real app, you might want to add this conditionally
  }
}