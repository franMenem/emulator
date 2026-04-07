#ifndef Snes9xBridge_h
#define Snes9xBridge_h

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

typedef struct Snes9xContext Snes9xContext;

typedef void (*Snes9xVideoCallback)(void *userData, const uint32_t *pixels);
typedef void (*Snes9xAudioCallback)(void *userData, int16_t left, int16_t right);

Snes9xContext *snes9x_create(void);
void snes9x_destroy(Snes9xContext *ctx);

void snes9x_set_user_data(Snes9xContext *ctx, void *userData);
void snes9x_set_video_callback(Snes9xContext *ctx, Snes9xVideoCallback callback);
void snes9x_set_audio_callback(Snes9xContext *ctx, Snes9xAudioCallback callback);

bool snes9x_load_rom(Snes9xContext *ctx, const char *path);

void snes9x_run_frame(Snes9xContext *ctx);

void snes9x_set_keys(Snes9xContext *ctx, uint32_t keys);

bool snes9x_save_battery(Snes9xContext *ctx, const char *path);
bool snes9x_load_battery(Snes9xContext *ctx, const char *path);

bool snes9x_save_state(Snes9xContext *ctx, const char *path);
bool snes9x_load_state(Snes9xContext *ctx, const char *path);

void snes9x_add_cheat(Snes9xContext *ctx, const char *code, const char *description);
void snes9x_remove_all_cheats(Snes9xContext *ctx);

void snes9x_set_sample_rate(Snes9xContext *ctx, uint32_t sampleRate);

unsigned int snes9x_get_screen_width(Snes9xContext *ctx);
unsigned int snes9x_get_screen_height(Snes9xContext *ctx);

#endif
