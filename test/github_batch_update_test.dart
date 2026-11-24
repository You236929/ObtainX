import 'package:flutter_test/flutter_test.dart';
import 'package:obtainium/app_sources/github_batch.dart';
import 'package:obtainium/http/source_request_session.dart';
import 'package:http/http.dart' as http;

Map<String, dynamic> _node({
  String tagName = 'v1.2.3',
  bool draft = false,
  bool prerelease = false,
  String? name = 'Release 1.2.3',
}) => {
  'tagName': tagName,
  'name': name,
  'description': 'notes',
  'isDraft': draft,
  'isPrerelease': prerelease,
  'publishedAt': '2026-11-01T10:00:00Z',
  'createdAt': '2026-10-31T09:00:00Z',
  'releaseAssets': {
    'nodes': [
      {
        'name': 'app.apk',
        'size': 1234,
        'downloadUrl':
            'https://github.com/o/r/releases/download/v1.2.3/app.apk',
        'updatedAt': '2026-11-01T10:05:00Z',
        'createdAt': '2026-11-01T10:04:00Z',
      },
    ],
  },
};

void main() {
  group('GitHub batch query', () {
    test('aliases one repository block per repo', () {
      final query = gitHubBatchQuery(3);
      expect(query, contains('query ObtainiumBatchUpdate('));
      expect(query, contains('\$o0: String!, \$n0: String!'));
      expect(query, contains('\$o2: String!, \$n2: String!'));
      expect(query, contains('r0: repository(owner: \$o0, name: \$n0)'));
      expect(query, contains('r2: repository(owner: \$o2, name: \$n2)'));
      expect(query, isNot(contains('r3:')));
      expect(query, contains('releases(first: $gitHubBatchReleasePageSize'));
      expect(query, contains('releaseAssets('));
      // Fields the REST-shaped parser reads must be part of the selection.
      for (final field in [
        'nameWithOwner',
        'isArchived',
        'tagName',
        'description',
        'isPrerelease',
        'isDraft',
        'publishedAt',
        'createdAt',
        'downloadUrl',
        'size',
      ]) {
        expect(query, contains(field));
      }
    });

    test('variables carry owner and name per alias', () {
      final variables = gitHubBatchVariables(const [
        GitHubBatchRepo('owner', 'repo'),
        GitHubBatchRepo('other', 'project'),
      ]);
      expect(variables, {
        'o0': 'owner',
        'n0': 'repo',
        'o1': 'other',
        'n1': 'project',
      });
    });
  });

  group('GraphQL answer mapping', () {
    test('unwraps data and per-alias repository nodes', () {
      final data = gitHubBatchData(
        '{"data":{"r0":{"repository":{"nameWithOwner":"o/r"}},'
        '"r1":{"repository":null}}}',
      );
      expect(data, isNotNull);
      expect(gitHubBatchRepositoryNode(data!, 0), isNotNull);
      expect(gitHubBatchRepositoryNode(data, 1), isNull);
      expect(gitHubBatchRepositoryNode(data, 2), isNull);
    });

    test('a non-GraphQL body yields no data', () {
      expect(gitHubBatchData('not json'), isNull);
      expect(gitHubBatchData('{"message":"Bad credentials"}'), isNull);
    });

    test('repo json matches the REST shape', () {
      final node = {
        'nameWithOwner': 'Owner/Repo',
        'isArchived': true,
      };
      final json = gitHubRestRepoJson(
        node,
        const GitHubBatchRepo('owner', 'repo'),
      );
      expect(json, {
        'name': 'Repo',
        'full_name': 'Owner/Repo',
        'html_url': 'https://github.com/Owner/Repo',
        'archived': true,
      });
    });

    test('a renamed repository is not answered from the batch', () {
      final json = gitHubRestRepoJson(
        {'nameWithOwner': 'owner/new-name', 'isArchived': false},
        const GitHubBatchRepo('owner', 'old-name'),
      );
      expect(json, isNull);
    });

    test('releases map to the REST fields the GitHub source parses', () {
      final releases = gitHubRestReleasesJson({
        'releases': {
          'nodes': [
            _node(),
            _node(tagName: 'v1.2.2', name: null, draft: true),
          ],
        },
      });
      expect(releases, hasLength(2));
      expect(releases.first, {
        'tag_name': 'v1.2.3',
        'name': 'Release 1.2.3',
        'body': 'notes',
        'prerelease': false,
        'draft': false,
        'created_at': '2026-10-31T09:00:00Z',
        'published_at': '2026-11-01T10:00:00Z',
        'assets': [
          {
            'name': 'app.apk',
            'browser_download_url':
                'https://github.com/o/r/releases/download/v1.2.3/app.apk',
            'size': 1234,
            'updated_at': '2026-11-01T10:05:00Z',
            'created_at': '2026-11-01T10:04:00Z',
          },
        ],
      });
      expect(releases[1]['draft'], isTrue);
      expect(releases[1]['name'], isNull);
    });

    test('an empty or malformed release list yields no releases', () {
      expect(gitHubRestReleasesJson({'releases': null}), isEmpty);
      expect(gitHubRestReleasesJson({'releases': {'nodes': null}}), isEmpty);
      expect(gitHubRestReleasesJson({'releases': <String, dynamic>{}}), isEmpty);
    });
  });

  group('session prefetch cache', () {
    test('a prefetched response is served once, under its URL key', () async {
      final session = SourceRequestSession();
      final response = http.Response('[]', 200);
      session.prefetchResponse(
        'https://api.github.com/repos/o/r/releases?per_page=100',
        response,
      );
      expect(
        session.takePrefetchedResponse(
          'https://api.github.com/repos/o/r/releases?per_page=100',
        ),
        same(response),
      );
      expect(
        session.takePrefetchedResponse(
          'https://api.github.com/repos/o/r/releases?per_page=100',
        ),
        isNull,
      );
      expect(
        session.takePrefetchedResponse(
          'https://api.github.com/repos/o/r/tags?per_page=100',
        ),
        isNull,
      );
    });

    test('re-prefetching the same URL keeps the latest answer', () {
      final session = SourceRequestSession();
      session.prefetchResponse('k', http.Response('1', 200));
      session.prefetchResponse('k', http.Response('2', 500));
      expect(session.takePrefetchedResponse('k')!.body, '2');
    });
  });
}
