/// Where a player fetches a media file, and the headers it must send (a
/// provider's session) — so it can stream rather than download first.
typedef MediaRequest = ({Uri uri, Map<String, String> headers});
