#!/bin/bash

VC=/vagrant/.cache
AC=/var/cache/apt/archives
VH=/home/vagrant

mkdir -p $VC

# I'm iterating through tuples of local dir to shared-dir
OLDIFS=$IFS; IFS=','
for c in $AC,$VC/apt-archives $VH/.ivy2,$VC/ivy $VH/.m2,$VC/maven $VH/.subfloor,$VC/subfloor
do
    set $c
    if [ ! -h "$1" ]; then
        if [ -d "$1" ]; then
            rsync -avu $1/ $2
        else
            mkdir -p $2
        fi
        rm -rf $1
        ln -s $2 $1
    fi
done
IFS=$OLDIFS
