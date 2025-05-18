import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Region {
  final String name;
  final String nameEn;
  final int id;

  Region({
    required this.name,
    required this.nameEn,
    required this.id,
  });

  factory Region.fromJson(Map<String, dynamic> json) {
    return Region(
      name: json['name']?.toString() ?? '',
      nameEn: json['name_en']?.toString() ?? '',
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'name_en': nameEn,
      'id': id,
    };
  }

  @override
  String toString() {
    return 'Region(name: $name, nameEn: $nameEn, id: $id)';
  }
}

class Province {
  final String name;
  final String fullName;
  final String nameEn;
  final String code;
  final String type;

  Province({
    required this.name,
    required this.fullName,
    required this.nameEn,
    required this.code,
    required this.type,
  });

  factory Province.fromJson(Map<String, dynamic> json) {
    return Province(
      name: json['name']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? json['name']?.toString() ?? '',
      nameEn: json['name_en']?.toString() ?? json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      type: json['division_type']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'full_name': fullName,
      'name_en': nameEn,
      'code': code,
      'type': type,
    };
  }

  @override
  String toString() {
    return 'Province(name: $name, fullName: $fullName, nameEn: $nameEn, code: $code, type: $type)';
  }
}

class District {
  final String name;
  final String code;
  final String provinceCode;

  District({
    required this.name,
    required this.code,
    required this.provinceCode,
  });

  factory District.fromJson(Map<String, dynamic> json) {
    return District(
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      provinceCode: json['province_code']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'code': code,
      'province_code': provinceCode,
    };
  }

  @override
  String toString() {
    return 'District(name: $name, code: $code, provinceCode: $provinceCode)';
  }
}

// Model cho phường/xã
class Ward {
  final String name;
  final String code;
  final String districtCode;

  Ward({
    required this.name,
    required this.code,
    required this.districtCode,
  });

  factory Ward.fromJson(Map<String, dynamic> json) {
    return Ward(
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      districtCode: json['district_code']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'code': code,
      'district_code': districtCode,
    };
  }

  @override
  String toString() {
    return 'Ward(name: $name, code: $code, districtCode: $districtCode)';
  }
}



// Hàm lấy danh sách tỉnh/thành từ API hoặc cache
Future<List<Province>> fetchProvinces() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? cachedData = prefs.getString('cached_provinces');

  if (cachedData != null) {
    return compute(parseProvinces, cachedData); // Dùng cache
  }

  try {
    final url = Uri.parse('https://provinces.open-api.vn/api/p/');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      String data = utf8.decode(response.bodyBytes);
      await prefs.setString('cached_provinces', data); // Lưu vào cache
      return compute(parseProvinces, data);
    } else {
      throw Exception('Lỗi tải tỉnh/thành: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Lỗi tải danh sách tỉnh/thành: $e');
  }
}

// Hàm lấy danh sách quận/huyện từ API hoặc cache
Future<List<District>> fetchDistricts(String provinceCode) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? cachedData = prefs.getString('cached_districts_$provinceCode');

  if (cachedData != null) {
    return compute(parseDistricts, cachedData);
  }

  try {
    final url = Uri.parse('https://provinces.open-api.vn/api/p/$provinceCode?depth=2');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      String data = utf8.decode(response.bodyBytes);
      await prefs.setString('cached_districts_$provinceCode', data);
      return compute(parseDistricts, data);
    } else {
      throw Exception('Lỗi tải quận/huyện: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Lỗi tải danh sách quận/huyện: $e');
  }
}

// Hàm lấy danh sách phường/xã từ API hoặc cache
Future<List<Ward>> fetchWards(String districtCode) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? cachedData = prefs.getString('cached_wards_$districtCode');

  if (cachedData != null) {
    return compute(parseWards, cachedData);
  }

  try {
    final url = Uri.parse('https://provinces.open-api.vn/api/d/$districtCode?depth=2');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      String data = utf8.decode(response.bodyBytes);
      await prefs.setString('cached_wards_$districtCode', data);
      return compute(parseWards, data);
    } else {
      throw Exception('Lỗi tải phường/xã: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Lỗi tải danh sách phường/xã: $e');
  }
}

// Hàm xóa cache khi cần cập nhật dữ liệu mới
Future<void> clearCache() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.remove('cached_provinces');
  await prefs.clear(); // Xóa toàn bộ cache
}

// Hàm parse dữ liệu
List<Province> parseProvinces(String responseBody) {
  final List<dynamic> data = jsonDecode(responseBody);
  return data.map((json) => Province.fromJson(json)).toList();
}

List<District> parseDistricts(String responseBody) {
  final Map<String, dynamic> data = jsonDecode(responseBody);
  List<dynamic> districts = data['districts'] ?? [];
  return districts.map((json) => District.fromJson(json)).toList();
}

List<Ward> parseWards(String responseBody) {
  final Map<String, dynamic> data = jsonDecode(responseBody);
  List<dynamic> wards = data['wards'] ?? [];
  return wards.map((json) => Ward.fromJson(json)).toList();
}
