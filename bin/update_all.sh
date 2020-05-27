#!/bin/bash
parallel jtcore contra ::: -mist -mister -sidi
mkdir -p /tmp/contra
rm -rf /tmp/contra/*
cp $JTROOT/rom/mra/*.mra /tmp/contra
cd /tmp/contra
mkdir -p _alternatives/_Contra
mv *.mra _alternatives/_Contra
mv _alternatives/_Contra/Contra.mra .
zip -r contra.zip Contra.mra _alternatives
mv contra.zip $JTROOT/../jtbin/mister/contra/releases
