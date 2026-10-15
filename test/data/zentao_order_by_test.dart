import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/value_objects/ticket_sort.dart';
import 'package:work_nexus/tools/zentao/data/models/zentao_order_by.dart';

void main() {
  test('maps a sort to the field names of each ZenTao list', () {
    const title = TicketSort(TicketSortField.title, descending: true);
    expect(zentaoOrderBy(title, bug: true), 'title_desc');
    expect(zentaoOrderBy(title, bug: false), 'name_desc');
    expect(
      zentaoOrderBy(const TicketSort(TicketSortField.updated), bug: false),
      'lastEditedDate_asc',
    );
    expect(zentaoOrderBy(TicketSort.newest, bug: true), 'id_desc');
  });

  test('a column the list cannot sort by falls back to the id', () {
    const left = TicketSort(TicketSortField.left);
    expect(zentaoOrderBy(left, bug: true), 'id_asc');
    expect(zentaoOrderBy(left, bug: false), 'left_asc');
  });
}
