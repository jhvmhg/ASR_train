#!/usr/bin/python3
# coding:utf8

import os,sys
import random

all_scp = sys.argv[1]
test_count = int(sys.argv[2])

train_out = open('train.scp', 'w')
test_out = open('test.scp', 'w')

all = [i.split()[0] for i in open(all_scp).readlines()]
test = random.sample(all, test_count)

for i in open(all_scp).readlines():
    i = i.strip()
    if i.split()[0] in test:
        test_out.write(i + '\n')
    else:
        train_out.write(i + '\n')

train_out.close()
test_out.close()
