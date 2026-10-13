#!/bin/bash
gcc main.c -o main.bin -std=gnu99 || exit 1
./main.bin "$@"
