import 'package:wsln_annotator/translator.dart';
import 'package:test/test.dart';

void main() {
  test('traslate apple', () async {
    var value = await translate('apple');
    expect(value, '苹果');
  });
}
