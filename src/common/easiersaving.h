// Easier Saving: shared option storage for the patched minarch/nextui and the
// pak's settings tool. Header-only so it can be dropped into NextUI's
// workspace/all/common/ without touching any makefiles.
//
// Options live in a plain key=value text file. A missing file, a missing key or
// an out of range value means 0 ("off"), so a patched binary with no settings
// file behaves exactly like stock NextUI.

#ifndef EASIERSAVING_H
#define EASIERSAVING_H

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sys/stat.h>
#include "defines.h"

#define ES_DIR SHARED_USERDATA_PATH "/.easiersaving"
#define ES_SETTINGS_PATH ES_DIR "/settings.txt"
// written by minarch when a sleep/power-off quicksave went to a regular slot,
// tells the next auto resume which slot to load instead of the hidden one
#define ES_RESUME_SLOT_PATH ES_DIR "/resume_slot.txt"

enum {
	ES_HIDE_SAVE_LOAD,   // remove Save and Load from the in-game menu
	ES_SAVE_AND_QUIT,    // Quit becomes Save & Quit
	ES_QUICKSAVE_TO_SLOT,// sleep/power-off quicksave goes to the current slot
	ES_ALWAYS_RESUME,    // A resumes in the game list, like X
	ES_MENU_RESET,       // add Reset to the in-game menu
	ES_LOW_BATTERY_SAVE, // save to the current slot when the battery runs low
	ES_SAVE_INTERVAL,    // index into ES_save_interval_secs, 0 is off
	ES_COUNT,
};

static const char* ES_keys[ES_COUNT] = {
	[ES_HIDE_SAVE_LOAD]    = "hide_save_load",
	[ES_SAVE_AND_QUIT]     = "save_and_quit",
	[ES_QUICKSAVE_TO_SLOT] = "quicksave_to_slot",
	[ES_ALWAYS_RESUME]     = "always_resume",
	[ES_MENU_RESET]        = "menu_reset",
	[ES_LOW_BATTERY_SAVE]  = "low_battery_save",
	[ES_SAVE_INTERVAL]     = "save_interval",
};

static const int ES_save_interval_secs[] = { 0, 10, 30, 60, 2*60, 5*60, 10*60, 30*60, 60*60 };
static const char* ES_save_interval_labels[] = {
	"Off", "10 seconds", "30 seconds", "1 minute", "2 minutes", "5 minutes", "10 minutes", "30 minutes", "1 hour",
};
#define ES_SAVE_INTERVAL_COUNT (int)(sizeof(ES_save_interval_secs) / sizeof(ES_save_interval_secs[0]))

// highest value each option takes, the rest are on/off
static inline int ES_max(int opt) {
	return opt==ES_SAVE_INTERVAL ? ES_SAVE_INTERVAL_COUNT - 1 : 1;
}

static int ES_values[ES_COUNT];
static int ES_loaded = 0;

static inline void ES_load(void) {
	ES_loaded = 1;
	memset(ES_values, 0, sizeof(ES_values));

	FILE* file = fopen(ES_SETTINGS_PATH, "r");
	if (!file) return;

	char line[256];
	while (fgets(line, sizeof(line), file)) {
		char* eq = strchr(line, '=');
		if (!eq) continue;
		*eq = '\0';
		for (int i=0; i<ES_COUNT; i++) {
			if (strcmp(line, ES_keys[i])) continue;
			int value = atoi(eq+1);
			ES_values[i] = value>=0 && value<=ES_max(i) ? value : 0;
		}
	}
	fclose(file);
}

static inline int ES_get(int opt) {
	if (!ES_loaded) ES_load();
	return (opt>=0 && opt<ES_COUNT) ? ES_values[opt] : 0;
}

static inline void ES_set(int opt, int value) {
	if (!ES_loaded) ES_load();
	if (opt>=0 && opt<ES_COUNT) ES_values[opt] = value>=0 && value<=ES_max(opt) ? value : 0;
}

static inline int ES_save(void) {
	mkdir(ES_DIR, 0755);
	FILE* file = fopen(ES_SETTINGS_PATH, "w");
	if (!file) return 0;
	for (int i=0; i<ES_COUNT; i++) {
		fprintf(file, "%s=%i\n", ES_keys[i], ES_get(i));
	}
	fclose(file);
	return 1;
}

#endif
