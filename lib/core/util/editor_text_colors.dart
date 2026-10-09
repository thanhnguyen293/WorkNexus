/// The colours offered for text and its highlight in the rich-text editor,
/// as the `#rrggbb` values written into the document (content data, not
/// theme colours). Rows run light → strong → deep, then the greys; six
/// columns so the picker lays them out as a grid.
const editorTextColors = [
  '#bfedd2', '#fbeeb8', '#f8cac6', '#eccafa', '#c2e0f4', '#ffffff', //
  '#2dc26b', '#f1c40f', '#e03e2d', '#b96ad9', '#3598db', '#ced4d9', //
  '#169179', '#e67e23', '#ba372a', '#843fa1', '#236fa1', '#95a5a6', //
  '#0e5e4c', '#a04f0c', '#7a1f17', '#4f1f66', '#163e5e', '#000000', //
];

/// Columns of the [editorTextColors] grid.
const editorTextColorColumns = 6;
