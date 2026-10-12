/// The local id of ZenTao [type] (`bug`, `task`, `story`) [id] of
/// [accountId]. Bugs, tasks and stories number independently, so the type is
/// part of the id: bug #6492 and task #6492 are different tickets.
String zenTaoTicketId(String accountId, String type, String id) =>
    '$accountId:${type.toLowerCase()}:$id';
