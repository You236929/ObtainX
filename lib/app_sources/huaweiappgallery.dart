import 'dart:convert';
import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart';
import 'package:obtainium/custom_errors.dart';
import 'package:obtainium/providers/source_provider.dart';

class HuaweiAppGallery extends AppSource {
  String? _interfaceCode;
  String? _identityId;

  HuaweiAppGallery() {
    name = tr('huaweiAppGallery');
    hosts = ['appgallery.huawei.com', 'appgallery.cloud.huawei.com'];
    versionDetectionDisallowed = true;
    showReleaseDateAsVersionToggle = true;
    canSearch = true;
  }

  @override
  String sourceSpecificStandardizeURL(String url, {bool forSelection = false}) {
    RegExp standardUrlRegEx = RegExp(
      '^https?://(www\\.)?${getSourceRegex(hosts)}(/#)?/(app|appdl)/[^/]+',
      caseSensitive: false,
    );
    RegExpMatch? match = standardUrlRegEx.firstMatch(url);
    if (match == null) {
      throw InvalidURLError(name);
    }
    return match.group(0)!;
  }

  String getDlUrl(String standardUrl) =>
      'https://${hosts[0].replaceAll('appgallery.huawei', 'appgallery.cloud.huawei')}/appdl/${standardUrl.split('/').last}';

  Future<Response> requestAppdlRedirect(
    String dlUrl,
    Map<String, dynamic> additionalSettings,
  ) async {
    Response res = await sourceRequest(
      dlUrl,
      additionalSettings,
      followRedirects: false,
    );
    if (res.statusCode == 200 ||
        res.statusCode == 302 ||
        res.statusCode == 304) {
      return res;
    } else {
      throw getObtainiumHttpError(res);
    }
  }

  String appIdFromRedirectDlUrl(String redirectDlUrl) {
    var parts = redirectDlUrl
        .split('?')[0]
        .split('/')
        .last
        .split('.')
        .reversed
        .toList();
    parts.removeAt(0);
    parts.removeAt(0);
    return parts.reversed.join('.');
  }

  @override
  Future<String?> tryInferringAppId(
    String standardUrl, {
    Map<String, dynamic> additionalSettings = const {},
  }) async {
    String dlUrl = getDlUrl(standardUrl);
    Response res = await requestAppdlRedirect(dlUrl, additionalSettings);
    return res.headers['location'] != null
        ? appIdFromRedirectDlUrl(res.headers['location']!)
        : null;
  }

  @override
  Future<APKDetails> getLatestAPKDetails(
    String standardUrl,
    Map<String, dynamic> additionalSettings,
  ) async {
    String dlUrl = getDlUrl(standardUrl);
    Response res = await requestAppdlRedirect(dlUrl, additionalSettings);
    if (res.headers['location'] == null) {
      throw NoReleasesError();
    }
    String appId = appIdFromRedirectDlUrl(res.headers['location']!);
    if (appId.isEmpty) {
      throw NoReleasesError();
    }
    var relDateStr = res.headers['location']
        ?.split('?')[0]
        .split('.')
        .reversed
        .toList()[1];
    if (relDateStr == null || relDateStr.length != 10) {
      throw NoVersionError();
    }
    var relDateStrAdj = relDateStr.split('');
    var tempLen = relDateStrAdj.length;
    var i = 2;
    while (i < tempLen) {
      relDateStrAdj.insert((i + i ~/ 2 - 1), '-');
      i += 2;
    }
    var relDate = DateFormat(
      'yy-MM-dd-HH-mm',
      'en_US',
    ).parse(relDateStrAdj.join(''));
    return APKDetails(
      relDateStr,
      [MapEntry('$appId.apk', dlUrl)],
      AppNames(name, appId),
      releaseDate: relDate,
    );
  }

  @override
  Future<Map<String, String>?> getRequestHeaders(
    Map<String, dynamic> additionalSettings,
    String url, {
    bool forAPKDownload = false,
  }) async {
    var headers = <String, String>{
      'user-agent':
          'Mozilla/5.0 (Linux; Android 16; OPD2405 Build/UKQ1.231108.001; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/147.0.7727.138 Safari/537.36',
      'accept': 'application/json, text/plain, */*',
    };
    if (_interfaceCode != null) {
      headers['Interface-Code'] = _interfaceCode!;
    }
    if (_identityId != null) {
      headers['Identity-Id'] = _identityId!;
    }
    return headers;
  }

  String _generateIdentityId() {
    final rand = Random();
    return List.generate(32, (_) => rand.nextInt(16).toRadixString(16)).join();
  }

  Future<String> _fetchInterfaceCode(
    Map<String, dynamic> additionalSettings,
  ) async {
    _identityId = _generateIdentityId();
    var timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    _interfaceCode = 'null_$timestamp';

    var res = await sourceRequest(
      'https://web-drcn.hispace.dbankcloud.com/edge/webedge/getInterfaceCode',
      additionalSettings,
      postBody: {'params': {}, 'zone': '', 'locale': ''},
    );

    if (res.statusCode != 200) {
      throw getObtainiumHttpError(res);
    }

    var code = jsonDecode(res.body);
    if (code is! String || code.isEmpty) {
      throw NoReleasesError();
    }
    _interfaceCode = code;
    return code;
  }

  @override
  Future<Map<String, List<String>>> search(
    String query, {
    Map<String, dynamic> querySettings = const {},
  }) async {
    await _fetchInterfaceCode(querySettings);
    var encodedQuery = Uri.encodeQueryComponent('searchApp|$query');

    var searchUrl =
        'https://web-drcn.hispace.dbankcloud.com/edge/uowap/index'
        '?method=internal.getTabDetail'
        '&serviceType=20'
        '&reqPageNum=1'
        '&uri=$encodedQuery'
        '&maxResults=25'
        '&version=10.4.1.300'
        '&zone';

    var res = await sourceRequest(searchUrl, querySettings);

    if (res.statusCode != 200) {
      throw getObtainiumHttpError(res);
    }

    var json = jsonDecode(res.body);

    Map<String, List<String>> results = {};

    var layoutData = json['layoutData'] as List<dynamic>?;
    if (layoutData != null) {
      for (var layout in layoutData) {
        var dataList = layout['dataList'] as List<dynamic>?;
        if (dataList != null) {
          for (var item in dataList) {
            var name = item['name']?.toString();
            var detailId = item['detailId']?.toString();
            if (name == null ||
                name.isEmpty ||
                detailId == null ||
                detailId.isEmpty) {
              continue;
            }

            var appId = detailId.split('__').first.replaceFirst('app|', '');
            var url = 'https://appgallery.huawei.com/app/$appId';
            try {
              url = standardizeUrl(url);
            } catch (_) {
              continue;
            }
            var memo = item['memo']?.toString();
            var desc = (memo != null && memo.isNotEmpty)
                ? memo
                : tr('noDescription');

            results[url] = [name, desc];
          }
        }
      }
    }

    return results;
  }
}
