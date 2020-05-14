#!/usr/bin/env python


import re
import os
import sys

destdir = sys.argv[1]
split_tag = ''
fout = open(os.path.join(destdir, 'wav.new.scp'), 'w')

for line in sys.stdin.readlines():
    if len(line.strip()) == 0:
        continue
    if len(split_tag) == 0:
        split_tag = re.findall('\s', line)[0]
    parts = line.strip().split(split_tag, 1)
    reco_id = parts[0]
    wav_aug = os.path.join(destdir, 'wav', reco_id + '.wav')
    if re.match('sp1\.0', reco_id):
        command = 'cp ' + parts[1] + ' ' + wav_aug
    else:
        command = parts[1][:-1]
        command = re.sub('-(?!.*-)', wav_aug, command)
    fout.write(reco_id + split_tag + os.path.realpath(wav_aug) + '\n')
    os.system(command)

fout.close()
