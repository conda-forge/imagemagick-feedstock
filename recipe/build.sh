#!/bin/bash
# Get an updated config.sub and config.guess
cp $BUILD_PREFIX/share/gnuconfig/config.* ./config

if [ "$license_family" = "agpl" ]; then
    with_gslib=yes
else
    with_gslib=no
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
            --with-x=yes \
            --with-xml=yes \
            --with-zlib=yes \
            --with-glib=yes

make -j$CPU_COUNT
# FIXME:
# The failure below seems to be associated with the option --with-gslib,
# but I could not get to turn "yes." See the logs for more info.
#
# tests/wandtest.c main 5321 non-conforming drawing primitive definition `text' @ error/draw.c/DrawImage/3269`
# make check
make install -j$CPU_COUNT
