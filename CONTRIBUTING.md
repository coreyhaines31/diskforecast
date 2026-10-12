# Contributing

Bug reports, ideas, and pull requests are welcome. Open an issue first for anything bigger than a small fix, so we can agree on the approach before you spend time on it.

## Reporting a bug

[Open an issue](https://github.com/coreyhaines31/diskforecast/issues/new/choose) and include:

- Your Disk Forecast version (Settings › General) and macOS version.
- Whether Full Disk Access is on (Settings › Scanning).
- What you did, what you expected, and what happened. A screenshot of the menu or window helps.

For a wrong size or a folder that's missing from Cleanup, say which folder and what Finder reports for it.

## Setting up

Follow [Building from source](README.md#building-from-source) in the README. In short:

```sh
brew install xcodegen swiftlint
xcodegen generate
xcodebuild -project DiskForecast.xcodeproj -scheme DiskForecast \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO test
```

`DiskForecast.xcodeproj` is generated from `project.yml` and isn't checked in. Add new files on disk and run `xcodegen generate` again.

Most logic lives in `Packages/DiskForecastCore`, which you can test on its own:

```sh
cd Packages/DiskForecastCore && swift test
```

## Ground rules

These keep Disk Forecast something people can trust with their disk:

- **Files only go to the Trash.** Never delete anything outright. All cleanup goes through `Trasher`, which refuses anything outside the home folder.
- **System Data fixes use the tool's own command** (`tmutil`, `xcrun simctl`, `docker`), show that command, and ask before running it.
- **No telemetry.** The only network request is Sparkle's update check.
- **Plain language.** Explain what something is and whether it's safe to clear. Don't promise speed: say "reclaim" and "explain", never "optimize", "boost", or "speed up".

## Before you open a pull request

- Run the tests and `swiftlint --strict`. Both run in CI on every pull request.
- Keep each pull request to one change, in small commits.
- Add or update tests in `Packages/DiskForecastCore` for logic changes.
- For a change you can see, add a before-and-after screenshot of the menu or window.

## Contributor terms

Disk Forecast is licensed under FSL-1.1-MIT, and some future features may be sold under a commercial license. To keep that possible, every contribution comes with these terms. By opening a pull request, you agree that:

1. You wrote the contribution, or otherwise have the right to submit it.
2. You grant Corey Haines a perpetual, worldwide, non-exclusive, royalty-free, irrevocable license to use, modify, and distribute your contribution, and to sublicense and relicense it under any terms, including commercial ones.
3. You keep the copyright in your contribution, and you can use it however you like.

If you can't agree to these terms, please open an issue describing the change instead.
