import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/util/image_urls.dart';

void main() {
  group('providerImageWebUrl', () {
    test('GitLab bare /uploads link → base/projectPath/uploads', () {
      final url = providerImageWebUrl(
        providerType: ProviderType.gitlab,
        baseUrl: 'https://xddlabs.com',
        projectPath: 'root/tbchat',
        rawUrl: '/uploads/abc123/pasted_image.png',
      );
      expect(
        url,
        'https://xddlabs.com/root/tbchat/uploads/abc123/pasted_image.png',
      );
    });

    test('a trailing slash on the base is not doubled', () {
      final url = providerImageWebUrl(
        providerType: ProviderType.gitlab,
        baseUrl: 'https://xddlabs.com/',
        projectPath: 'root/tbchat',
        rawUrl: '/uploads/abc123/img.png',
      );
      expect(url, 'https://xddlabs.com/root/tbchat/uploads/abc123/img.png');
    });

    test('an absolute URL is returned unchanged, for any provider', () {
      const abs = 'https://cdn.example.com/x/pic.png';
      for (final p in ProviderType.values) {
        expect(
          providerImageWebUrl(
            providerType: p,
            baseUrl: 'https://xddlabs.com',
            projectPath: 'root/tbchat',
            rawUrl: abs,
          ),
          abs,
        );
      }
    });

    test(
      'GitLab /uploads without a project path resolves against the root',
      () {
        final url = providerImageWebUrl(
          providerType: ProviderType.gitlab,
          baseUrl: 'https://xddlabs.com',
          projectPath: null,
          rawUrl: '/uploads/abc123/img.png',
        );
        expect(url, 'https://xddlabs.com/uploads/abc123/img.png');
      },
    );

    test('a non-GitLab relative link resolves against the instance root', () {
      final url = providerImageWebUrl(
        providerType: ProviderType.zentao,
        baseUrl: 'https://zentao.example.com',
        projectPath: 'root/tbchat',
        rawUrl: '/file-read-1.png',
      );
      expect(url, 'https://zentao.example.com/file-read-1.png');
    });

    test('null / empty base URL yields null', () {
      expect(
        providerImageWebUrl(
          providerType: ProviderType.gitlab,
          baseUrl: null,
          projectPath: 'root/tbchat',
          rawUrl: '/uploads/abc/img.png',
        ),
        isNull,
      );
      expect(
        providerImageWebUrl(
          providerType: ProviderType.gitlab,
          baseUrl: '  ',
          projectPath: 'root/tbchat',
          rawUrl: '/uploads/abc/img.png',
        ),
        isNull,
      );
    });
  });
}
