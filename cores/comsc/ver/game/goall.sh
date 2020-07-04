#!/bin/bash

rm -f scene
for i in scene*; do
    s=${i#scene}
    govideo.sh -s $s
done