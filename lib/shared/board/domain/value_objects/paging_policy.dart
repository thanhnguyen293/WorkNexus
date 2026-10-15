/// Tickets per page of a column's view: enough to fill a column, small enough
/// that the board shows up quickly.
const kPagedViewPageSize = 50;

/// Pages a filtered board fetches per load, side by side: a filter hides most
/// of each page, so one load scans more of the view at once.
const kFilteredPagesPerLoad = 4;

/// How many loads in a row a filtered column fetches by itself while they add
/// no visible card; then it waits for "Load more", so a filter that matches
/// little never pulls a whole view down unasked.
const kMaxDryLoads = 2;
