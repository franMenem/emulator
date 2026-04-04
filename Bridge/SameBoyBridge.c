#include "SameBoyBridge.h"
#include "gb.h"
#include <stdlib.h>
#include <string.h>

struct SBContext {
    GB_gameboy_t *gb;
    uint32_t pixelBuffer[256 * 224]; // max size (SGB), GB/GBC uses 160x144
    SBVideoCallback videoCallback;
    SBAudioCallback audioCallback;
    void *userData;
};

// --- Callbacks routed to Swift ---

static uint32_t rgb_encode(GB_gameboy_t *gb, uint8_t r, uint8_t g, uint8_t b) {
    return (0xFFu << 24) | ((uint32_t)r << 16) | ((uint32_t)g << 8) | b; // ARGB
}

static void vblank_callback(GB_gameboy_t *gb, GB_vblank_type_t type) {
    (void)type;
    SBContext *ctx = (SBContext *)GB_get_user_data(gb);
    if (ctx->videoCallback) {
        ctx->videoCallback(ctx->userData, ctx->pixelBuffer);
    }
}

static void audio_callback(GB_gameboy_t *gb, GB_sample_t *sample) {
    SBContext *ctx = (SBContext *)GB_get_user_data(gb);
    if (ctx->audioCallback) {
        ctx->audioCallback(ctx->userData, sample->left, sample->right);
    }
}

// --- Public API ---

SBContext *sb_create(bool isColorGB) {
    SBContext *ctx = calloc(1, sizeof(SBContext));
    ctx->gb = GB_alloc();
    GB_init(ctx->gb, isColorGB ? GB_MODEL_CGB_E : GB_MODEL_DMG_B);
    GB_set_user_data(ctx->gb, ctx);
    GB_set_pixels_output(ctx->gb, ctx->pixelBuffer);
    GB_set_rgb_encode_callback(ctx->gb, rgb_encode);
    GB_set_vblank_callback(ctx->gb, vblank_callback);
    return ctx;
}

void sb_destroy(SBContext *ctx) {
    if (!ctx) return;
    // GB_dealloc internally calls GB_free then frees the allocation
    GB_dealloc(ctx->gb);
    free(ctx);
}

void sb_set_user_data(SBContext *ctx, void *userData) {
    ctx->userData = userData;
}

void sb_set_video_callback(SBContext *ctx, SBVideoCallback callback) {
    ctx->videoCallback = callback;
}

void sb_set_audio_callback(SBContext *ctx, SBAudioCallback callback) {
    ctx->audioCallback = callback;
    if (callback) {
        GB_apu_set_sample_callback(ctx->gb, audio_callback);
    }
}

bool sb_load_rom(SBContext *ctx, const char *path) {
    return GB_load_rom(ctx->gb, path) == 0;
}

bool sb_load_boot_rom(SBContext *ctx, const char *path) {
    return GB_load_boot_rom(ctx->gb, path) == 0;
}

uint64_t sb_run_frame(SBContext *ctx) {
    return GB_run_frame(ctx->gb);
}

void sb_set_key(SBContext *ctx, int key, bool pressed) {
    GB_set_key_state(ctx->gb, (GB_key_t)key, pressed);
}

bool sb_save_battery(SBContext *ctx, const char *path) {
    return GB_save_battery(ctx->gb, path) == 0;
}

bool sb_load_battery(SBContext *ctx, const char *path) {
    return GB_load_battery(ctx->gb, path) == 0;
}

size_t sb_save_state_size(SBContext *ctx) {
    return GB_get_save_state_size(ctx->gb);
}

bool sb_save_state(SBContext *ctx, const char *path) {
    return GB_save_state(ctx->gb, path) == 0;
}

bool sb_load_state(SBContext *ctx, const char *path) {
    return GB_load_state(ctx->gb, path) == 0;
}

void sb_set_rewind_length(SBContext *ctx, double seconds) {
    GB_set_rewind_length(ctx->gb, seconds);
}

bool sb_rewind_pop(SBContext *ctx) {
    return GB_rewind_pop(ctx->gb);
}

void sb_add_cheat(SBContext *ctx, const char *code, const char *description) {
    GB_import_cheat(ctx->gb, code, description, true);
}

void sb_remove_all_cheats(SBContext *ctx) {
    GB_remove_all_cheats(ctx->gb);
}

void sb_set_sample_rate(SBContext *ctx, unsigned int sampleRate) {
    GB_set_sample_rate(ctx->gb, sampleRate);
}

unsigned int sb_get_screen_width(SBContext *ctx) {
    return GB_get_screen_width(ctx->gb);
}

unsigned int sb_get_screen_height(SBContext *ctx) {
    return GB_get_screen_height(ctx->gb);
}
