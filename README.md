# Easier Saving

A NextUI tool pak that makes saving simpler. Each change can be turned on or off on its own:

| Option | What it does |
|---|---|
| **Hide Save & Load** | Removes Save and Load from the in-game menu. |
| **Save & Quit** | Quit becomes Save & Quit. It saves to the current save state slot, then quits. |
| **Quicksave to Slot** | The quicksave made when the device sleeps or powers off mid-game goes to the current save state slot, not NextUI's hidden quicksave slot. Auto-resume on the next boot loads that slot. |
| **Always Resume** | In the game list, A resumes a game that has a save state, the same as X. This includes games stored as `.cue`/`.m3u` folders. Games without a save state still start with A. |
| **Reset in Menu** | Adds Reset to the in-game menu. |

With all options on, the in-game menu is **Continue / Options / Reset / Save & Quit**. Each game then has one save that is always kept up to date, and every way of opening the game picks up where you left off. The only way to start over is **Reset** in the in-game menu.

### "Always save, always resume"

To get that behavior, turn on **Save & Quit**, **Quicksave to Slot** and **Always Resume** (plus **Hide Save & Load** and **Reset in Menu** for the simplified menu). With those on:

| Way out of a game | Saves to the current slot? |
|---|---|
| Save & Quit in the menu | Yes |
| Power off (hold power, or Options → Quicksave) | Yes |
| Sleep, including auto-sleep and sleep that turns into power-off | Yes |
| Game Switcher (MENU + SELECT, or its shortcut) | Yes (stock NextUI already does this) |
| Save & Quit shortcut | Yes (stock) |
| Plugging/unplugging HDMI (minarch restarts) | Yes |
| The game itself asks to exit (rare, eg. quitting a DOS game) | No. Resuming the moment it exited would just exit again, so the previous save is kept. |
| Battery dies or power is cut | No. Nothing can run at that point, so you resume from the last sleep or save. |

| Way into a game | Resumes? |
|---|---|
| A or X in the game list, collections, Recently Played | Yes |
| Game Switcher | Yes (stock) |
| Auto-resume after power-off | Yes, from the slot the quicksave went to |

Turning on only some of these options leaves gaps. For example, with Quicksave to Slot off, a power-off save goes to the hidden slot, and opening the game later from the list resumes the older regular save.

Two things can still put a game somewhere other than where you left off. A **Reset Game** or **Load State** shortcut you bound yourself in Options → Shortcuts (both are unbound by default). And **RetroAchievements Hardcore mode**, which blocks save states completely.

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
