# Security policy

Disk Forecast reads your whole disk and can move files to the Trash or delete them, so security reports matter to us.

## Reporting a vulnerability

Please don't open a public issue. Report it privately through GitHub instead: on the repository's **Security** tab, choose **Report a vulnerability**, or go straight to [the private report form](https://github.com/coreyhaines31/diskforecast/security/advisories/new).

Include what you found, how to reproduce it, and which Disk Forecast and macOS versions you tested. Use a test folder, never real files you'd miss. You'll get a reply within a few days, and credit in the release notes once a fix ships, if you'd like it.

## Supported versions

Fixes go into the latest release. The app updates itself through Sparkle, so please check you're on the [current version](https://github.com/coreyhaines31/diskforecast/releases/latest) before reporting.

## In scope

- Files being moved to the Trash or deleted that the user didn't choose, or that the cleanup list should never include (your home folder, standard folders, files a running app has open)
- `diskforecast trash` acting without `--yes`, or on anything not on the cleanup list
- The Claude Desktop extension (`mcpb/`) being able to move or delete anything; it should only read
- Information about your disk leaving the Mac (the only expected network request is the update check)
- The update mechanism, such as installing an update that isn't signed with Disk Forecast's release key
