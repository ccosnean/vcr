import 'package:dio/dio.dart';

class ApiCall {
  Dio client = Dio();

  call() async {
    Response response =
    await client.get('https://api.github.com/users/louis-kevin/repos');

    return response;
  }
}
