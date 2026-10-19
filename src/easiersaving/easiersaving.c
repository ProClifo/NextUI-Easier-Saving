// Easier Saving settings: a single list of on/off options, styled after
// minarch's Options > Frontend menu.
//
// usage: easiersaving.elf [notice]
//   notice: optional text shown at the top instead of the title (eg. a
//           version mismatch warning from launch.sh)
//
// Writes ES_SETTINGS_PATH, and creates/removes ES_ENABLED_PATH for the
// master switch. launch.sh applies the master switch after this exits.

#include <stdio.h>
#include <unistd.h>
#include <msettings.h>

#include "defines.h"
#include "api.h"
#include "utils.h"
#include "easiersaving.h"

#define ES_ENABLED_PATH ES_DIR "/enabled"

#define OPTION_PADDING 8

enum {
	ROW_ENABLED,
	ROW_HIDE_SAVE_LOAD,
	ROW_SAVE_AND_QUIT,
	ROW_QUICKSAVE_TO_SLOT,
	ROW_A_RESUMES,
	ROW_MENU_RESET,
	ROW_COUNT,
};

typedef struct {
	char* name;
	char* desc;
	int opt; // ES_* option, or -1 for the master switch
} Row;

static Row rows[ROW_COUNT] = {
	[ROW_ENABLED]           = {"Easier Saving",       "Use the patched NextUI binaries in this pak.\nTurn off to go back to stock behavior.", -1},
	[ROW_HIDE_SAVE_LOAD]    = {"Hide Save & Load",    "Remove Save and Load from the in-game menu.", ES_HIDE_SAVE_LOAD},
	[ROW_SAVE_AND_QUIT]     = {"Save & Quit",         "Quit becomes Save & Quit, saving to\nthe current save state slot first.", ES_SAVE_AND_QUIT},
	[ROW_QUICKSAVE_TO_SLOT] = {"Quicksave to Slot",   "The sleep/power off quicksave goes to the\ncurrent save state slot, not a hidden one.", ES_QUICKSAVE_TO_SLOT},
	[ROW_A_RESUMES]         = {"A Resumes",           "A resumes games that have a save state.\nX starts them fresh instead.", ES_A_RESUMES},
	[ROW_MENU_RESET]        = {"Reset in Menu",       "Add Reset to the in-game menu.", ES_MENU_RESET},
};

static int enabled = 0;

static int Row_get(int i) {
	return rows[i].opt<0 ? enabled : ES_get(rows[i].opt);
}
static void Row_toggle(int i) {
	if (rows[i].opt<0) enabled = !enabled;
	else ES_set(rows[i].opt, !ES_get(rows[i].opt));
}

int main(int argc, char* argv[]) {
	char* notice = argc>1 && argv[1][0] ? argv[1] : NULL;

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

	while (!quit) {
		GFX_startFrame();
		PAD_poll();

		if (PAD_justRepeated(BTN_UP)) {
			selected -= 1;
			if (selected<0) selected += ROW_COUNT;
			dirty = 1;
		}
		else if (PAD_justRepeated(BTN_DOWN)) {
			selected += 1;
			if (selected>=ROW_COUNT) selected -= ROW_COUNT;
			dirty = 1;
		}
		else if (PAD_justRepeated(BTN_LEFT) || PAD_justRepeated(BTN_RIGHT) || PAD_justPressed(BTN_A)) {
			Row_toggle(selected);
			dirty = 1;
		}
		else if (PAD_justPressed(BTN_B)) {
			quit = 1;
		}

		PWR_update(&dirty, &show_setting, NULL, NULL);

		if (dirty) {
			GFX_clear(screen);

			int ow = GFX_blitHardwareGroup(screen, show_setting);

			// title (or notice) pill
			char* title = notice ? notice : "Easier Saving";
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

			if (show_setting && !GetHDMI()) GFX_blitHardwareHints(screen, show_setting);
			else GFX_blitButtonGroup((char*[]){ "A","TOGGLE", NULL }, 0, screen, 0);
			GFX_blitButtonGroup((char*[]){ "B","SAVE", NULL }, 1, screen, 1);

			// rows
			int mw = screen->w - SCALE1(PADDING * 2);
			int ox = SCALE1(PADDING);
			int oy = SCALE1(PADDING + PILL_SIZE + PADDING);
			char* desc = NULL;
			for (int i=0; i<ROW_COUNT; i++) {
				SDL_Color text_color = COLOR_WHITE;
				int y = oy + SCALE1(i*BUTTON_SIZE);
				// options only matter while the patched binaries are in use
				int muted = i!=ROW_ENABLED && !enabled;

				if (i==selected) {
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

				text = TTF_RenderUTF8_Blended(font.tiny, Row_get(i) ? "On" : "Off", muted && i!=selected ? COLOR_GRAY : COLOR_WHITE);
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

	return EXIT_SUCCESS;
}
