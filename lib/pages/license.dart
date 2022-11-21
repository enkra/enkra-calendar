import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../oss_licenses.dart';

class OssLicensesPage extends StatelessWidget {
  const OssLicensesPage({
    Key? key,
  }) : super(key: key);

  static Future<List<String>> loadLicenses() async {
    final ossKeys = ossLicenses.keys.toList();
    final lm = <String, List<String>>{};

    // merging non-dart based dependency list using LicenseRegistry.
    await for (var l in LicenseRegistry.licenses) {
      for (var p in l.packages) {
        if (!ossKeys.contains(p)) {
          final lp = lm.putIfAbsent(p, () => []);
          lp.addAll(l.paragraphs.map((p) => p.text));
          ossKeys.add(p);
        }
      }
    }
    for (var key in lm.keys) {
      ossLicenses[key] = {'license': lm[key]?.join('\n')};
    }

    // filter no lincense info item
    ossLicenses.removeWhere((key, value) {
      return value['license'] == null;
    });

    final keys = ossLicenses.keys.toList();
    return keys..sort();
  }

  static final _licenses = loadLicenses();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Open Source Licenses'),
        ),
        body: FutureBuilder<List<String>>(
            future: _licenses,
            builder: (context, snapshot) {
              return ListView.separated(
                  padding: const EdgeInsets.all(0),
                  itemCount: snapshot.data?.length ?? 0,
                  itemBuilder: (context, index) {
                    final key = snapshot.data![index];
                    final licenseJson = ossLicenses[key];
                    final version = licenseJson['version'];
                    final desc = licenseJson['description'];
                    return ListTile(
                        title: Text('$key ${version ?? ''}'),
                        subtitle: desc != null ? Text(desc) : null,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (context) => MiscOssLicenseSingle(
                                    name: key, json: licenseJson))));
                  },
                  separatorBuilder: (context, index) => const Divider());
            }));
  }
}

class MiscOssLicenseSingle extends StatelessWidget {
  final String name;
  final Map<String, dynamic> json;

  String get version => json['version'] ?? "";
  String? get description => json['description'];
  String? get licenseText => json['license'];
  String? get homepage => json['homepage'];

  const MiscOssLicenseSingle({
    Key? key,
    required this.name,
    required this.json,
  }) : super(key: key);

  String? _bodyText() {
    return licenseText?.split('\n').map((line) {
      if (line.startsWith('//')) line = line.substring(2);
      line = line.trim();
      return line;
    }).join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$name $version')),
      body: Container(
          color: Theme.of(context).canvasColor,
          child: ListView(children: <Widget>[
            if (description != null)
              Padding(
                  padding:
                      const EdgeInsets.only(top: 12.0, left: 12.0, right: 12.0),
                  child: Text(description!,
                      style: Theme.of(context)
                          .textTheme
                          .bodyText2
                          ?.copyWith(fontWeight: FontWeight.bold))),
            if (homepage != null)
              Padding(
                  padding:
                      const EdgeInsets.only(top: 12.0, left: 12.0, right: 12.0),
                  child: InkWell(
                    child: Text(homepage!,
                        style: const TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline)),
                    onTap: () => launch(homepage!),
                  )),
            if (description != null || homepage != null) const Divider(),
            Padding(
              padding:
                  const EdgeInsets.only(top: 12.0, left: 12.0, right: 12.0),
              child: Text(_bodyText()!,
                  style: Theme.of(context).textTheme.bodyText2),
            ),
          ])),
    );
  }
}
