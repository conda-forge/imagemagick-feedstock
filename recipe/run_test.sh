#!/bin/bash


pushd test_data

magick montage  -geometry +4+4  in.png in.png in.png in.png out.png

popd
