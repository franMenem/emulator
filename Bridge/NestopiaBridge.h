#ifndef NestopiaBridge_h
#define NestopiaBridge_h

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

typedef struct NestopiaContext NestopiaContext;

typedef void (*NestopiaVideoCallback)(void *userData, const uint32_t *pixels);
typedef void (*NestopiaAudioCallback)(void *userData, int16_t left, int16_t right);

NestopiaContext *nestopia_create(void);
void nestopia_destroy(NestopiaContext *ctx);

void nestopia_set_user_data(NestopiaContext *ctx, void *userData);
void nestopia_set_video_callback(NestopiaContext *ctx, NestopiaVideoCallback callback);
void nestopia_set_audio_callback(NestopiaContext *ctx, NestopiaAudioCallback callback);

bool nestopia_load_rom(NestopiaContext *ctx, const char *path);

void nestopia_run_frame(NestopiaContext *ctx);

void nestopia_set_keys(NestopiaContext *ctx, uint32_t keys);

bool nestopia_save_battery(NestopiaContext *ctx, const char *path);
bool nestopia_load_battery(NestopiaContext *ctx, const char *path);

bool nestopia_save_state(NestopiaContext *ctx, const char *path);
bool nestopia_load_state(NestopiaContext *ctx, const char *path);

void nestopia_add_cheat(NestopiaContext *ctx, const char *code, const char *description);
void nestopia_remove_all_cheats(NestopiaContext *ctx);

void nestopia_set_sample_rate(NestopiaContext *ctx, uint32_t sampleRate);

unsigned int nestopia_get_screen_width(NestopiaContext *ctx);
unsigned int nestopia_get_screen_height(NestopiaContext *ctx);

#endif
