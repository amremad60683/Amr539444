/// Reads the transaction text messages banks send (Arabic or English) and
/// pulls out what the app needs. Read-only: nothing here talks to a bank.
///
/// Formats differ between banks, so this is deliberately tolerant: it looks
/// for an amount next to a currency, decides debit/credit from keywords,
/// and reads the available balance when the message includes one.
library;

enum BankKind { debit, credit, unknown }

class BankMessage {
  BankMessage({
    required this.raw,
    required this.kind,
    this.amount,
    this.balance,
    this.merchant,
    this.cardLast4,
    this.category = 'other',
  });

  final String raw;
  final BankKind kind;

  /// Amount of the transaction.
  final double? amount;

  /// Available balance after the transaction, when the bank sends it.
  final double? balance;

  final String? merchant;
  final String? cardLast4;

  /// Guessed category id.
  final String category;

  bool get hasTransaction => amount != null && kind != BankKind.unknown;
  bool get isUseful => hasTransaction || balance != null;

  /// Stable id used to ignore the same message twice.
  String get fingerprint {
    var h = 0;
    for (final c in raw.trim().codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return '${raw.trim().length}-$h';
  }
}

String _normalize(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  for (var i = 0; i < 10; i++) {
    s = s.replaceAll(ar[i], '$i').replaceAll(fa[i], '$i');
  }
  return s.replaceAll('٫', '.').replaceAll('٬', ',').replaceAll('‏', '').replaceAll('‎', '');
}

const _currency = r'(?:EGP|E\.G\.P|L\.?E\.?|جنيه(?:اً|ا)?|جنيهات|ج\.?\s?م\.?)';
const _number = r'(\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?)';

final _amountRe = RegExp(
  '(?:$_currency\\s*$_number)|(?:$_number\\s*$_currency)',
  caseSensitive: false,
);

final _balanceKw = RegExp(
  r'(available\s+balance|avail(?:able)?\.?\s*bal(?:ance)?|current\s+balance|\bbalance\b|\bbal\b|الرصيد\s*المتاح|رصيدك\s*المتاح|الرصيد\s*الحالي|رصيدك|الرصيد|رصيد)',
  caseSensitive: false,
);

final _debitKw = RegExp(
  r'(debited|debit|was\s+used|used\s+for|purchase|purchased|withdrawal|withdrawn|withdraw|spent|paid|payment|charged|\bpos\b|\batm\b|transfer(?:red)?\s+to|خصم|استخدام|تم\s*سحب|سحب|شراء|عملية\s*شراء|دفع|سداد|مدين|تحويل\s*صادر|حوالة\s*صادرة)',
  caseSensitive: false,
);

final _creditKw = RegExp(
  r'(credited|credit(?!\s*card)|deposit(?:ed)?|received|salary|refund(?:ed)?|reversal|transfer(?:red)?\s+from|إيداع|ايداع|إضافة|اضافة|أضيف|اضيف|دائن|تحويل\s*وارد|حوالة\s*واردة|استرداد|مرتب|راتب)',
  caseSensitive: false,
);

final _merchantEn = RegExp(r'\bat\s+([A-Za-z0-9&\-\.\x27 ]{2,40}?)(?=\s+on\b|\s+dated\b|\s+using\b|[,.;\n]|$)',
    caseSensitive: false);
final _merchantArKw = RegExp(r'(?:لدى|لدي|عند|لصالح|في|من)\s+');
final _merchantArValue = RegExp(r'([^\n،,.;:]{2,40}?)(?=\s+(?:بتاريخ|يوم|في|لدى|لدي|الساعة|بمبلغ|رصيد|الرصيد)|[،,.;\n]|$)');

final _card = RegExp(
  r'(?:\*{2,}|x{2,}|ending(?:\s+with)?|ending\s+in|المنتهية\s*ب|المنتهي\s*ب|رقم)\s*(\d{4})',
  caseSensitive: false,
);

double _toDouble(String v) => double.parse(v.replaceAll(',', ''));

BankMessage parseBankSms(String input) {
  final raw = input.trim();
  final text = _normalize(raw);

  // All amounts with a currency, in order.
  final amounts = <({int start, double value})>[];
  for (final m in _amountRe.allMatches(text)) {
    final v = m.group(1) ?? m.group(2);
    if (v != null) amounts.add((start: m.start, value: _toDouble(v)));
  }

  // The balance is the first amount after a balance keyword.
  double? balance;
  int? balanceAt;
  for (final k in _balanceKw.allMatches(text)) {
    final after = amounts.where((a) => a.start >= k.start && a.start - k.end < 30);
    if (after.isNotEmpty) {
      balance = after.first.value;
      balanceAt = after.first.start;
      break;
    }
  }

  // The transaction amount: the first amount that isn't the balance.
  final txn = amounts.where((a) => a.start != balanceAt).toList();
  final amount = txn.isEmpty ? null : txn.first.value;

  // Debit or credit: whichever keyword comes first.
  final d = _debitKw.firstMatch(text);
  final c = _creditKw.firstMatch(text);
  BankKind kind;
  if (d == null && c == null) {
    kind = BankKind.unknown;
  } else if (c == null) {
    kind = BankKind.debit;
  } else if (d == null) {
    kind = BankKind.credit;
  } else {
    kind = c.start < d.start ? BankKind.credit : BankKind.debit;
  }

  String? merchant = _merchantEn.firstMatch(text)?.group(1)?.trim();
  if (merchant == null || merchant.isEmpty) {
    merchant = null;
    // Skip matches that are part of the account, card or amount.
    final skip = RegExp(r'\d|\*|حساب|بطاق|كارت|كرت|المنتهي|جنيه|ج\.م|EGP|رصيد', caseSensitive: false);
    for (final k in _merchantArKw.allMatches(text)) {
      final m = _merchantArValue.matchAsPrefix(text, k.end);
      if (m == null) continue;
      final v = m.group(1)!.trim();
      if (!skip.hasMatch(v)) {
        merchant = v;
        break;
      }
    }
  }

  return BankMessage(
    raw: raw,
    kind: amount == null ? BankKind.unknown : kind,
    amount: amount,
    balance: balance,
    merchant: merchant,
    cardLast4: _card.firstMatch(text)?.group(1),
    category: guessCategory('${merchant ?? ''} $text'),
  );
}

/// Merchant / keyword -> category id.
const _rules = <String, List<String>>{
  'food': [
    'carrefour', 'spinneys', 'seoudi', 'metro market', 'kheir zaman', 'hyperone', 'oscar', 'gourmet',
    'talabat', 'elmenus', 'breadfast', 'mcdonald', 'kfc', 'hardee', 'burger', 'pizza', 'cafe', 'coffee',
    'starbucks', 'costa', 'cilantro', 'restaurant', 'bakery', 'كارفور', 'سبينيس', 'سعودي', 'مترو',
    'طلبات', 'مطعم', 'كافيه', 'سوبر ماركت', 'ماركت', 'مخبز',
  ],
  'transport': [
    'uber', 'careem', 'indrive', 'swvl', 'didi', 'bolt', 'shell', 'totalenergies', 'total ', 'mobil',
    'wataniya', 'chillout', 'emarat misr', 'petrol', 'fuel', 'parking', 'metro ticket', 'اوبر', 'أوبر',
    'كريم', 'بنزين', 'وطنية', 'شل ', 'موبيل', 'جراج',
  ],
  'mobile': ['vodafone', 'orange', 'etisalat', 'e& ', ' we ', 'telecom egypt', 'فودافون', 'اورنج', 'أورنج', 'اتصالات', 'المصرية للاتصالات'],
  'bills': ['electricity', 'fawry', 'water', 'natural gas', 'kahraba', 'كهرباء', 'فوري', 'مياه', 'غاز', 'فاتورة'],
  'health': ['pharmacy', 'el ezaby', 'seif', '19011', 'hospital', 'clinic', 'lab', 'صيدلية', 'العزبي', 'سيف', 'مستشفى', 'عيادة', 'معمل'],
  'beauty': ['sephora', 'faces', 'bath & body', 'mac cosmetics', 'mikyajy', 'loreal', 'beauty', 'مكياج', 'تجميل'],
  'salon': ['salon', 'barber', 'spa', 'كوافير', 'صالون', 'حلاق'],
  'clothes': ['zara', 'h&m', 'lc waikiki', 'defacto', 'max fashion', 'bershka', 'pull&bear', 'american eagle', 'ملابس'],
  'shopping': ['amazon', 'noon', 'jumia', 'b.tech', 'btech', 'raya', 'mall', 'أمازون', 'امازون', 'نون', 'جوميا'],
  'home': ['ikea', 'home centre', 'homzmart', 'ايكيا'],
  'fun': ['cinema', 'vox', 'netflix', 'spotify', 'shahid', 'anghami', 'playstation', 'steam', 'سينما', 'شاهد'],
  'study': ['school', 'university', 'course', 'udemy', 'coursera', 'مدرسة', 'جامعة', 'كورس'],
};

String guessCategory(String text) {
  final t = ' ${_normalize(text).toLowerCase()} ';
  for (final e in _rules.entries) {
    for (final k in e.value) {
      if (t.contains(k)) return e.key;
    }
  }
  return 'other';
}

/// Builds the link an iPhone Shortcut opens with a message's text.
Uri bankLink(String text) => Uri(scheme: 'masrofy', host: 'bank', queryParameters: {'text': text});

/// Reads the message text from a `masrofy://bank?text=...` link.
String? textFromBankLink(Uri uri) {
  if (uri.scheme != 'masrofy') return null;
  if (uri.host != 'bank' && !uri.path.contains('bank')) return null;
  final t = uri.queryParameters['text'];
  return (t == null || t.trim().isEmpty) ? null : t;
}
