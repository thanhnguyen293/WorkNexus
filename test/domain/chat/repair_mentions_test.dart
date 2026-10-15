import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/domain/usecases/parse_message_content.dart';

String _randomEnglishUsername(Random random) {
  const firstNames = [
    'Alexander',
    'Benjamin',
    'Charlotte',
    'Daniel',
    'Evelyn',
    'Fiona',
    'Gabriel',
    'Hannah',
    'Ian',
    'Jessica',
    'Liam',
    'Mason',
    'Natalie',
    'Oliver',
    'Penelope',
    'Quinn',
    'Rachel',
    'Samuel',
    'Thomas',
    'Victoria',
  ];
  const lastNames = [
    'Smith',
    'Johnson',
    'Williams',
    'Brown',
    'Jones',
    'Miller',
    'Davis',
    'Wilson',
    'Anderson',
    'Taylor',
    'Thomas',
    'Moore',
    'Jackson',
    'Martin',
    'Lee',
    'Clark',
    'Lewis',
    'Walker',
    'Hall',
    'Allen',
  ];
  const suffixes = [
    'Dev',
    'QA',
    'Lead',
    'Eng',
    'Arch',
    'Ops',
    'Design',
    'Product',
    'Core',
    'Sec',
  ];

  final first = firstNames[random.nextInt(firstNames.length)];
  final last = lastNames[random.nextInt(lastNames.length)];
  final suffix = suffixes[random.nextInt(suffixes.length)];
  final id = random.nextInt(900) + 100;

  switch (random.nextInt(3)) {
    case 0:
      return '${first}_$last';
    case 1:
      return '$first-$last-$suffix';
    default:
      return '${first}_${suffix}_$id';
  }
}

List<String> _generateUniqueEnglishNames(Random random, int count) {
  final names = <String>{};
  while (names.length < count) {
    names.add(_randomEnglishUsername(random));
  }
  return names.toList();
}

void main() {
  test('drops the name tail the official client leaves after a mention', () {
    final random = Random(101);
    for (var i = 0; i < 5; i++) {
      final first = _randomEnglishUsername(random).split(RegExp(r'[-_]')).first;
      final last = _randomEnglishUsername(random).split(RegExp(r'[-_]')).first;
      final role = ['Dev', 'Lead', 'Arch', 'Ops', 'QA'][random.nextInt(5)];
      final name = '$first-$last-$role';
      final tail = '-$last-$role';
      final id = 10 + random.nextInt(900);
      final otherName = _randomEnglishUsername(random);
      final otherId = 10 + random.nextInt(900);

      expect(
        ParseMessageContent.repairMentions(
          'hi [@$name](@#$id)$tail, ok [@$otherName](@#$otherId) done',
        ),
        'hi [@$name](@#$id), ok [@$otherName](@#$otherId) done',
      );
    }
  });

  test('unwraps a mention nested in another link to the same user', () {
    final random = Random(202);
    for (var i = 0; i < 5; i++) {
      final name = _randomEnglishUsername(random);
      final id = 10 + random.nextInt(900);
      final suffix = '-Tail${random.nextInt(100)}';

      expect(
        ParseMessageContent.repairMentions(
          '[[@$name](@#$id)$suffix](@#$id) task complete',
        ),
        '[@$name](@#$id) task complete',
      );
    }
  });

  test('drops a tail that starts with a space', () {
    final random = Random(303);
    for (var i = 0; i < 5; i++) {
      final first = _randomEnglishUsername(random).split(RegExp(r'[-_]')).first;
      final last = _randomEnglishUsername(random).split(RegExp(r'[-_]')).first;
      final role = ['Dev', 'Lead', 'QA'][random.nextInt(3)];
      final name = '$first $last-$role';
      final tail = ' $last-$role';
      final id = 10 + random.nextInt(900);

      expect(
        ParseMessageContent.repairMentions(
          'hello [@$name](@#$id)$tail resolved',
        ),
        'hello [@$name](@#$id) resolved',
      );
    }
  });

  test('keeps text that is not a repeated tail', () {
    final random = Random(404);
    for (var i = 0; i < 5; i++) {
      final name = _randomEnglishUsername(random);
      final id1 = 10 + random.nextInt(900);
      final id2 = 10 + random.nextInt(900);
      final text = '[@$name](@#$id1) info [@Module-Core](@#$id2)-Detail';

      expect(ParseMessageContent.repairMentions(text), text);
    }
  });

  test(
    'inserts spaces between adjacent markdown mentions (random English names)',
    () {
      final random = Random(42);
      const prefixes = ['cc: ', 'fyi: ', 'to: ', 'review: ', ''];

      for (var round = 0; round < 10; round++) {
        final userCount = 2 + random.nextInt(4); // 2 to 5 users
        final prefix = prefixes[random.nextInt(prefixes.length)];
        final selectedNames = _generateUniqueEnglishNames(random, userCount);
        final users = [
          for (var i = 0; i < selectedNames.length; i++)
            (name: selectedNames[i], id: 10 + random.nextInt(900)),
        ];

        final input =
            '$prefix${users.map((u) => '[@${u.name}](@#${u.id})').join()}';
        final expected =
            '$prefix${users.map((u) => '[@${u.name}](@#${u.id})').join(' ')}';

        expect(ParseMessageContent.repairMentions(input), expected);
      }
    },
  );

  test(
    'inserts spaces between adjacent plain text mentions (random English names)',
    () {
      final random = Random(99);
      const prefixes = ['cc: ', 'fyi: ', 'to: ', 'review: ', ''];

      for (var round = 0; round < 10; round++) {
        final userCount = 2 + random.nextInt(4); // 2 to 5 users
        final prefix = prefixes[random.nextInt(prefixes.length)];
        final selectedNames = _generateUniqueEnglishNames(random, userCount);

        final input = '$prefix${selectedNames.map((n) => '@$n').join()}';
        final expected = '$prefix${selectedNames.map((n) => '@$n').join(' ')}';

        expect(ParseMessageContent.repairMentions(input), expected);
      }
    },
  );
}
