import 'package:flutter_test/flutter_test.dart';
import 'package:parachute/utils/validators.dart';

void main() {
  group('Validators', () {
    group('validateTitle', () {
      test('should return null for valid title', () {
        expect(Validators.validateTitle('My Recording'), isNull);
        expect(Validators.validateTitle('Test 123'), isNull);
      });

      test('should return error for empty title', () {
        expect(Validators.validateTitle(''), isNotNull);
        expect(Validators.validateTitle('   '), isNotNull);
        expect(Validators.validateTitle(null), isNotNull);
      });

      test('should return error for title exceeding max length', () {
        final longTitle = 'a' * 101;
        expect(Validators.validateTitle(longTitle), isNotNull);
      });

      test('should accept title at max length', () {
        final maxTitle = 'a' * 100;
        expect(Validators.validateTitle(maxTitle), isNull);
      });
    });

    group('validateApiKey', () {
      test('should return null for valid API key', () {
        expect(
            Validators.validateApiKey('sk-1234567890abcdefghijklmnop'), isNull);
      });

      test('should return error for empty key', () {
        expect(Validators.validateApiKey(''), isNotNull);
        expect(Validators.validateApiKey('   '), isNotNull);
        expect(Validators.validateApiKey(null), isNotNull);
      });

      test('should return error for invalid format', () {
        expect(Validators.validateApiKey('invalid-key'), isNotNull);
        expect(Validators.validateApiKey('1234567890'), isNotNull);
      });

      test('should return error for too short key', () {
        expect(Validators.validateApiKey('sk-123'), isNotNull);
      });
    });

    group('validateTag', () {
      test('should return null for valid tag', () {
        expect(Validators.validateTag('work'), isNull);
        expect(Validators.validateTag('my-tag'), isNull);
        expect(Validators.validateTag('tag 123'), isNull);
      });

      test('should return null for empty tag (optional)', () {
        expect(Validators.validateTag(''), isNull);
        expect(Validators.validateTag(null), isNull);
      });

      test('should return error for tag with special characters', () {
        expect(Validators.validateTag('tag@special'), isNotNull);
        expect(Validators.validateTag('tag#hash'), isNotNull);
      });

      test('should return error for tag exceeding max length', () {
        final longTag = 'a' * 51;
        expect(Validators.validateTag(longTag), isNotNull);
      });
    });

    group('sanitize', () {
      test('should trim whitespace', () {
        expect(Validators.sanitize('  test  '), 'test');
        expect(Validators.sanitize('\n\ttest\n\t'), 'test');
      });

      test('should not modify already trimmed text', () {
        expect(Validators.sanitize('test'), 'test');
      });
    });

    group('isValidFilePath', () {
      test('should return true for valid paths', () {
        expect(Validators.isValidFilePath('/path/to/file.m4a'), isTrue);
        expect(Validators.isValidFilePath('C:\\path\\to\\file.m4a'), isTrue);
      });

      test('should return false for invalid paths', () {
        expect(Validators.isValidFilePath(''), isFalse);
        expect(Validators.isValidFilePath(null), isFalse);
        expect(Validators.isValidFilePath('justfilename'), isFalse);
      });
    });
  });
}
