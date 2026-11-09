# Security

Omavisor is an Omarchy shell plugin: QML that runs inside your
`omarchy-shell`, with your user's rights and no sandbox. What it can reach,
and what it leaves alone, is listed in the README (Optional tools, Live
activities, and the network notes under Glances).

## Reporting a problem

Please report a security problem privately, not in a public issue: use
**Report a vulnerability** on the public repository's Security tab (GitHub
private vulnerability reporting). Include the Omavisor version
(`omarchy-shell dev.deusvult.omavisor version`), your Omarchy version, and
the steps to reproduce.

You'll get an answer within a week. A confirmed problem is fixed in a new
release, and the release notes say what it was once the fix is out.

## Supported versions

Only the latest release gets fixes.

## What counts

For example: a way for a web page, a media player, a notification or another
user's file to make Omavisor run a command, write outside
`~/.local/state/omavisor/`, or send data anywhere. Omavisor's own network
use is Open-Meteo for the weather and the album art a player links to
(downloaded with limits, README `remoteArt`); anything beyond that is a bug.
