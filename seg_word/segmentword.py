#! /usr/bin/python3
# coding:utf-8

import sys
import re
import jieba

seg_dict = sys.argv[1]
orig_file = sys.argv[2]
seg_file = sys.argv[3]
oov_file = sys.argv[4]

words = set(i.strip().split()[0] for i in open(seg_dict).readlines())

jieba.initialize()
jieba.set_dictionary(seg_dict)

out = open(seg_file, 'w')
oov_out = open(oov_file, 'w')
for line in open(orig_file).readlines():
    line = line.strip()
    sn, text = line.split(maxsplit=1)
    text = re.sub('\s', '', text)
    text = jieba.lcut(text.lower(), cut_all=False, HMM=False)
    flag = False
    oov = []
    for word in text:
        if word not in words:
            flag = True
            oov.append(word)
    if not flag:
        out.write(sn + '\t' + ' '.join(text) + '\n')
    else:
        oov_out.write(sn + '\t' + ' '.join(text) + '|' + ' '.join(oov) + '\n')
out.close()
oov_out.close()
