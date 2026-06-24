#!/bin/bash
set -exo pipefail

# Get an updated config.sub and config.guess
if [[ "${target_platform}" != "win-"* ]]; then
    cp ${BUILD_PREFIX}/share/gnuconfig/config.* ./config
fi

if [ "${license_family}" = "agpl" ]; then
    # NOTE: `--with-gslib` linking fails due to missing headers in ghostscript package
    # (ghostscript/iapi.h, ierrors.h not provided); falls back to external gs command
    # Ref: https://github.com/conda-forge/ghostscript-feedstock/issues/40
    with_gslib=yes
else
    with_gslib=no
fi

# X11 support is not available on Windows
if [[ "${target_platform}" == "win-"* ]]; then
    # Provide ssize_t during the Windows clang/autotools build phase.
    # This is needed to compile ImageMagick sources that use ssize_t on Windows.
    # We normalize the installed/public header to a typedef later for MSVC consumers.
    export CPPFLAGS="${CPPFLAGS} -Dssize_t=ptrdiff_t"

    # `_WIN32_WINNT` is not defined in autotools_clang_conda environment,
    # causing `MAGICKCORE_POSIX_SUPPORT` to be set instead of `MAGICKCORE_WINDOWS_SUPPORT`.
    # This leads to `dirent.h/sys/wait.h` being included, which don't exist on Windows.
    export CPPFLAGS="${CPPFLAGS} -D_WIN32_WINNT=0x0601"

    # Windows system libraries required by MagickCore/nt-*.c
    export LIBS="${LIBS} -ladvapi32 -luser32"

    # Ensure configure finds conda-forge host .pc files under Library/lib/pkgconfig.
    export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig"

    # On Windows with clang, UCRT's complex.h is incompatible with fftw3's _Complex usage.
    # Disable complex math functions to use fftw double[2] fallback macros in fourier.c
    export ac_cv_header_complex_h=no
    export ac_cv_func_cabs=no
    export ac_cv_func_carg=no
    export ac_cv_func_creal=no
    export ac_cv_func_cimag=no

    # Fix magick-baseconfig.h for downstream MSVC (cl.exe) consumers.
    #
    # The conda-forge imagemagick package is built with clang/autotools.
    # clang on Windows supports both __restrict and __restrict__, so
    # AC_C_RESTRICT selects __restrict__ (GCC/Clang form).  MSVC only
    # supports __restrict (single underscore), causing C2086/C2371 errors
    # when libvips or other downstream packages include MagickCore headers.
    #
    # Similarly, clang on Windows provides ssize_t via sys/types.h, so
    # AC_TYPE_SSIZE_T finds it and leaves the ssize_t #undef in place.
    # MSVC's SDK does not provide ssize_t, causing C2065 (undeclared
    # identifier) errors in downstream MSVC builds.
    #
    # We first try to override the autoconf cache variables so that
    # configure generates the correct magick-baseconfig.h directly.
    # The sed commands below act as a guaranteed fallback in case the
    # cache overrides have no effect (e.g., autoconf version differences).
    
    # AC_C_RESTRICT: tell configure that __restrict is the restrict keyword,
    # not __restrict__ (which is the clang default on Windows).
    export ac_cv_c_restrict=__restrict
    
    # AC_TYPE_SSIZE_T: tell configure that ssize_t does not exist on this
    # platform, so it emits a typedef in magick-baseconfig.h.
    export ac_cv_type_ssize_t=no

    # MSVC/lld-link build should not link libstdc++.
    sed -i -E 's/(^| )-lstdc\+\+($| )/ /g' "${PREFIX}"/lib/pkgconfig/*.pc

    with_x=no
else
    with_x=yes
fi

./configure --prefix=${PREFIX} \
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
            --with-openexr=yes \
            --with-openjp2=yes \
            --with-pango=yes \
            --with-perl=no \
            --with-png=yes \
            --with-raqm=no \
            --with-raw=yes \
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
    make -j${CPU_COUNT}
    make check -j1

    # When performing a parallel installation on Windows, a conflict error occurs stating that magick.exe cannot be found
    make install
    grep -n 'ssize_t' "${PREFIX}/include/ImageMagick-7/MagickCore/magick-baseconfig.h" || true

    # Fix magick-baseconfig.h for MSVC (cl.exe) consumers.
    #
    # The package is built with clang/autotools, which detects __attribute__
    # support and sets MAGICKCORE_HAVE___ATTRIBUTE__=1 in magick-baseconfig.h.
    # MSVC does not support __attribute__, so method-attribute.h would expand
    # magick_attribute to __attribute__ instead of the no-op MSVC branch.
    # Undefine MAGICKCORE_HAVE___ATTRIBUTE__ under _MSC_VER so that
    # method-attribute.h falls through to the MAGICKCORE_WINDOWS_SUPPORT branch.
    #
    # Also, clang on Windows provides ssize_t via sys/types.h, so AC_TYPE_SSIZE_T
    # finds it and emits no typedef in magick-baseconfig.h. MSVC's SDK does not
    # provide ssize_t, so we inject a typedef ptrdiff_t ssize_t guarded by _MSC_VER.
    BASECONFIG="${PREFIX}/include/ImageMagick-7/MagickCore/magick-baseconfig.h"
    # Add MSVC ssize_t typedef after the _magickcore_ssize_t block
    perl -i -0777 -pe \
      's|(#ifndef _magickcore_ssize_t\n#define _magickcore_ssize_t int)|$1\n#ifdef _MSC_VER\n#  include <stddef.h>\n#  ifndef ssize_t\n    typedef ptrdiff_t ssize_t;\n#  endif\n#endif|' \
      "${BASECONFIG}"
    
    # Add MSVC __attribute__ guard
    perl -i -0777 -pe \
      's|(#define MAGICKCORE_HAVE___ATTRIBUTE__ 1)|$1\n#ifdef _MSC_VER\n#  undef MAGICKCORE_HAVE___ATTRIBUTE__\n#endif|' \
      "${BASECONFIG}"
    
    for f in "${PREFIX}/lib/"*.dll.lib; do
        base=$(basename "$f" .dll.lib)
        cp "$f" "${PREFIX}/lib/${base}.lib"
    done
else
    make -j${CPU_COUNT}
    make check -j"${CPU_COUNT}"
    make install -j${CPU_COUNT}
fi
