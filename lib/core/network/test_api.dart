import 'package:flutter/material.dart';

import 'api_client.dart';

class TestApi {
  static Future<void> test() async {
    try {
      final response = await ApiClient.get("/");

      debugPrint("STATUS : ${response.statusCode}");
      debugPrint("DATA : ${response.data}");
    } catch (e) {
      debugPrint("ERROR : $e");
    }
  }
}