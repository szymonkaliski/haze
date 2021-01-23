#!/usr/bin/env bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR" || exit 1

rsync -azP . --exclude .git --delete we@norns.local:/home/we/dust/code/manglive

../maiden-socket/send.js 'norns.script.load("code/manglive/manglive.lua")'

