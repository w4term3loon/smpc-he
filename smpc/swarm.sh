#!/bin/sh

slaves=$(( $1 - 1 ))
lua participant.lua "$1" &
for i in $(seq 1 $slaves); do
  lua participant.lua > "log/$i.log" &
done

