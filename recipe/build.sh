#!/bin/bash
set -exo pipefail

# Get an updated config.sub and config.guess
if [[ "${target_platform}" != "win-"* ]]; then
    cp $BUILD_PREFIX/share/gnuconfig/config.* ./config
fi

if [ "${license_family}" = "agpl" ]; then
    with_gslib=yes
else
    with_gslib=no
fi

# X11 support is not available on Windows
if [[ "${target_platform}" == "win-"* ]]; then
    # `_WIN32_WINNT` is not defined in autotools_clang_conda environment,
    # causing `MAGICKCORE_POSIX_SUPPORT` to be set instead of `MAGICKCORE_WINDOWS_SUPPORT`.
    # This leads to `dirent.h/sys/wait.h` being included, which don't exist on Windows.
    export CPPFLAGS="${CPPFLAGS} -D_WIN32_WINNT=0x0601"
    
    # ssize_t is not defined in the Windows SDK; use ptrdiff_t as substitute
    export CPPFLAGS="${CPPFLAGS} -Dssize_t=ptrdiff_t"

    # Windows system libraries required by MagickCore/nt-*.c
    export LIBS="${LIBS} -ladvapi32 -luser32"

    # Ensure configure finds conda-forge host .pc files under Library/lib/pkgconfig.
    export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig"
    echo "PKG_CONFIG_PATH=${PKG_CONFIG_PATH}"
    ls -la "${PREFIX}/lib/pkgconfig" || true

    with_x=no
    with_gdi32=no
else
    with_x=yes
    with_gdi32=yes
fi

./configure --prefix=$PREFIX \
            --enable-hdri=yes \
            --with-quantum-depth=16 \
            --disable-docs \
            --disable-static \
            --disable-openmp \
            --with-bzlib=yes \
            --with-autotrace=no \
            --with-djvu=no \
            --with-dps=no \
            --with-fftw=yes \
            --with-flif=no \
            --with-fpx=no \
            --with-fontconfig=yes \
            --with-freetype=yes \
            --with-gdi32=${with_gdi32} \
            --with-gslib=$with_gslib \
            --with-gvc=yes \
            --with-heic=yes \
            --with-jbig=yes \
            --with-jpeg=yes \
            --with-lcms=no \
            --with-lqr=no \
            --with-ltdl=no \
            --with-lzma=yes \
            --with-magick-plus-plus=yes \
            --with-openexr=no \
            --with-openjp2=yes \
            --with-pango=yes \
            --with-perl=no \
            --with-png=yes \
            --with-raqm=no \
            --with-raw=no \
            --with-rsvg=yes \
            --with-tiff=yes \
            --with-webp=yes \
            --with-wmf=no \
            --with-x=${with_x} \
            --with-xml=yes \
            --with-zlib=yes \
            --with-glib=yes

if [[ "${target_platform}" == "win-"* ]]; then
    patch_libtool
fi

make -j${CPU_COUNT}
# FIXME:
# The failure below seems to be associated with the option --with-gslib,
# but I could not get to turn "yes." See the logs for more info.
#
# tests/wandtest.c main 5321 non-conforming drawing primitive definition `text' @ error/draw.c/DrawImage/3269`
# make check
make install

if [[ "${target_platform}" == "win-"* ]]; then
    for f in "${PREFIX}/lib/"*.dll.lib; do
        base=$(basename "$f" .dll.lib)
        cp "$f" "${PREFIX}/lib/${base}.lib"
    done
fi
