// GitHub site-level batch update check.
//
// GitHub's REST API has no multi-repository endpoint, but its GraphQL API
// answers an aliased query for several repositories in one round trip. This
// file builds that query and turns the GraphQL nodes back into the REST shapes
// the GitHub source already parses, so the per-app code path stays unchanged.
//
// Only github.com is covered: GitHub Enterprise hosts keep their own `/api/v3`
// REST root, which the batch path does not model.

import 'dart:convert';

/// Repositories per GraphQL request. Kept small enough that one failed query
/// costs little and the query stays well inside GitHub's node limits.
const int gitHubBatchRepoLimit = 10;

/// Releases per repository, matching the REST list the source requests
/// (`releases?per_page=100`, newest first).
const int gitHubBatchReleasePageSize = 100;

/// Assets per release. A release rarely has more, and REST serves the same
/// order (newest uploaded first is not required: the source picks by name).
const int gitHubBatchAssetPageSize = 30;

/// One repository to look up in a batch.
class GitHubBatchRepo {
  final String owner;
  final String name;

  const GitHubBatchRepo(this.owner, this.name);

  String get nameWithOwner => '$owner/$name';

  @override
  String toString() => nameWithOwner;
}

const String _repositoryFields = '''
    nameWithOwner
    isArchived
    releases(first: $gitHubBatchReleasePageSize, orderBy: {field: CREATED_AT, direction: DESC}) {
      nodes {
        tagName
        name
        description
        isPrerelease
        isDraft
        publishedAt
        createdAt
        releaseAssets(first: $gitHubBatchAssetPageSize) {
          nodes { name size downloadUrl updatedAt createdAt }
        }
      }
    }''';

/// The GraphQL document for [repoCount] repositories, aliased `r0`…`rN-1` so
/// each answer maps back to its request by index.
String gitHubBatchQuery(int repoCount) {
  final StringBuffer variables = StringBuffer();
  final StringBuffer body = StringBuffer();
  for (int i = 0; i < repoCount; i++) {
    if (i > 0) variables.write(', ');
    variables.write('\$o$i: String!, \$n$i: String!');
    body.write('\n  r$i: repository(owner: \$o$i, name: \$n$i) {');
    body.write('\n$_repositoryFields\n  }');
  }
  return 'query ObtainiumBatchUpdate($variables) {$body\n}';
}

/// The variables that go with [gitHubBatchQuery].
Map<String, dynamic> gitHubBatchVariables(List<GitHubBatchRepo> repos) {
  final Map<String, dynamic> variables = {};
  for (int i = 0; i < repos.length; i++) {
    variables['o$i'] = repos[i].owner;
    variables['n$i'] = repos[i].name;
  }
  return variables;
}

/// The `data` object of a GraphQL answer, decoded from [body], or null when the
/// answer is not a GraphQL payload.
Map<String, dynamic>? gitHubBatchData(String body) {
  try {
    final decoded = jsonDecode(body);
    final data = decoded is Map ? decoded['data'] : null;
    return data is Map<String, dynamic> ? data : null;
  } catch (_) {
    return null;
  }
}

/// The repository node answered for index [index], or null when GitHub could
/// not resolve it (deleted, private, renamed away, or an error entry).
Map<String, dynamic>? gitHubBatchRepositoryNode(
  Map<String, dynamic> data,
  int index,
) {
  final node = data['r$index'];
  if (node is! Map) return null;
  final repository = node['repository'];
  return repository is Map<String, dynamic> ? repository : null;
}

/// The REST `/repos/{owner}/{repo}` body for [node], or null when the answer is
/// not for the requested repository (a rename would otherwise be masked: the
/// per-app REST probe detects the redirect and reports the new URL).
Map<String, dynamic>? gitHubRestRepoJson(
  Map<String, dynamic> node,
  GitHubBatchRepo requested,
) {
  final nameWithOwner = node['nameWithOwner'];
  if (nameWithOwner is! String ||
      nameWithOwner.toLowerCase() != requested.nameWithOwner.toLowerCase()) {
    return null;
  }
  final String name = nameWithOwner.split('/').last;
  return {
    'name': name,
    'full_name': nameWithOwner,
    'html_url': 'https://github.com/$nameWithOwner',
    'archived': node['isArchived'] == true,
  };
}

/// The REST `releases?per_page=100` body (a newest-first list) for [node].
List<Map<String, dynamic>> gitHubRestReleasesJson(Map<String, dynamic> node) {
  final releases = node['releases'];
  final nodes = releases is Map ? releases['nodes'] : null;
  if (nodes is! List) return [];
  final List<Map<String, dynamic>> result = [];
  for (final dynamic raw in nodes) {
    if (raw is! Map) continue;
    final assets = raw['releaseAssets'];
    final assetNodes = assets is Map ? assets['nodes'] : null;
    result.add({
      'tag_name': raw['tagName'],
      'name': raw['name'],
      'body': raw['description'],
      'prerelease': raw['isPrerelease'] == true,
      'draft': raw['isDraft'] == true,
      'created_at': raw['createdAt'],
      'published_at': raw['publishedAt'],
      'assets': assetNodes is List
          ? assetNodes
                .whereType<Map>()
                .map(
                  (asset) => {
                    'name': asset['name'],
                    'browser_download_url': asset['downloadUrl'],
                    'size': asset['size'],
                    'updated_at': asset['updatedAt'],
                    'created_at': asset['createdAt'],
                  },
                )
                .toList()
          : <Map<String, dynamic>>[],
    });
  }
  return result;
}
