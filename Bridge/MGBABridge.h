#ifndef MGBABridge_h
#define MGBABridge_h

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

typedef struct MGBAContext MGBAContext;

typedef void (*MGBAVideoCallback)(void *userData, const uint32_t *pixels);
typedef void (*MGBAAudioCallback)(void *userData, int16_t left, int16_t right);

MGBAContext *mgba_create(void);
void mgba_destroy(MGBAContext *ctx);

void mgba_set_user_data(MGBAContext *ctx, void *userData);
void mgba_set_video_callback(MGBAContext *ctx, MGBAVideoCallback callback);
void mgba_set_audio_callback(MGBAContext *ctx, MGBAAudioCallback callback);

bool mgba_load_rom(MGBAContext *ctx, const char *path);

void mgba_run_frame(MGBAContext *ctx);

void mgba_set_keys(MGBAContext *ctx, uint32_t keys);

bool mgba_save_battery(MGBAContext *ctx, const char *path);
bool mgba_load_battery(MGBAContext *ctx, const char *path);

bool mgba_save_state(MGBAContext *ctx, const char *path);
bool mgba_load_state(MGBAContext *ctx, const char *path);

void mgba_add_cheat(MGBAContext *ctx, const char *code, const char *description);
void mgba_remove_all_cheats(MGBAContext *ctx);

void mgba_set_sample_rate(MGBAContext *ctx, uint32_t sampleRate);

unsigned int mgba_get_screen_width(MGBAContext *ctx);
unsigned int mgba_get_screen_height(MGBAContext *ctx);

#endif
