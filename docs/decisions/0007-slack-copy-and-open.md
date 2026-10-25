# 7. Share to Slack copies the image and opens Slack

**Decision:** "Slack" in the share menu copies the image (and caption) to the clipboard and opens Slack with `slack://open`. You paste with ⌘V. Snaps can also be dragged into Slack.

**Why:** Slack for Mac (checked: 4.49.81, direct download) registers no macOS share extension, so it never appears in the system share menu. Slack's documented deep links open workspaces, channels and existing files but cannot upload a new file (docs.slack.dev/interactivity/deep-linking).

**Rejected:** uploading through the Slack API. It needs a registered Slack app, sign-in and a stored token, which breaks "no account".
