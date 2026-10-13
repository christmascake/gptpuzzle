#!/bin/bash
gcc main.c -w -o main.bin -std=c11 || exit 1
./main.bin "$@"
