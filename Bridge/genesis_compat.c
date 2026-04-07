/*
 * genesis_compat.c – Compiles libretro-common sources needed by Genesis Plus GX.
 *
 * The static library (libgenesis.a) was built with STATIC_LINKING=1, which
 * omits the libretro-common file I/O and VFS implementations. We compile them
 * here so the linker can resolve those symbols.
 */

/* Provide VFS_FRONTEND so that file_stream.c uses standard C I/O */
#ifndef VFS_FRONTEND
#define VFS_FRONTEND
#endif

/* Required by file_stream.c / vfs_implementation.c */
#include "../GenesisCore/Genesis-Plus-GX/libretro/libretro-common/compat/compat_strcasestr.c"
#include "../GenesisCore/Genesis-Plus-GX/libretro/libretro-common/vfs/vfs_implementation.c"
#include "../GenesisCore/Genesis-Plus-GX/libretro/libretro-common/streams/file_stream.c"
#include "../GenesisCore/Genesis-Plus-GX/libretro/libretro-common/streams/file_stream_transforms.c"
#include "../GenesisCore/Genesis-Plus-GX/libretro/libretro-common/file/file_path.c"
