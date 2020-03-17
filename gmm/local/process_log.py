#!/usr/bin/python3
# coding:utf-8

import os,sys

log_dir = sys.argv[1]
result = open(sys.argv[2], 'w', encoding="utf-8")

for log in os.listdir(log_dir):
    with open(os.path.join(log_dir, log), encoding='utf-8') as f:
        lines = f.readlines()
        for line in lines:
            if not line.startswith('#') and '.' not in line:
                result.write(line.strip().replace(' ', '\t', 1) + '\n')
result.close()
