/*
 * GenesisBridge.c – Thin C bridge between the Genesis Plus GX libretro core and Swift.
 *
 * The genesis static library has all retro_* symbols prefixed as genesis_retro_*.
 * We include genesis_prefix.h BEFORE libretro.h so that the standard API names
 * (#define retro_init genesis_retro_init, etc.) resolve to the actual symbols.
 */

#include "GenesisBridge.h"

/* Prefix header maps retro_* -> genesis_retro_* */
#include "genesis_prefix.h"
#include "libretro.h"

#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/* Genesis screen dimensions */
#define GENESIS_WIDTH  320
#define GENESIS_HEIGHT 240  /* PAL max; NTSC is 224 — use max to avoid overflow */

/* ---------- Context -------------------------------------------------------- */

struct GenesisContext {
    /* ARGB8888 framebuffer delivered to Swift (0xFFRRGGBB) */
    uint32_t argbBuffer[GENESIS_WIDTH * GENESIS_HEIGHT];

    unsigned screenWidth;
    unsigned screenHeight;

    GenesisVideoCallback videoCallback;
    GenesisAudioCallback audioCallback;
    void *userData;

    /* Bitmask of pressed buttons (bit index = libretro JOYPAD id) */
    uint32_t keys;

    uint32_t sampleRate;
    bool     romLoaded;
};

/* Singleton – the libretro API is global; only one core at a time. */
static GenesisContext *g_genesis_ctx = NULL;

/* ---------- Libretro callbacks --------------------------------------------- */

static bool genesis_env_callback(unsigned cmd, void *data) {
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

static void genesis_video_callback(const void *data, unsigned width, unsigned height, size_t pitch) {
    GenesisContext *ctx = g_genesis_ctx;
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

static void genesis_audio_callback(int16_t left, int16_t right) {
    GenesisContext *ctx = g_genesis_ctx;
    if (!ctx || !ctx->audioCallback) return;
    ctx->audioCallback(ctx->userData, left, right);
}

static void genesis_input_poll_callback(void) {
    /* Nothing to do — keys are set synchronously via genesis_set_keys */
}

static int16_t genesis_input_state_callback(unsigned port, unsigned device, unsigned index, unsigned id) {
    GenesisContext *ctx = g_genesis_ctx;
    if (!ctx || port != 0 || device != RETRO_DEVICE_JOYPAD) return 0;
    return (ctx->keys >> id) & 1;
}

/* ---------- Public API ----------------------------------------------------- */

GenesisContext *genesis_create(void) {
    GenesisContext *ctx = calloc(1, sizeof(GenesisContext));
    if (!ctx) return NULL;

    ctx->screenWidth  = GENESIS_WIDTH;
    ctx->screenHeight = GENESIS_HEIGHT;
    ctx->sampleRate   = 44100;

    g_genesis_ctx = ctx;

    /* Set callbacks BEFORE init, per libretro spec */
    retro_set_environment(genesis_env_callback);
    retro_set_video_refresh(genesis_video_callback);
    retro_set_audio_sample(genesis_audio_callback);
    retro_set_input_poll(genesis_input_poll_callback);
    retro_set_input_state(genesis_input_state_callback);

    retro_init();

    return ctx;
}

void genesis_destroy(GenesisContext *ctx) {
    if (!ctx) return;
    if (ctx->romLoaded) {
        retro_unload_game();
    }
    retro_deinit();
    if (g_genesis_ctx == ctx) g_genesis_ctx = NULL;
    free(ctx);
}

void genesis_set_user_data(GenesisContext *ctx, void *userData) {
    if (ctx) ctx->userData = userData;
}

void genesis_set_video_callback(GenesisContext *ctx, GenesisVideoCallback callback) {
    if (ctx) ctx->videoCallback = callback;
}

void genesis_set_audio_callback(GenesisContext *ctx, GenesisAudioCallback callback) {
    if (ctx) ctx->audioCallback = callback;
}

bool genesis_load_rom(GenesisContext *ctx, const char *path) {
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

void genesis_run_frame(GenesisContext *ctx) {
    if (!ctx || !ctx->romLoaded) return;
    retro_run();
}

void genesis_set_keys(GenesisContext *ctx, uint32_t keys) {
    if (ctx) ctx->keys = keys;
}

bool genesis_save_state(GenesisContext *ctx, const char *path) {
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

bool genesis_load_state(GenesisContext *ctx, const char *path) {
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

bool genesis_save_battery(GenesisContext *ctx, const char *path) {
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

bool genesis_load_battery(GenesisContext *ctx, const char *path) {
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

static unsigned gen_cheat_index = 0;

void genesis_add_cheat(GenesisContext *ctx, const char *code, const char *description) {
    if (!ctx || !ctx->romLoaded || !code) return;
    (void)description;
    retro_cheat_set(gen_cheat_index++, true, code);
}

void genesis_remove_all_cheats(GenesisContext *ctx) {
    if (!ctx || !ctx->romLoaded) return;
    retro_cheat_reset();
    gen_cheat_index = 0;
}

void genesis_set_sample_rate(GenesisContext *ctx, uint32_t sampleRate) {
    if (ctx) ctx->sampleRate = sampleRate;
    /* The libretro core's sample rate is fixed; resampling is done on the
       frontend side (AudioEngine). We just store it for reference. */
}

unsigned int genesis_get_screen_width(GenesisContext *ctx) {
    return ctx ? ctx->screenWidth : GENESIS_WIDTH;
}

unsigned int genesis_get_screen_height(GenesisContext *ctx) {
    return ctx ? ctx->screenHeight : GENESIS_HEIGHT;
}
