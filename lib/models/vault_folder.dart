import 'package:flutter/material.dart';

class VaultFolder {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final int itemCount;

  VaultFolder({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.itemCount,
  });

  VaultFolder copyWith({
    String? id,
    String? name,
    IconData? icon,
    Color? color,
    int? itemCount,
  }) {
    return VaultFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      itemCount: itemCount ?? this.itemCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'iconCodePoint': icon.codePoint,
    'iconFontFamily': icon.fontFamily,
    'iconFontPackage': icon.fontPackage,
    'color': color.toARGB32(),
    'itemCount': itemCount,
  };

  factory VaultFolder.fromJson(Map<String, dynamic> json) {
    return VaultFolder(
      id: json['id'],
      name: json['name'],
      icon: IconData(
        json['iconCodePoint'],
        fontFamily: json['iconFontFamily'],
        fontPackage: json['iconFontPackage'],
      ),
      color: Color(json['color']),
      itemCount: json['itemCount'],
    );
  }
}
