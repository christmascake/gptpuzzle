#!/bin/bash
./compile.sh || exit 1
./main.bin "$@"
