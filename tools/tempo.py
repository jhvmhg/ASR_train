#!/usr/bin/python3
# coding:utf8

import os,sys

scp = sys.argv[1]
out_scp = sys.argv[2]

out = open(out_scp, 'w')

for line in open(scp).readlines():
    line = line.strip()
    name, path = line.split()
    new_name = '20190307' + name
    new_path = '/home1/gongxingwei/1000h/speed09/' + new_name + '.wav'
    os.system('sox ' + path + ' ' + new_path + ' tempo 0.9')
    out.write(new_name + '\t' + new_path + '\n')
out.close() 
