/// A ZenTao task's hours: estimated, logged so far, and left, plus how far
/// along it is ([progress], 0–1).
typedef TaskEffort = ({
  double estimate,
  double consumed,
  double left,
  double progress,
});
