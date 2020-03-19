#!/bin/python3
# coding:utf-8

import sys
import wave
import contextlib

scp = sys.argv[1]
duration = 0

with open(scp) as f:
    line = f.readline()
    while line:
        fname = line.strip().split()[1]
        with contextlib.closing(wave.open(fname,'r')) as wav:
            frames = wav.getnframes()
            rate = wav.getframerate()
            duration += frames / float(rate)
        line = f.readline()
print('总时长：%s小时' %(duration/3600))
