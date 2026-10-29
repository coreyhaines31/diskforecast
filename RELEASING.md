# Releasing

For maintainers. Releases are cut from `main` after `development` is merged into it.

```sh
git checkout main && git pull
NOTARY_PROFILE=midnightoil-notary Scripts/release.sh 1.2.1
```

`Scripts/release.sh` then:

1. Archives the app and exports it with Developer ID signing (cloud-managed, so no certificate lives on the machine).
2. Notarizes and staples the app, builds the DMG, and notarizes and staples that.
3. Checks the app inside the DMG with Gatekeeper.
4. Signs the update with Sparkle and writes `appcast.xml`.
5. Packs the Claude Desktop extension (`mcpb/dist/diskforecast.mcpb`) and publishes a GitHub release `v<version>` with the DMG, `appcast.xml`, and `diskforecast.mcpb`. The README and website link to `releases/latest/download/diskforecast.mcpb`, so every release needs it.
6. Bumps the version and checksum in the Homebrew cask.

The build number is the commit count, so it always goes up.

## One-time setup

- **Xcode:** signed in to the team in Settings › Accounts, or `ASC_KEY_PATH`, `ASC_KEY_ID`, and `ASC_ISSUER_ID` for an App Store Connect API key.
- **Notarization:** a notarytool keychain profile (`xcrun notarytool store-credentials <name>`), passed as `NOTARY_PROFILE`. Or `APPLE_ID` and `APPLE_APP_PASSWORD` in the environment.
- **Sparkle key:** the EdDSA private key in the login keychain under the account `diskforecast`. The script passes `--account diskforecast`, so another app's key is never used. The public key is `SUPublicEDKey` in `project.yml`. For CI, put the private key in `SPARKLE_KEY_FILE`.
- **Homebrew:** `Casks/diskforecast.rb` in [coreyhaines31/homebrew-tap](https://github.com/coreyhaines31/homebrew-tap).
- **GitHub CLI:** `gh` signed in with push access to this repo and the tap.
- **Node:** Node 20+ and npm, to pack the extension.

If a release went out without the extension, attach it by hand:

```sh
cd mcpb && npm ci && npm run pack
gh release upload v<version> dist/diskforecast.mcpb --repo coreyhaines31/diskforecast --clobber
```

## From CI

Pushing a tag like `v1.2.1` runs the same script in the [release workflow](.github/workflows/release.yml), once the repo variable `CI_RELEASES` is `true` and the `ASC_API_KEY`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `APPLE_ID`, `APPLE_APP_PASSWORD`, and `SPARKLE_PRIVATE_KEY` secrets exist.

## Updates

The app checks `https://github.com/coreyhaines31/diskforecast/releases/latest/download/appcast.xml` (`SUFeedURL` in `project.yml`). Each release's appcast points at that release's DMG.

## The website

The site in `site/` deploys to Vercel (project `diskforecast`) from `main`:

```sh
python3 site/_build/render.py   # regenerate pages after editing site/_build/*.py
cd site && vercel deploy --prod
```
