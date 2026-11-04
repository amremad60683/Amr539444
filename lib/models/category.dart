import 'package:flutter/cupertino.dart';

/// Icons a custom category can use. Kept as a fixed const list so release
/// builds can tree-shake icon fonts (no IconData built from a codepoint).
const categoryIcons = <String, IconData>{
  'cart': CupertinoIcons.cart,
  'bus': CupertinoIcons.bus,
  'car': CupertinoIcons.car,
  'bag': CupertinoIcons.bag,
  'doc': CupertinoIcons.doc_text,
  'film': CupertinoIcons.film,
  'bandage': CupertinoIcons.bandage,
  'paintbrush': CupertinoIcons.paintbrush,
  'scissors': CupertinoIcons.scissors,
  'eyedropper': CupertinoIcons.eyedropper,
  'gift': CupertinoIcons.gift,
  'heart': CupertinoIcons.heart,
  'house': CupertinoIcons.house,
  'book': CupertinoIcons.book,
  'game': CupertinoIcons.gamecontroller,
  'phone': CupertinoIcons.device_phone_portrait,
  'wifi': CupertinoIcons.wifi,
  'bolt': CupertinoIcons.bolt,
  'drop': CupertinoIcons.drop,
  'paw': CupertinoIcons.paw,
  'airplane': CupertinoIcons.airplane,
  'briefcase': CupertinoIcons.briefcase,
  'music': CupertinoIcons.music_note,
  'person2': CupertinoIcons.person_2,
  'star': CupertinoIcons.star,
  'tag': CupertinoIcons.tag,
  'sportscourt': CupertinoIcons.sportscourt,
  'smiley': CupertinoIcons.smiley,
  'more': CupertinoIcons.ellipsis,
};

/// A spending category: built-in or created by the user.
class CategoryDef {
  const CategoryDef({
    required this.id,
    required this.ar,
    required this.en,
    required this.iconKey,
    this.custom = false,
  });

  final String id;
  final String ar;
  final String en;
  final String iconKey;
  final bool custom;

  IconData get icon => categoryIcons[iconKey] ?? CupertinoIcons.ellipsis;
  String label(bool isAr) => isAr ? ar : en;

  Map<String, dynamic> toJson() => {'id': id, 'ar': ar, 'en': en, 'icon': iconKey};

  factory CategoryDef.fromJson(Map<String, dynamic> j) => CategoryDef(
        id: j['id'] as String,
        ar: j['ar'] as String,
        en: j['en'] as String,
        iconKey: j['icon'] as String? ?? 'tag',
        custom: true,
      );
}

/// Built-in categories. Ids of the first version (food, transport, shopping,
/// bills, fun, health, other) are kept so old entries still resolve.
const builtInCategories = <CategoryDef>[
  CategoryDef(id: 'food', ar: 'أكل', en: 'Food', iconKey: 'cart'),
  CategoryDef(id: 'transport', ar: 'مواصلات', en: 'Transport', iconKey: 'bus'),
  CategoryDef(id: 'shopping', ar: 'مشتريات', en: 'Shopping', iconKey: 'bag'),
  CategoryDef(id: 'clothes', ar: 'لبس', en: 'Clothes', iconKey: 'tag'),
  CategoryDef(id: 'beauty', ar: 'مكياج وعناية', en: 'Beauty & care', iconKey: 'paintbrush'),
  CategoryDef(id: 'salon', ar: 'كوافير وحلاقة', en: 'Salon & barber', iconKey: 'scissors'),
  CategoryDef(id: 'bills', ar: 'فواتير', en: 'Bills', iconKey: 'doc'),
  CategoryDef(id: 'mobile', ar: 'موبايل ونت', en: 'Phone & internet', iconKey: 'wifi'),
  CategoryDef(id: 'home', ar: 'البيت', en: 'Home', iconKey: 'house'),
  CategoryDef(id: 'fun', ar: 'خروج', en: 'Going out', iconKey: 'film'),
  CategoryDef(id: 'gifts', ar: 'هدايا', en: 'Gifts', iconKey: 'gift'),
  CategoryDef(id: 'health', ar: 'صحة', en: 'Health', iconKey: 'bandage'),
  CategoryDef(id: 'kids', ar: 'الأطفال', en: 'Kids', iconKey: 'smiley'),
  CategoryDef(id: 'study', ar: 'دراسة', en: 'Study', iconKey: 'book'),
  CategoryDef(id: 'other', ar: 'أخرى', en: 'Other', iconKey: 'more'),
];

/// One hue per category, used for its icon tile and its bar.
const _categoryColors = <String, Color>{
  'food': Color(0xFFF2763A),
  'transport': Color(0xFF3B82F6),
  'shopping': Color(0xFF8B5CF6),
  'clothes': Color(0xFFEC4899),
  'beauty': Color(0xFFDB2777),
  'salon': Color(0xFFA855F7),
  'bills': Color(0xFF0EA5E9),
  'mobile': Color(0xFF06B6D4),
  'home': Color(0xFF65A30D),
  'fun': Color(0xFFF59E0B),
  'gifts': Color(0xFFEF4444),
  'health': Color(0xFF10B981),
  'kids': Color(0xFFEAB308),
  'study': Color(0xFF6366F1),
  'other': Color(0xFF8A8FA8),
};

const _customPalette = [
  Color(0xFF14B8A6), Color(0xFFF43F5E), Color(0xFF0EA5E9), Color(0xFFA855F7),
  Color(0xFF84CC16), Color(0xFFF97316), Color(0xFF6366F1), Color(0xFFEC4899),
];

extension CategoryColor on CategoryDef {
  Color get color =>
      _categoryColors[id] ?? _customPalette[id.codeUnits.fold(0, (a, c) => a + c) % _customPalette.length];
}
