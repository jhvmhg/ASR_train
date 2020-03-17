#! /usr/bin/python3
# coding:utf-8

import sys
import re

in_file = sys.argv[1]
out_file = open(sys.argv[2], 'w')

out = []

with open(in_file) as f:
    line = f.readline()
    while line:
        line = re.sub("\s", "", line.strip()).lower()
        lines = re.split("[^\u4e00-\u9fa50-9a-z]", line)
        lines = list(filter(lambda i:len(i)>0, lines))
        out += lines
        line = f.readline()

out_file.write('\n'.join(out))
out_file.close()
