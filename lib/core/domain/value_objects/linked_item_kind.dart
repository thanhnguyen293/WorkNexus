/// What a GitLab/GitHub link points to: a merge/pull request or an issue.
/// Shared by the chat (which recognises links) and the fetcher (which loads
/// them), since the two kinds use different provider endpoints.
enum LinkedItemKind { mergeRequest, issue }
