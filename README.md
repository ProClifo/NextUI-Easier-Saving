# Easier Saving

A tool pak for [NextUI](https://github.com/LoveRetro/NextUI) and [MinUI](https://github.com/shauninman/MinUI) that makes saving simpler. Each change can be turned on or off on its own:

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

1. Download the zip for your OS from the [releases](../../releases), or from the latest **Build** workflow run:

   | OS | Download | Devices |
   |---|---|---|
   | NextUI v6.15.0 | `Easier Saving (NextUI).zip` | `tg5040` (TrimUI Smart Pro / Brick), `tg5050`, `h700` (Anbernic) |
   | MinUI v20251127-1 | `Easier Saving (MinUI).zip` | `miyoomini`, `rg35xx`, `rg35xxplus`, `my355`, `tg5040`, `zero28`, `rgb30`, `m17`, `gkdpixel`, `my282`, `magicmini`, `trimuismart` (TrimUI Model S) |

2. Extract it to the root of your SD card. This adds `Tools/<platform>/Easier Saving.pak`.
3. On the device, open **Tools → Easier Saving**, set the options, then press **B** to save.

## Updates

Opening the pak checks GitHub for a newer release in the background ("Checking for updates..." in the title) when the device is on Wi-Fi. If there is one, an **Update Available** row shows up at the top of the list. Press **A** on it to download the update. The pak then installs it and restarts, keeping your settings.

- Downloads come from this repo's [releases](../../releases) over HTTPS, verified against a CA bundle shipped in the pak, and are checked against the SHA-256 in the release's `latest.txt`.
- An update built for a different NextUI/MinUI release than the one installed isn't offered; the title shows *vX.Y.Z needs a newer NextUI* (or MinUI) instead.
- Needs `curl` and Wi-Fi on the device. Most MinUI devices have neither, so there the check finds nothing and you update by copying the new zip over.
- Without a connection the check quietly finds nothing.
- Builds that don't come from a release (`dev-<commit>` in the title) always count as older than the latest release.

## How it works

Changing the in-game menu needs a modified `minarch.elf`, and changing the game list needs a modified launcher (`nextui.elf` or `minui.elf`). This pak includes both, built from the OS's own source with [`patches/nextui.patch`](patches/nextui.patch) or [`patches/minui.patch`](patches/minui.patch) applied.

- **Nothing in `.system` is overwritten.** The patched binaries are bind-mounted over the stock ones, and redone on every boot. On NextUI that's a boot hook (`.userdata/<platform>/.hooks/boot.d/easier-saving.sync.sh`). MinUI has no hooks, so the pak adds a clearly marked block to the top of `.userdata/<platform>/auto.sh`, keeping anything else you have in there.
- **Turning the pak off** (the *Easier Saving* row) unmounts the binaries and removes the hook or `auto.sh` block, so you get the stock binaries back right away. Deleting the pak folder also gets you stock NextUI after the next reboot.
- **Version-locked.** The binaries only work with the NextUI/MinUI release they were built from (see [`sources.txt`](sources.txt)). If you run a different release, or update NextUI before this pak is rebuilt, it falls back to the stock binaries and the settings screen shows *Needs NextUI &lt;release&gt;* (or MinUI). To skip this check at your own risk, create `.userdata/shared/.easiersaving/skip-version-check`.
- With an option off, the patched binaries behave exactly like stock for that feature.

Settings are stored in `.userdata/shared/.easiersaving/settings.txt`, and the log is in `.userdata/<platform>/logs/Easier Saving.txt`.

### MinUI differences

- **Low Battery Save** saves once the battery reaches its lowest reading, then every 2 minutes until charging. MinUI only reports the charge in rough steps, so there's no separate 10% and 5% save, and no on-screen notice, since MinUI has no notifications.
- There's no RetroAchievements in MinUI, so nothing is skipped for Hardcore mode.

## Building

```sh
./scripts/build.sh                      # every target in sources.txt
./scripts/build.sh nextui-h700          # just one
./scripts/build.sh minui-miyoomini
```

The build needs `git` and `docker` (or `podman`). For each target it clones the repository and tag listed in `sources.txt` and applies that OS's patch. NextUI targets compile inside the official `ghcr.io/loveretro/<platform>-toolchain` images. MinUI targets first build their toolchain image from [`shauninman/union-<platform>-toolchain`](https://github.com/shauninman/union-miyoomini-toolchain). The output is `dist/Easier Saving (NextUI).zip` and/or `dist/Easier Saving (MinUI).zip`. The GitHub Actions workflow runs the same script, with NextUI on arm64 runners and MinUI on x86_64.

Pushing a `v*` tag (eg. `v1.2.0`), or running the **Build** workflow by hand with a version in its *release* field, publishes a release, and that release is what installed paks update to. Besides the two zips it carries `easier-saving-<os>-<platform>.tar.gz` and `latest.txt`, which `update.sh` on the device reads. Set `PAK_VERSION` to give a local build a version.

### Updating to a new NextUI or MinUI release

1. Update the target's line in `sources.txt` (and the matrix in `.github/workflows/build.yml` if you add a target).
2. Check that the patch still applies: `git -C <checkout> apply --check patches/<os>.patch`. If it doesn't, apply it by hand to the new tag and regenerate it with `git diff -- workspace/all/minarch workspace/all/nextui > patches/nextui.patch` (or `workspace/all/minarch workspace/all/minui > patches/minui.patch`).
3. Tag a new release.

### Layout

```
sources.txt                    OS repo/tag each target is built against
patches/nextui.patch           NextUI changes: minarch (in-game menu, saving) and nextui (A resumes)
patches/minui.patch            the same for MinUI's minarch and minui
src/common/easiersaving.h      option storage shared by the patched binaries and the settings tool
src/easiersaving/              settings tool (easiersaving.elf); makefile for NextUI, makefile.minui for MinUI
pak/Easier Saving.pak/         launch.sh, apply.sh (mount/unmount, boot hook, version check), update.sh (self-update)
scripts/build.sh               build + package
```
