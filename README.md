# Easier Saving

A NextUI tool pak that makes saving simpler. Each change can be turned on or off on its own:

| Option | What it does |
|---|---|
| **Hide Save & Load** | Removes Save and Load from the in-game menu. |
| **Save & Quit** | Quit becomes Save & Quit. It saves to the current save state slot, then quits. |
| **Quicksave to Slot** | The quicksave made when the device sleeps or powers off mid-game goes to the current save state slot, not NextUI's hidden quicksave slot. Auto-resume on the next boot loads that slot. |
| **A Resumes** | In the game list, A resumes a game that has a save state and X starts it fresh. The button hints change to match. Games without a save state still start with A. |
| **Reset in Menu** | Adds Reset to the in-game menu. |

With all options on, the in-game menu is **Continue / Options / Reset / Save & Quit**. Each game then has one save that is always kept up to date, and A picks up where you left off.

> "Current save state slot" means the slot shown in the Save/Load slot picker. It is slot 1 unless you pick another one. If Save & Load are hidden, it stays on whichever slot you used last.

## Install

1. Download `Easier Saving.zip` from the [releases](../../releases) (or from the latest **Build** workflow run).
2. Extract it to the root of your SD card. This adds `Tools/<platform>/Easier Saving.pak`.
3. On the device, open **Tools → Easier Saving**, set the options, then press **B** to save.

Supported platforms: `tg5040` (TrimUI Smart Pro / Brick), `tg5050`, `h700` (Anbernic).

## How it works

Changing NextUI's in-game menu needs a modified `minarch.elf`, and changing the game list needs a modified `nextui.elf`. This pak includes both, built from NextUI's own source with [`patches/easier-saving.patch`](patches/easier-saving.patch) applied.

- **Nothing in `.system` is overwritten.** The patched binaries are bind-mounted over the stock ones. A boot hook (`.userdata/<platform>/.hooks/boot.d/easier-saving.sync.sh`) redoes the mount on every boot.
- **Turning the pak off** (the *Easier Saving* row) unmounts the binaries and removes the hook, so you get stock NextUI right away. Deleting the pak folder also gets you stock NextUI after the next reboot.
- **Version-locked.** The binaries only work with the NextUI release they were built from (see [`nextui.version`](nextui.version)). If you update NextUI and this pak hasn't been rebuilt yet, it falls back to the stock binaries and the settings screen shows *Needs NextUI vX.Y.Z*. To skip this check at your own risk, create `.userdata/shared/.easiersaving/skip-version-check`.
- With an option off, the patched binaries behave exactly like stock for that feature.

Settings are stored in `.userdata/shared/.easiersaving/settings.txt`, and the log is in `.userdata/<platform>/logs/Easier Saving.txt`.

## Building

```sh
./scripts/build.sh               # all platforms
./scripts/build.sh tg5040        # just one
```

The build needs `git` and `docker` (or `podman`). It clones NextUI at the tag in `nextui.version`, applies the patch, and compiles inside the official `ghcr.io/loveretro/<platform>-toolchain` images. The output is `dist/Easier Saving.zip`. The GitHub Actions workflow runs the same script on arm64 runners. Pushing a `v*` tag publishes a release.

### Updating to a new NextUI release

1. Put the new tag in `nextui.version`.
2. Check that the patch still applies: `git -C <NextUI checkout> apply --check patches/easier-saving.patch`. If it doesn't, apply it by hand to the new tag and regenerate it with `git diff -- workspace/all/minarch workspace/all/nextui > patches/easier-saving.patch`.
3. Tag a new release.

### Layout

```
nextui.version                 NextUI tag the binaries are built against
patches/easier-saving.patch    changes to minarch (in-game menu, quicksave) and nextui (A resumes)
src/common/easiersaving.h      option storage shared by the patched binaries and the settings tool
src/easiersaving/              settings tool (easiersaving.elf)
pak/Easier Saving.pak/         launch.sh + apply.sh (mount/unmount, boot hook, version check)
scripts/build.sh               build + package
```
