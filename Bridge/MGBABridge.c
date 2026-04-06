#include "MGBABridge.h"

#include <mgba/core/core.h>
#include <mgba/core/blip_buf.h>
#include <mgba/core/cheats.h>
#include <mgba/core/serialize.h>
#include <mgba/core/interface.h>
#include <mgba/gba/core.h>
#include <mgba-util/vfs.h>

#include <stdlib.h>
#include <string.h>
#include <fcntl.h>

// GBA screen dimensions
#define GBA_WIDTH  240
#define GBA_HEIGHT 160

// Audio samples to read per batch from blip buffers
#define AUDIO_SAMPLES 1024

struct MGBAContext {
    struct mCore *core;

    // Video buffer in mGBA native format (XBGR8: 0x00BBGGRR)
    color_t videoBuffer[GBA_WIDTH * GBA_HEIGHT];

    // Converted ARGB buffer delivered to Swift (0xFFRRGGBB)
    uint32_t argbBuffer[GBA_WIDTH * GBA_HEIGHT];

    MGBAVideoCallback videoCallback;
    MGBAAudioCallback audioCallback;
    void *userData;

    uint32_t sampleRate;
};

// Convert XBGR8 (0x00BBGGRR) to ARGB (0xFFRRGGBB)
static void convert_xbgr_to_argb(const color_t *src, uint32_t *dst, size_t count) {
    for (size_t i = 0; i < count; i++) {
        uint32_t pixel = src[i];
        uint8_t r = pixel & 0xFF;
        uint8_t g = (pixel >> 8) & 0xFF;
        uint8_t b = (pixel >> 16) & 0xFF;
        dst[i] = 0xFF000000u | ((uint32_t)r << 16) | ((uint32_t)g << 8) | b;
    }
}

// Drain blip buffers and deliver audio samples via callback
static void drain_audio(MGBAContext *ctx) {
    if (!ctx->audioCallback) return;

    struct blip_t *left  = ctx->core->getAudioChannel(ctx->core, 0);
    struct blip_t *right = ctx->core->getAudioChannel(ctx->core, 1);
    if (!left || !right) return;

    int avail = blip_samples_avail(left);
    while (avail > 0) {
        int toRead = avail > AUDIO_SAMPLES ? AUDIO_SAMPLES : avail;
        int16_t lBuf[AUDIO_SAMPLES];
        int16_t rBuf[AUDIO_SAMPLES];

        int lCount = blip_read_samples(left,  lBuf, toRead, 0);
        int rCount = blip_read_samples(right, rBuf, toRead, 0);
        int count  = lCount < rCount ? lCount : rCount;

        for (int i = 0; i < count; i++) {
            ctx->audioCallback(ctx->userData, lBuf[i], rBuf[i]);
        }

        avail = blip_samples_avail(left);
    }
}

// --- Public API ---

MGBAContext *mgba_create(void) {
    MGBAContext *ctx = calloc(1, sizeof(MGBAContext));
    if (!ctx) return NULL;

    ctx->core = GBACoreCreate();
    if (!ctx->core) {
        free(ctx);
        return NULL;
    }

    ctx->core->init(ctx->core);

    // Set up video buffer
    ctx->core->setVideoBuffer(ctx->core, ctx->videoBuffer, GBA_WIDTH);

    // Default sample rate
    ctx->sampleRate = 32768;

    return ctx;
}

void mgba_destroy(MGBAContext *ctx) {
    if (!ctx) return;
    ctx->core->deinit(ctx->core);
    free(ctx);
}

void mgba_set_user_data(MGBAContext *ctx, void *userData) {
    ctx->userData = userData;
}

void mgba_set_video_callback(MGBAContext *ctx, MGBAVideoCallback callback) {
    ctx->videoCallback = callback;
}

void mgba_set_audio_callback(MGBAContext *ctx, MGBAAudioCallback callback) {
    ctx->audioCallback = callback;
}

bool mgba_load_rom(MGBAContext *ctx, const char *path) {
    if (!mCoreLoadFile(ctx->core, path)) return false;
    mCoreAutoloadSave(ctx->core);
    ctx->core->reset(ctx->core);
    return true;
}

void mgba_run_frame(MGBAContext *ctx) {
    ctx->core->runFrame(ctx->core);

    // Deliver video
    if (ctx->videoCallback) {
        convert_xbgr_to_argb(ctx->videoBuffer, ctx->argbBuffer, GBA_WIDTH * GBA_HEIGHT);
        ctx->videoCallback(ctx->userData, ctx->argbBuffer);
    }

    // Deliver audio
    drain_audio(ctx);
}

void mgba_set_keys(MGBAContext *ctx, uint32_t keys) {
    ctx->core->setKeys(ctx->core, keys);
}

bool mgba_save_battery(MGBAContext *ctx, const char *path) {
    // Clone SRAM from core and write to file
    void *sram = NULL;
    size_t size = ctx->core->savedataClone(ctx->core, &sram);
    if (!sram || size == 0) return false;

    struct VFile *vf = VFileOpen(path, O_WRONLY | O_CREAT | O_TRUNC);
    if (!vf) {
        free(sram);
        return false;
    }

    ssize_t written = vf->write(vf, sram, size);
    vf->close(vf);
    free(sram);

    return (size_t)written == size;
}

bool mgba_load_battery(MGBAContext *ctx, const char *path) {
    struct VFile *vf = VFileOpen(path, O_RDONLY);
    if (!vf) return false;

    // loadSave takes ownership of the VFile — do NOT close it
    return ctx->core->loadSave(ctx->core, vf);
}

bool mgba_save_state(MGBAContext *ctx, const char *path) {
    struct VFile *vf = VFileOpen(path, O_WRONLY | O_CREAT | O_TRUNC);
    if (!vf) return false;

    bool ok = mCoreSaveStateNamed(ctx->core, vf, SAVESTATE_ALL);
    vf->close(vf);
    return ok;
}

bool mgba_load_state(MGBAContext *ctx, const char *path) {
    struct VFile *vf = VFileOpen(path, O_RDONLY);
    if (!vf) return false;

    bool ok = mCoreLoadStateNamed(ctx->core, vf, SAVESTATE_ALL);
    vf->close(vf);
    return ok;
}

void mgba_add_cheat(MGBAContext *ctx, const char *code, const char *description) {
    struct mCheatDevice *device = ctx->core->cheatDevice(ctx->core);
    if (!device) return;

    struct mCheatSet *set = device->createSet(device, description);
    if (!set) return;

    // addLine returns true on success; type 0 = auto-detect
    set->addLine(set, code, 0);
    set->enabled = true;
    mCheatAddSet(device, set);
}

void mgba_remove_all_cheats(MGBAContext *ctx) {
    struct mCheatDevice *device = ctx->core->cheatDevice(ctx->core);
    if (!device) return;
    mCheatDeviceClear(device);
}

void mgba_set_sample_rate(MGBAContext *ctx, uint32_t sampleRate) {
    ctx->sampleRate = sampleRate;

    // Update blip buffer rates: GBA runs at ~16.78 MHz clock
    struct blip_t *left  = ctx->core->getAudioChannel(ctx->core, 0);
    struct blip_t *right = ctx->core->getAudioChannel(ctx->core, 1);
    if (left)  blip_set_rates(left,  ctx->core->frequency(ctx->core), sampleRate);
    if (right) blip_set_rates(right, ctx->core->frequency(ctx->core), sampleRate);
}

unsigned int mgba_get_screen_width(MGBAContext *ctx) {
    unsigned w = 0, h = 0;
    ctx->core->desiredVideoDimensions(ctx->core, &w, &h);
    return w;
}

unsigned int mgba_get_screen_height(MGBAContext *ctx) {
    unsigned w = 0, h = 0;
    ctx->core->desiredVideoDimensions(ctx->core, &w, &h);
    return h;
}
