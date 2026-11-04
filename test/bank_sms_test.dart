import 'package:flutter_test/flutter_test.dart';
import 'package:masrofy/services/bank_sms.dart';

// Sample messages written in the common shapes Egyptian banks use.
// Card and account digits are made up.
void main() {
  test('English card purchase with available balance', () {
    final m = parseBankSms(
        'Your credit card ending with 1234 was used for EGP 1,250.00 at CARREFOUR MAADI on 04/11/2026 18:22. Available balance EGP 12,345.67');
    expect(m.kind, BankKind.debit);
    expect(m.amount, 1250);
    expect(m.balance, 12345.67);
    expect(m.merchant, 'CARREFOUR MAADI');
    expect(m.cardLast4, '1234');
    expect(m.category, 'food');
  });

  test('Arabic debit with Arabic digits and balance', () {
    final m = parseBankSms('تم خصم مبلغ ٢٥٠٫٥٠ جنيه من حسابك رقم ****5678 لدى اوبر بتاريخ ٠٤/١١ الرصيد المتاح ٩٬٨٠٠٫٠٠ جنيه');
    expect(m.kind, BankKind.debit);
    expect(m.amount, 250.5);
    expect(m.balance, 9800);
    expect(m.merchant, 'اوبر');
    expect(m.category, 'transport');
  });

  test('Salary credit', () {
    final m = parseBankSms('Your account **9012 has been credited with EGP 9,000.00 salary on 25/11. Avail Bal: EGP 18,200.00');
    expect(m.kind, BankKind.credit);
    expect(m.amount, 9000);
    expect(m.balance, 18200);
  });

  test('Arabic deposit', () {
    final m = parseBankSms('تم إيداع ٥٠٠ ج.م في حسابك. رصيدك الحالي ١٥٠٠ ج.م');
    expect(m.kind, BankKind.credit);
    expect(m.amount, 500);
    expect(m.balance, 1500);
  });

  test('ATM withdrawal', () {
    final m = parseBankSms('ATM withdrawal of LE 2000 from card ending 4321. Balance LE 7000');
    expect(m.kind, BankKind.debit);
    expect(m.amount, 2000);
    expect(m.balance, 7000);
  });

  test('balance-only message', () {
    final m = parseBankSms('رصيدك المتاح هو 3,250.00 جنيه');
    expect(m.hasTransaction, false);
    expect(m.balance, 3250);
    expect(m.isUseful, true);
  });

  test('not a bank message', () {
    final m = parseBankSms('هنتقابل الساعة 8');
    expect(m.isUseful, false);
  });

  test('vodafone bill guessed as mobile', () {
    final m = parseBankSms('Purchase of EGP 300.00 at VODAFONE EGYPT using card **1111');
    expect(m.category, 'mobile');
  });

  test('link round trip', () {
    const t = 'تم خصم 100 جنيه';
    expect(textFromBankLink(bankLink(t)), t);
    expect(textFromBankLink(Uri.parse('https://example.com')), isNull);
  });

  test('same message gives same fingerprint', () {
    expect(parseBankSms(' abc EGP 5 ').fingerprint, parseBankSms('abc EGP 5').fingerprint);
  });

  test('merchant after "your card ending" in Arabic', () {
    final m = parseBankSms('تم خصم مبلغ 1,250.00 جنيه من بطاقتك المنتهية ب 4321 لدى كارفور المعادي. الرصيد المتاح 3,130.00 جنيه');
    expect(m.merchant, 'كارفور المعادي');
    expect(m.amount, 1250);
    expect(m.balance, 3130);
    expect(m.category, 'food');
  });
}
