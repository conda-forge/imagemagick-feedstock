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
    export LIBS="${LIBS} -ladvapi32 -luser32 -lfftw3"

    # Ensure configure finds conda-forge host .pc files under Library/lib/pkgconfig.
    export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig"

    # On Windows with clang, UCRT's complex.h is incompatible with fftw3's _Complex usage.
    # Disable complex math functions to use fftw double[2] fallback macros in fourier.c
    export ac_cv_header_complex_h=no
    export ac_cv_func_cabs=no
    export ac_cv_func_carg=no
    export ac_cv_func_creal=no
    export ac_cv_func_cimag=no

    # MSVC/lld-link build should not link libstdc++.
    sed -i -E 's/(^| )-lstdc\+\+($| )/ /g' "${PREFIX}"/lib/pkgconfig/*.pc

    with_x=no
else
    # Ensure configure finds conda-forge host .pc files for pango, librsvg, and fontconfig delegates
    export PKG_CONFIG="${PREFIX}/bin/pkg-config"
    export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig:${PREFIX}/share/pkgconfig:${PKG_CONFIG_PATH}"

    with_x=yes
fi

${PKG_CONFIG} --exists pangocairo && echo "pangocairo found" || echo "pangocairo NOT found"
${PKG_CONFIG} --debug pangocairo 2>&1 | head -20
exit

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
            --with-gdi32=no \
            --with-gslib=${with_gslib} \
            --with-gvc=yes \
            --with-heic=yes \
            --with-jbig=yes \
            --with-jpeg=yes \
            --with-lcms=yes \
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

# When performing a parallel build on Windows, a conflict error occurs stating that magick.exe cannot be found
if [[ "${target_platform}" == "win-"* ]]; then
    make install
else
    make install -j${CPU_COUNT}
fi

if [[ "${target_platform}" == "win-"* ]]; then
    for f in "${PREFIX}/lib/"*.dll.lib; do
        base=$(basename "$f" .dll.lib)
        cp "$f" "${PREFIX}/lib/${base}.lib"
    done
fi
