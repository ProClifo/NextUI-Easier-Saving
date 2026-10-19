# Easier Saving

A NextUI tool pak that makes saving simpler. Each change can be turned on or off on its own:

| Option | What it does |
|---|---|
| **Hide Save & Load** | Removes Save and Load from the in-game menu. |
| **Save & Quit** | Quit becomes Save & Quit. It saves to the current save state slot, then quits. |
| **Quicksave to Slot** | The quicksave made when the device sleeps or powers off mid-game goes to the current save state slot, not NextUI's hidden quicksave slot. Auto-resume on the next boot loads that slot. |
| **Always Resume** | In the game list, A resumes a game that has a save state, the same as X. This includes games stored as `.cue`/`.m3u` folders. Games without a save state still start with A. |
| **Reset in In-Game Menu** | Adds Reset to the in-game menu. It asks "Are you sure you want to reset?" first, with **No** selected, so a stray press can't wipe your progress. |
| **Low Battery Save** | While you play on battery, saves to the current slot when the battery reaches 10% and again at 5%, then every 2 minutes until you plug in. A notice ("Low Battery - Saved to Slot N") shows each time. |
| **Save Interval** | While you play, saves to the current slot every 10 seconds, 30 seconds, 1, 2, 5, 10 or 30 minutes, or 1 hour. Off by default. Time in the in-game menu doesn't count, and these saves are silent. Short intervals can cause a brief stutter on systems with large save states. |

With all options on, the in-game menu is **Continue / Options / Reset / Save & Quit**. Each game then has one save that is always kept up to date, and every way of opening the game picks up where you left off. The only way to start over is **Reset** in the in-game menu.

### "Always save, always resume"

To get that behavior, turn on **Save & Quit**, **Quicksave to Slot**, **Always Resume** and **Low Battery Save** (plus **Hide Save & Load** and **Reset in In-Game Menu** for the simplified menu). With those on:

| Way out of a game | Saves to the current slot? |
|---|---|
| Save & Quit in the menu | Yes |
| Power off (hold power, or Options → Quicksave) | Yes |
| Sleep, including auto-sleep and sleep that turns into power-off | Yes |
| Game Switcher (MENU + SELECT, or its shortcut) | Yes (stock NextUI already does this) |
| Save & Quit shortcut | Yes (stock) |
| Plugging/unplugging HDMI (minarch restarts) | Yes |
| The game itself asks to exit (rare, eg. quitting a DOS game) | No. Resuming the moment it exited would just exit again, so the previous save is kept. |
| Battery dies | Covered by Low Battery Save. You lose at most the last 2 minutes of play below 5%. |
| Power is cut suddenly (battery pulled, crash) | No. Nothing can run at that point, so you resume from the last save. |

| Way into a game | Resumes? |
|---|---|
| A or X in the game list, collections, Recently Played | Yes |
| Game Switcher | Yes (stock) |
| Auto-resume after power-off | Yes, from the slot the quicksave went to |

Turning on only some of these options leaves gaps. For example, with Quicksave to Slot off, a power-off save goes to the hidden slot, and opening the game later from the list resumes the older regular save.

Two things can still put a game somewhere other than where you left off. A **Reset Game** or **Load State** shortcut you bound yourself in Options → Shortcuts (both are unbound by default). And **RetroAchievements Hardcore mode**, which blocks save states completely.

> "Current save state slot" means the slot shown in the Save/Load slot picker. It is slot 1 unless you pick another one. If Save & Load are hidden, it stays on whichever slot you used last.

## Install

1. Download `Easier Saving.zip` from the [releases](../../releases), or from the latest **Build** workflow run. It's built for [NextUI](https://github.com/LoveRetro/NextUI) v6.15.0 on every supported device: `tg5040` (TrimUI Smart Pro / Brick), `tg5050` and `h700` (Anbernic).

2. Extract it to the root of your SD card. This adds `Tools/<platform>/Easier Saving.pak`.
3. On the device, open **Tools → Easier Saving**, set the options, then press **B** to save.

## Updates

Opening the pak checks GitHub for a newer release in the background ("Checking for updates..." in the title) when the device is on Wi-Fi. If there is one, an **Update Available** row shows up at the top of the list. Press **A** on it to download the update. The pak then installs it and restarts, keeping your settings.

- Downloads come from this repo's [releases](../../releases) over HTTPS, verified against a CA bundle shipped in the pak, and are checked against the SHA-256 in the release's `latest.txt`.
- An update built for a different NextUI release than the one installed isn't offered; the title shows *vX.Y.Z needs a newer NextUI* instead.
- Without a connection the check quietly finds nothing.
- Builds that don't come from a release (`dev-<commit>` in the title) always count as older than the latest release.

## How it works

Changing NextUI's in-game menu needs a modified `minarch.elf`, and changing the game list needs a modified `nextui.elf`. This pak includes both, built from NextUI's own source with [`patches/easier-saving.patch`](patches/easier-saving.patch) applied.

- **Nothing in `.system` is overwritten.** The patched binaries are bind-mounted over the stock ones. A boot hook (`.userdata/<platform>/.hooks/boot.d/easier-saving.sync.sh`) redoes the mount on every boot.
- **Turning the pak off** (the *Easier Saving* row) unmounts the binaries and removes the hook, so you get stock NextUI right away. Deleting the pak folder also gets you stock NextUI after the next reboot.
- **Version-locked.** The binaries only work with the NextUI release they were built from (see [`sources.txt`](sources.txt)). If you run a different release, or update NextUI before this pak is rebuilt, it falls back to the stock binaries and the settings screen shows *Needs NextUI &lt;release&gt;*. To skip this check at your own risk, create `.userdata/shared/.easiersaving/skip-version-check`.
- With an option off, the patched binaries behave exactly like stock for that feature.

Settings are stored in `.userdata/shared/.easiersaving/settings.txt`, and the log is in `.userdata/<platform>/logs/Easier Saving.txt`.

## Building

```sh
./scripts/build.sh               # all platforms
./scripts/build.sh h700          # just one
```

The build needs `git` and `docker` (or `podman`). For each platform it clones the NextUI repository and tag listed in `sources.txt`, applies the patch, and compiles inside the official `ghcr.io/loveretro/<platform>-toolchain` images. The output is `dist/Easier Saving.zip`. The GitHub Actions workflow runs the same script on arm64 runners.

Pushing a `v*` tag (eg. `v1.2.0`) publishes a release, and that release is what installed paks update to. Besides `Easier Saving.zip` it carries `easier-saving-<platform>.tar.gz` and `latest.txt`, which `update.sh` on the device reads. Set `PAK_VERSION` to give a local build a version.

### Updating to a new NextUI release

1. Update the platform's line in `sources.txt` (and the matrix in `.github/workflows/build.yml` if you add a platform).
2. Check that the patch still applies: `git -C <NextUI checkout> apply --check patches/easier-saving.patch`. If it doesn't, apply it by hand to the new tag and regenerate it with `git diff -- workspace/all/minarch workspace/all/nextui > patches/easier-saving.patch`.
3. Tag a new release.

### Layout

```
sources.txt                    NextUI repo/tag each platform is built against
patches/easier-saving.patch    changes to minarch (in-game menu, quicksave) and nextui (A resumes)
src/common/easiersaving.h      option storage shared by the patched binaries and the settings tool
src/easiersaving/              settings tool (easiersaving.elf)
pak/Easier Saving.pak/         launch.sh, apply.sh (mount/unmount, boot hook, version check), update.sh (self-update)
scripts/build.sh               build + package
```
