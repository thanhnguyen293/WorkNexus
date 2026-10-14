import '../../../../core/domain/value_objects/ticket_sort.dart';

/// [sort] as the `orderBy` slot of ZenTao's classic task / bug list URLs
/// (`pri_asc`, `lastEditedDate_desc`, …). A field the list cannot sort by
/// (a bug's hours, a task's severity) falls back to the id.
String zentaoOrderBy(TicketSort sort, {required bool bug}) {
  final field = switch (sort.field) {
    TicketSortField.id => 'id',
    TicketSortField.title => bug ? 'title' : 'name',
    TicketSortField.priority => 'pri',
    TicketSortField.severity => bug ? 'severity' : 'id',
    TicketSortField.status => 'status',
    TicketSortField.assignee => 'assignedTo',
    TicketSortField.estimate => bug ? 'id' : 'estimate',
    TicketSortField.left => bug ? 'id' : 'left',
    TicketSortField.resolution => bug ? 'resolution' : 'id',
    TicketSortField.updated => 'lastEditedDate',
  };
  return '${field}_${sort.descending ? 'desc' : 'asc'}';
}
