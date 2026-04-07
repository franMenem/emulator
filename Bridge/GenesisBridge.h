#ifndef GenesisBridge_h
#define GenesisBridge_h

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

typedef struct GenesisContext GenesisContext;

typedef void (*GenesisVideoCallback)(void *userData, const uint32_t *pixels);
typedef void (*GenesisAudioCallback)(void *userData, int16_t left, int16_t right);

GenesisContext *genesis_create(void);
void genesis_destroy(GenesisContext *ctx);

void genesis_set_user_data(GenesisContext *ctx, void *userData);
void genesis_set_video_callback(GenesisContext *ctx, GenesisVideoCallback callback);
void genesis_set_audio_callback(GenesisContext *ctx, GenesisAudioCallback callback);

bool genesis_load_rom(GenesisContext *ctx, const char *path);

void genesis_run_frame(GenesisContext *ctx);

void genesis_set_keys(GenesisContext *ctx, uint32_t keys);

bool genesis_save_battery(GenesisContext *ctx, const char *path);
bool genesis_load_battery(GenesisContext *ctx, const char *path);

bool genesis_save_state(GenesisContext *ctx, const char *path);
bool genesis_load_state(GenesisContext *ctx, const char *path);

void genesis_add_cheat(GenesisContext *ctx, const char *code, const char *description);
void genesis_remove_all_cheats(GenesisContext *ctx);

void genesis_set_sample_rate(GenesisContext *ctx, uint32_t sampleRate);

unsigned int genesis_get_screen_width(GenesisContext *ctx);
unsigned int genesis_get_screen_height(GenesisContext *ctx);

#endif
