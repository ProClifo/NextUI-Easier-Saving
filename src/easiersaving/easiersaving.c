// Easier Saving settings: a single list of on/off options, styled after
// minarch's Options > Frontend menu.
//
// usage: easiersaving.elf [notice]
//   notice: optional text shown at the top instead of the title (eg. a
//           version mismatch warning from launch.sh)
//
// Writes ES_SETTINGS_PATH, and creates/removes ES_ENABLED_PATH for the
// master switch. launch.sh applies the master switch after this exits.
//
// Runs from the pak folder and checks for an update in the background with
// ./update.sh. When one is downloaded it exits with EXIT_INSTALL_UPDATE and
// launch.sh installs it.

#include <stdio.h>
#include <unistd.h>
#include <msettings.h>

#include "defines.h"
#include "api.h"
#include "utils.h"
#include "easiersaving.h"

#define ES_ENABLED_PATH ES_DIR "/enabled"
#define EXIT_INSTALL_UPDATE 3

#define OPTION_PADDING 8

enum {
	ROW_UPDATE, // only listed when an update can be installed
	ROW_ENABLED,
	ROW_HIDE_SAVE_LOAD,
	ROW_SAVE_AND_QUIT,
	ROW_QUICKSAVE_TO_SLOT,
	ROW_ALWAYS_RESUME,
	ROW_MENU_RESET,
	ROW_LOW_BATTERY_SAVE,
	ROW_COUNT,
};

typedef struct {
	char* name;
	char* desc;
	int opt; // ES_* option, or -1 for the master switch
} Row;

static Row rows[ROW_COUNT] = {
	[ROW_UPDATE]            = {"Update Available",    "Download and install the new version.\nYour settings are kept.", -1},
	[ROW_ENABLED]           = {"Easier Saving",       "Use the patched NextUI binaries in this pak.\nTurn off to go back to stock behavior.", -1},
	[ROW_HIDE_SAVE_LOAD]    = {"Hide Save & Load",    "Remove Save and Load from the in-game menu.", ES_HIDE_SAVE_LOAD},
	[ROW_SAVE_AND_QUIT]     = {"Save & Quit",         "Quit becomes Save & Quit, saving to\nthe current save state slot first.", ES_SAVE_AND_QUIT},
	[ROW_QUICKSAVE_TO_SLOT] = {"Quicksave to Slot",   "The sleep/power off quicksave goes to the\ncurrent save state slot, not a hidden one.", ES_QUICKSAVE_TO_SLOT},
	[ROW_ALWAYS_RESUME]     = {"Always Resume",       "A resumes games that have a save state,\nthe same as X. Use Reset to start over.", ES_ALWAYS_RESUME},
	[ROW_MENU_RESET]        = {"Reset in Menu",       "Add Reset to the in-game menu.", ES_MENU_RESET},
	[ROW_LOW_BATTERY_SAVE]  = {"Low Battery Save",    "Save to the current slot at 10% and 5% battery,\nthen every 2 minutes until charging.", ES_LOW_BATTERY_SAVE},
};

static int enabled = 0;

static int Row_get(int i) {
	return rows[i].opt<0 ? enabled : ES_get(rows[i].opt);
}
static void Row_toggle(int i) {
	if (rows[i].opt<0) enabled = !enabled;
	else ES_set(rows[i].opt, !ES_get(rows[i].opt));
}

///////////////////////////////
// updates, ./update.sh does the network work on a background thread

enum {
	UPDATE_CHECKING,
	UPDATE_NONE,         // up to date, offline, or the check failed
	UPDATE_AVAILABLE,
	UPDATE_INCOMPATIBLE, // newer release needs another NextUI version
	UPDATE_DOWNLOADING,
	UPDATE_READY,        // downloaded, launch.sh installs it after we exit
	UPDATE_FAILED,
};

static SDL_atomic_t update_state;
static char update_version[32];
static char update_error[128];

// runs ./update.sh <command> and returns its first line of output
static void Update_run(const char* command, char* out, int size) {
	char cmd[64];
	snprintf(cmd, sizeof(cmd), "sh ./update.sh %s 2>/dev/null", command);
	out[0] = '\0';
	FILE* pipe = popen(cmd, "r");
	if (!pipe) return;
	if (fgets(out, size, pipe)) out[strcspn(out, "\r\n")] = '\0';
	pclose(pipe);
}
static int Update_checkThread(void* unused) {
	char line[160];
	Update_run("check", line, sizeof(line));
	int state = UPDATE_NONE;
	if (!strncmp(line, "available ", 10)) state = UPDATE_AVAILABLE;
	else if (!strncmp(line, "incompatible ", 13)) state = UPDATE_INCOMPATIBLE;
	if (state!=UPDATE_NONE) snprintf(update_version, sizeof(update_version), "%s", strchr(line, ' ')+1);
	else if (line[0]) LOG_info("update check: %s\n", line);
	SDL_AtomicSet(&update_state, state);
	return 0;
}
static int Update_downloadThread(void* unused) {
	char line[160];
	Update_run("download", line, sizeof(line));
	if (!strcmp(line, "ready")) {
		SDL_AtomicSet(&update_state, UPDATE_READY);
	}
	else {
		snprintf(update_error, sizeof(update_error), "Update failed: %s", line[0] ? (strncmp(line, "error ", 6) ? line : line+6) : "unknown error");
		LOG_info("%s\n", update_error);
		SDL_AtomicSet(&update_state, UPDATE_FAILED);
	}
	return 0;
}

int main(int argc, char* argv[]) {
	char* notice = argc>1 && argv[1][0] ? argv[1] : NULL;

	char version[32] = "";
	getFile("./version.txt", version, sizeof(version));
	version[strcspn(version, "\r\n")] = '\0';
	char title_buf[128];

	PWR_setCPUSpeed(CPU_SPEED_MENU);

	SDL_Surface* screen = GFX_init(MODE_MENU);
	PAD_init();
	PWR_init();
	InitSettings();

	if (exists(ES_SETTINGS_PATH)) {
		ES_load();
		enabled = exists(ES_ENABLED_PATH);
	}
	else { // first run, start with everything on (nothing is applied until B)
		for (int i=0; i<ES_COUNT; i++) ES_set(i, 1);
		enabled = 1;
	}

	int quit = 0;
	int dirty = 1;
	int show_setting = 0;
	int selected = 0;
	int start = 0; // first visible row, the list scrolls on short screens
	int install_update = 0;

	SDL_AtomicSet(&update_state, UPDATE_CHECKING);
	SDL_DetachThread(SDL_CreateThread(Update_checkThread, "UpdateCheck", NULL));
	int last_update_state = UPDATE_CHECKING;

	// rows actually shown, selected indexes into this
	int visible[ROW_COUNT];
	int visible_count = 0;

	while (!quit) {
		GFX_startFrame();
		PAD_poll();

		int update = SDL_AtomicGet(&update_state);
		if (update!=last_update_state) {
			// keep the same row selected when the update row comes or goes,
			// unless the cursor is still on the first row, then point at the update
			int was_update_row = last_update_state==UPDATE_AVAILABLE;
			int is_update_row = update==UPDATE_AVAILABLE;
			if (is_update_row && !was_update_row && selected>0) selected += 1;
			else if (!is_update_row && was_update_row && selected>0) selected -= 1;
			last_update_state = update;
			dirty = 1;
		}
		if (update==UPDATE_READY) {
			install_update = 1;
			quit = 1;
		}

		visible_count = 0;
		for (int i=0; i<ROW_COUNT; i++) {
			if (i==ROW_UPDATE && update!=UPDATE_AVAILABLE) continue;
			visible[visible_count++] = i;
		}
		if (selected>=visible_count) selected = visible_count - 1;

		if (update==UPDATE_DOWNLOADING) {
			// nothing to do but wait
		}
		else if (PAD_justRepeated(BTN_UP)) {
			selected -= 1;
			if (selected<0) selected += visible_count;
			dirty = 1;
		}
		else if (PAD_justRepeated(BTN_DOWN)) {
			selected += 1;
			if (selected>=visible_count) selected -= visible_count;
			dirty = 1;
		}
		else if (visible[selected]==ROW_UPDATE && PAD_justPressed(BTN_A)) {
			SDL_AtomicSet(&update_state, UPDATE_DOWNLOADING);
			SDL_DetachThread(SDL_CreateThread(Update_downloadThread, "UpdateDownload", NULL));
		}
		else if (visible[selected]!=ROW_UPDATE && (PAD_justRepeated(BTN_LEFT) || PAD_justRepeated(BTN_RIGHT) || PAD_justPressed(BTN_A))) {
			Row_toggle(visible[selected]);
			dirty = 1;
		}
		else if (PAD_justPressed(BTN_B)) {
			quit = 1;
		}

		PWR_update(&dirty, &show_setting, NULL, NULL);

		if (dirty) {
			GFX_clear(screen);

			int ow = GFX_blitHardwareGroup(screen, show_setting);

			// title pill: a notice from launch.sh wins, then update progress
			char* title = title_buf;
			if (notice) title = notice;
			else if (update==UPDATE_CHECKING) title = "Checking for updates...";
			else if (update==UPDATE_DOWNLOADING) snprintf(title_buf, sizeof(title_buf), "Downloading %s...", update_version);
			else if (update==UPDATE_FAILED) title = update_error;
			else if (update==UPDATE_INCOMPATIBLE) snprintf(title_buf, sizeof(title_buf), "%s needs a newer NextUI", update_version);
			else if (version[0]) snprintf(title_buf, sizeof(title_buf), "Easier Saving %s", version);
			else title = "Easier Saving";
			int max_width = screen->w - SCALE1(PADDING * 2) - ow;
			char display_name[256];
			int text_width = GFX_truncateText(font.large, title, display_name, max_width, SCALE1(BUTTON_PADDING*2));
			max_width = MIN(max_width, text_width);
			SDL_Surface* text = TTF_RenderUTF8_Blended(font.large, display_name, uintToColour(THEME_COLOR6_255));
			GFX_blitPillLight(ASSET_WHITE_PILL, screen, &(SDL_Rect){
				SCALE1(PADDING),
				SCALE1(PADDING),
				max_width,
				SCALE1(PILL_SIZE)
			});
			SDL_BlitSurface(text, &(SDL_Rect){0, 0, max_width-SCALE1(BUTTON_PADDING*2), text->h}, screen, &(SDL_Rect){
				SCALE1(PADDING+BUTTON_PADDING),
				SCALE1(PADDING+4)
			});
			SDL_FreeSurface(text);

			int on_update_row = visible[selected]==ROW_UPDATE;
			if (show_setting && !GetHDMI()) GFX_blitHardwareHints(screen, show_setting);
			else if (update!=UPDATE_DOWNLOADING) GFX_blitButtonGroup((char*[]){ "A",on_update_row?"INSTALL":"TOGGLE", NULL }, 0, screen, 0);
			if (update!=UPDATE_DOWNLOADING) GFX_blitButtonGroup((char*[]){ "B","SAVE", NULL }, 1, screen, 1);

			// rows
			int mw = screen->w - SCALE1(PADDING * 2);
			int ox = SCALE1(PADDING);
			int oy = SCALE1(PADDING + PILL_SIZE + PADDING);
			char* desc = NULL;

			// leave room for a two line description above the hints
			int dw, dh;
			GFX_sizeText(font.tiny, "A\nA", SCALE1(12), &dw, &dh);
			int max_rows = (screen->h - SCALE1(PADDING + PILL_SIZE) - dh - oy) / SCALE1(BUTTON_SIZE);
			if (max_rows>visible_count) max_rows = visible_count;
			if (selected<start) start = selected;
			if (selected>=start+max_rows) start = selected - max_rows + 1;
			if (start+max_rows>visible_count) start = visible_count - max_rows;

			for (int j=start; j<start+max_rows; j++) {
				int i = visible[j];
				SDL_Color text_color = COLOR_WHITE;
				int y = oy + SCALE1((j-start)*BUTTON_SIZE);
				// options only matter while the patched binaries are in use
				int muted = i!=ROW_ENABLED && i!=ROW_UPDATE && !enabled;

				if (j==selected) {
					GFX_blitPillLight(ASSET_BUTTON, screen, &(SDL_Rect){ox, y, mw, SCALE1(BUTTON_SIZE)});

					int w = 0;
					TTF_SizeUTF8(font.small, rows[i].name, &w, NULL);
					w += SCALE1(OPTION_PADDING*2);
					GFX_blitPillDark(ASSET_BUTTON, screen, &(SDL_Rect){ox, y, w, SCALE1(BUTTON_SIZE)});
					text_color = uintToColour(THEME_COLOR5_255);
					desc = rows[i].desc;
				}
				else if (muted) text_color = COLOR_GRAY;

				text = TTF_RenderUTF8_Blended(font.small, rows[i].name, text_color);
				SDL_BlitSurface(text, NULL, screen, &(SDL_Rect){ox+SCALE1(OPTION_PADDING), y+SCALE1(1)});
				SDL_FreeSurface(text);

				char* value = i==ROW_UPDATE ? update_version : Row_get(i) ? "On" : "Off";
				text = TTF_RenderUTF8_Blended(font.tiny, value, muted && j!=selected ? COLOR_GRAY : COLOR_WHITE);
				SDL_BlitSurface(text, NULL, screen, &(SDL_Rect){ox + mw - text->w - SCALE1(OPTION_PADDING), y+SCALE1(3)});
				SDL_FreeSurface(text);
			}

			if (desc) {
				int w,h;
				GFX_sizeText(font.tiny, desc, SCALE1(12), &w,&h);
				GFX_blitText(font.tiny, desc, SCALE1(12), COLOR_WHITE, screen, &(SDL_Rect){
					(screen->w - w) / 2,
					screen->h - SCALE1(PADDING + PILL_SIZE) - h,
					w,h
				});
			}

			GFX_flip(screen);
			dirty = 0;
		}
		else GFX_sync();
	}

	ES_save();
	if (enabled) putFile(ES_ENABLED_PATH, "1");
	else unlink(ES_ENABLED_PATH);
	sync();

	QuitSettings();
	PWR_quit();
	PAD_quit();
	GFX_quit();

	return install_update ? EXIT_INSTALL_UPDATE : EXIT_SUCCESS;
}
