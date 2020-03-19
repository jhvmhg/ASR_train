#!/bin/python3
# coding:utf-8

import sys
import re

lex = sys.argv[1]

ph = set()
with open(lex) as  f:
    for line in f.readlines():
        ph.update(set(line.strip().split()[1:]))
ph.discard('sil')

out = open('silence_phones.txt', 'w')
out.write('sil\n')
out.close()

out = open('optional_silence.txt', 'w')
out.write('sil\n')
out.close()

yin_diao = {}
diao_yin = {}
shengmu = {}

for item in ph:
    yin = re.search('[A-Za-z]+', item).group()
    if re.search('[0-9]+', item):
        diao = re.search('[0-9]+', item).group()
        if diao not in diao_yin:
            diao_yin[diao] = set()
        diao_yin[diao].add(item)
        if yin not in yin_diao:
            yin_diao[yin] = set()
        yin_diao[yin].add(item)
    else:
        shengmu[item] = [item]

out = open('extra_questions.txt', 'w')
out.write('sil\n')
for i in sorted(list(diao_yin.keys())):
    out.write(' '.join(sorted(list(diao_yin[i]))) + '\n')
out.write(' '.join(sorted(list(shengmu.keys()))) + '\n')
out.close()

yin_diao.update(shengmu)
out = open('nonsilence_phones.txt', 'w')
for i in sorted(list(yin_diao.keys())):
    out.write(' '.join(sorted(list(yin_diao[i]))) + '\n')
out.close()
