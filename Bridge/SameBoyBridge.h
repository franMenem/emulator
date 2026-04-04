#ifndef SameBoyBridge_h
#define SameBoyBridge_h

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

// Opaque handle
typedef struct SBContext SBContext;

// Callbacks from C to Swift
typedef void (*SBVideoCallback)(void *userData, const uint32_t *pixels);
typedef void (*SBAudioCallback)(void *userData, int16_t left, int16_t right);

// Lifecycle
SBContext *sb_create(bool isColorGB);
void sb_destroy(SBContext *ctx);

// User data (Swift object pointer)
void sb_set_user_data(SBContext *ctx, void *userData);
void sb_set_video_callback(SBContext *ctx, SBVideoCallback callback);
void sb_set_audio_callback(SBContext *ctx, SBAudioCallback callback);

// ROM
bool sb_load_rom(SBContext *ctx, const char *path);
bool sb_load_boot_rom(SBContext *ctx, const char *path);

// Emulation
uint64_t sb_run_frame(SBContext *ctx);

// Input
void sb_set_key(SBContext *ctx, int key, bool pressed);

// Save / Load battery (SRAM)
bool sb_save_battery(SBContext *ctx, const char *path);
bool sb_load_battery(SBContext *ctx, const char *path);

// Save states
size_t sb_save_state_size(SBContext *ctx);
bool sb_save_state(SBContext *ctx, const char *path);
bool sb_load_state(SBContext *ctx, const char *path);

// Rewind
void sb_set_rewind_length(SBContext *ctx, double seconds);
bool sb_rewind_pop(SBContext *ctx);

// Cheats
void sb_add_cheat(SBContext *ctx, const char *code, const char *description);
void sb_remove_all_cheats(SBContext *ctx);

// Audio
void sb_set_sample_rate(SBContext *ctx, unsigned int sampleRate);

// Screen dimensions
unsigned int sb_get_screen_width(SBContext *ctx);
unsigned int sb_get_screen_height(SBContext *ctx);

#endif
