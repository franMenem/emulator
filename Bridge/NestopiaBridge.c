/*
 * NestopiaBridge.c – Thin C bridge between the nestopia libretro core and Swift.
 *
 * The nestopia static library has all retro_* symbols prefixed as nes_retro_*.
 * We include nes_prefix.h BEFORE libretro.h so that the standard API names
 * (#define retro_init nes_retro_init, etc.) resolve to the actual symbols.
 */

#include "NestopiaBridge.h"

/* Prefix header maps retro_* -> nes_retro_* */
#include "nes_prefix.h"
#include "libretro.h"

#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/* NES screen dimensions */
#define NES_WIDTH  256
#define NES_HEIGHT 240

/* ---------- Context -------------------------------------------------------- */

struct NestopiaContext {
    /* ARGB8888 framebuffer delivered to Swift (0xFFRRGGBB) */
    uint32_t argbBuffer[NES_WIDTH * NES_HEIGHT];

    unsigned screenWidth;
    unsigned screenHeight;

    NestopiaVideoCallback videoCallback;
    NestopiaAudioCallback audioCallback;
    void *userData;

    /* Bitmask of pressed buttons (bit index = libretro JOYPAD id) */
    uint32_t keys;

    uint32_t sampleRate;
    bool     romLoaded;
};

/* Singleton – the libretro API is global; only one core at a time. */
static NestopiaContext *g_nes_ctx = NULL;

/* ---------- Libretro callbacks --------------------------------------------- */

static bool nes_env_callback(unsigned cmd, void *data) {
    switch (cmd) {
        case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT: {
            enum retro_pixel_format *fmt = (enum retro_pixel_format *)data;
            /* We only support XRGB8888 */
            return (*fmt == RETRO_PIXEL_FORMAT_XRGB8888);
        }
        case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY: {
            const char **dir = (const char **)data;
            *dir = NULL;
            return true;
        }
        case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY: {
            const char **dir = (const char **)data;
            *dir = NULL;
            return true;
        }
        case RETRO_ENVIRONMENT_GET_LOG_INTERFACE:
            return false;
        case RETRO_ENVIRONMENT_GET_VARIABLE:
            return false;
        case RETRO_ENVIRONMENT_SET_VARIABLES:
            return true;
        case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE: {
            bool *updated = (bool *)data;
            if (updated) *updated = false;
            return true;
        }
        default:
            return false;
    }
}

static void nes_video_callback(const void *data, unsigned width, unsigned height, size_t pitch) {
    NestopiaContext *ctx = g_nes_ctx;
    if (!ctx || !data) return;

    ctx->screenWidth  = width;
    ctx->screenHeight = height;

    if (ctx->videoCallback) {
        /* Convert XRGB8888 (0x00RRGGBB) -> ARGB (0xFFRRGGBB) */
        const uint8_t *src = (const uint8_t *)data;
        for (unsigned y = 0; y < height; y++) {
            const uint32_t *srcRow = (const uint32_t *)(src + y * pitch);
            uint32_t *dstRow = ctx->argbBuffer + y * width;
            for (unsigned x = 0; x < width; x++) {
                dstRow[x] = srcRow[x] | 0xFF000000u;
            }
        }
        ctx->videoCallback(ctx->userData, ctx->argbBuffer);
    }
}

static void nes_audio_callback(int16_t left, int16_t right) {
    NestopiaContext *ctx = g_nes_ctx;
    if (!ctx || !ctx->audioCallback) return;
    ctx->audioCallback(ctx->userData, left, right);
}

static void nes_input_poll_callback(void) {
    /* Nothing to do — keys are set synchronously via nestopia_set_keys */
}

static int16_t nes_input_state_callback(unsigned port, unsigned device, unsigned index, unsigned id) {
    NestopiaContext *ctx = g_nes_ctx;
    if (!ctx || port != 0 || device != RETRO_DEVICE_JOYPAD) return 0;
    return (ctx->keys >> id) & 1;
}

/* ---------- Public API ----------------------------------------------------- */

NestopiaContext *nestopia_create(void) {
    NestopiaContext *ctx = calloc(1, sizeof(NestopiaContext));
    if (!ctx) return NULL;

    ctx->screenWidth  = NES_WIDTH;
    ctx->screenHeight = NES_HEIGHT;
    ctx->sampleRate   = 48000;

    g_nes_ctx = ctx;

    /* Set callbacks BEFORE init, per libretro spec */
    retro_set_environment(nes_env_callback);
    retro_set_video_refresh(nes_video_callback);
    retro_set_audio_sample(nes_audio_callback);
    retro_set_input_poll(nes_input_poll_callback);
    retro_set_input_state(nes_input_state_callback);

    retro_init();

    return ctx;
}

void nestopia_destroy(NestopiaContext *ctx) {
    if (!ctx) return;
    if (ctx->romLoaded) {
        retro_unload_game();
    }
    retro_deinit();
    if (g_nes_ctx == ctx) g_nes_ctx = NULL;
    free(ctx);
}

void nestopia_set_user_data(NestopiaContext *ctx, void *userData) {
    if (ctx) ctx->userData = userData;
}

void nestopia_set_video_callback(NestopiaContext *ctx, NestopiaVideoCallback callback) {
    if (ctx) ctx->videoCallback = callback;
}

void nestopia_set_audio_callback(NestopiaContext *ctx, NestopiaAudioCallback callback) {
    if (ctx) ctx->audioCallback = callback;
}

bool nestopia_load_rom(NestopiaContext *ctx, const char *path) {
    if (!ctx || !path) return false;

    /* If a ROM was previously loaded, unload it first */
    if (ctx->romLoaded) {
        retro_unload_game();
        ctx->romLoaded = false;
    }

    /* Read ROM file into memory */
    FILE *f = fopen(path, "rb");
    if (!f) return false;

    fseek(f, 0, SEEK_END);
    long fileSize = ftell(f);
    fseek(f, 0, SEEK_SET);

    if (fileSize <= 0) {
        fclose(f);
        return false;
    }

    void *romData = malloc((size_t)fileSize);
    if (!romData) {
        fclose(f);
        return false;
    }

    size_t bytesRead = fread(romData, 1, (size_t)fileSize, f);
    fclose(f);

    if ((long)bytesRead != fileSize) {
        free(romData);
        return false;
    }

    struct retro_game_info game_info;
    memset(&game_info, 0, sizeof(game_info));
    game_info.path = path;
    game_info.data = romData;
    game_info.size = (size_t)fileSize;

    bool ok = retro_load_game(&game_info);
    free(romData);

    if (ok) {
        ctx->romLoaded = true;

        /* Query actual screen dimensions from AV info */
        struct retro_system_av_info av_info;
        retro_get_system_av_info(&av_info);
        ctx->screenWidth  = av_info.geometry.base_width;
        ctx->screenHeight = av_info.geometry.base_height;
    }

    return ok;
}

void nestopia_run_frame(NestopiaContext *ctx) {
    if (!ctx || !ctx->romLoaded) return;
    retro_run();
}

void nestopia_set_keys(NestopiaContext *ctx, uint32_t keys) {
    if (ctx) ctx->keys = keys;
}

bool nestopia_save_state(NestopiaContext *ctx, const char *path) {
    if (!ctx || !ctx->romLoaded || !path) return false;

    size_t size = retro_serialize_size();
    if (size == 0) return false;

    void *data = malloc(size);
    if (!data) return false;

    if (!retro_serialize(data, size)) {
        free(data);
        return false;
    }

    FILE *f = fopen(path, "wb");
    if (!f) {
        free(data);
        return false;
    }

    size_t written = fwrite(data, 1, size, f);
    fclose(f);
    free(data);

    return written == size;
}

bool nestopia_load_state(NestopiaContext *ctx, const char *path) {
    if (!ctx || !ctx->romLoaded || !path) return false;

    FILE *f = fopen(path, "rb");
    if (!f) return false;

    fseek(f, 0, SEEK_END);
    long fileSize = ftell(f);
    fseek(f, 0, SEEK_SET);

    if (fileSize <= 0) {
        fclose(f);
        return false;
    }

    void *data = malloc((size_t)fileSize);
    if (!data) {
        fclose(f);
        return false;
    }

    size_t bytesRead = fread(data, 1, (size_t)fileSize, f);
    fclose(f);

    if ((long)bytesRead != fileSize) {
        free(data);
        return false;
    }

    bool ok = retro_unserialize(data, (size_t)fileSize);
    free(data);
    return ok;
}

bool nestopia_save_battery(NestopiaContext *ctx, const char *path) {
    if (!ctx || !ctx->romLoaded || !path) return false;

    size_t size = retro_get_memory_size(RETRO_MEMORY_SAVE_RAM);
    void *data  = retro_get_memory_data(RETRO_MEMORY_SAVE_RAM);
    if (!data || size == 0) return false;

    FILE *f = fopen(path, "wb");
    if (!f) return false;

    size_t written = fwrite(data, 1, size, f);
    fclose(f);

    return written == size;
}

bool nestopia_load_battery(NestopiaContext *ctx, const char *path) {
    if (!ctx || !ctx->romLoaded || !path) return false;

    size_t size = retro_get_memory_size(RETRO_MEMORY_SAVE_RAM);
    void *data  = retro_get_memory_data(RETRO_MEMORY_SAVE_RAM);
    if (!data || size == 0) return false;

    FILE *f = fopen(path, "rb");
    if (!f) return false;

    size_t bytesRead = fread(data, 1, size, f);
    fclose(f);

    return bytesRead == size;
}

static unsigned nes_cheat_index = 0;

void nestopia_add_cheat(NestopiaContext *ctx, const char *code, const char *description) {
    if (!ctx || !ctx->romLoaded || !code) return;
    (void)description;
    retro_cheat_set(nes_cheat_index++, true, code);
}

void nestopia_remove_all_cheats(NestopiaContext *ctx) {
    if (!ctx || !ctx->romLoaded) return;
    retro_cheat_reset();
    nes_cheat_index = 0;
}

void nestopia_set_sample_rate(NestopiaContext *ctx, uint32_t sampleRate) {
    if (ctx) ctx->sampleRate = sampleRate;
    /* The libretro core's sample rate is fixed; resampling is done on the
       frontend side (AudioEngine). We just store it for reference. */
}

unsigned int nestopia_get_screen_width(NestopiaContext *ctx) {
    return ctx ? ctx->screenWidth : NES_WIDTH;
}

unsigned int nestopia_get_screen_height(NestopiaContext *ctx) {
    return ctx ? ctx->screenHeight : NES_HEIGHT;
}
