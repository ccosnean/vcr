import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;

import 'package:dio/adapter.dart';
import 'package:dio/dio.dart';
import 'package:vcr/cassette.dart';

const dioHttpHeadersForResponseBody = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

class VcrAdapter extends DefaultHttpClientAdapter {
  String basePath;
  bool createIfNotExists;
  File? _file;

  File get file {
    if (_file == null)
      throw Exception(
          'File not loaded, use `useCassette` or enable creation if not exists with `createIfNotExists` options');

    return _file!;
  }

  VcrAdapter({this.basePath = 'test/cassettes', this.createIfNotExists = true});

  useCassette(path) {
    _file = loadFile(path);
  }

  File loadFile(String path) {
    if (!path.endsWith('.json')) {
      path = "$path.json";
    }

    var paths = path.replaceAll("\"", "/").split('/');

    Directory current = Directory.current;
    String basePath = p.joinAll(
        [current.path, ...this.basePath.replaceAll("\"", "/").split('/')]);

    String cassettePath = p.joinAll(paths);
    String filePath = p.join(basePath, cassettePath);

    return File(filePath);
  }

  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) async {
    if (_file == null && createIfNotExists) useCassette(p.current);

    var data = await _matchRequest(options.uri);

    if (data == null) {
      data = await _makeNormalRequest(options, requestStream, cancelFuture);
    }

    if(data == null){
      throw Exception('Unable to create cassette');
    }

    Map response = data['response'];

    final responsePayload = json.encode(response['body']);

    return ResponseBody.fromString(
      responsePayload,
      response["status"],
      headers: dioHttpHeadersForResponseBody,
    );
  }

  Future<Map?> _makeNormalRequest(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) async {
    ResponseBody responseBody =
        await super.fetch(options, requestStream, cancelFuture);

    var cassette = Cassette(file, responseBody, options);

    await cassette.save();

    return _matchRequest(options.uri);
  }

  List? _readFile() {
    String jsonString = file.readAsStringSync();
    return json.decode(jsonString);
  }

  Future<Map?> _matchRequest(Uri uri) async {
    if(!file.existsSync()) return null;

    String host = uri.host;
    String path = uri.path;
    List requests = _readFile()!;
    return requests.firstWhere((request) {
      Uri uri2 = Uri.parse(request["request"]["url"]);
      return uri2.host == host && uri2.path == path;
    }, orElse: () => null);
  }
}
