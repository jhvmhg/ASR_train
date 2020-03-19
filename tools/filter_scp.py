#!/bin/python3
# coding:utf-8

import sys
import re

filter_file = sys.argv[1]
f_input = sys.argv[2]
f_output = sys.argv[3]

tags = set()
with open(filter_file) as f:
    for line in f.readlines():
        tags.add(line.split()[0])

out = []
sep = re.search('\s', open(f_input).readline()).group()
with open(f_input) as f:
    for line in f.readlines():
        line = line.strip()
        tag, content = line.split(maxsplit=1)
        if tag in tags:
            out.append(tag + sep + content)

with open(f_output, 'w') as f:
    f.write('\n'.join(out) + '\n')
