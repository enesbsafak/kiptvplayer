# Security

Please do not open a public issue for a vulnerability. Report it privately
through GitHub: **Security › Report a vulnerability** on this repository
(private vulnerability reporting). You will get an answer within a week.

In scope: credential handling (OS keyring, backups), the updater (feed,
SHA-256 check, installer), parsing of provider data (M3U, XMLTV, Xtream,
Stalker) and anything that runs code or reads files it should not.

Provider passwords, MAC addresses and API keys never leave the device except
to the provider the user added; the app has no telemetry.
