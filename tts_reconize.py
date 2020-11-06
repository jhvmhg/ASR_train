#!/usr/bin/env python
# coding: utf-8

import os
from pathlib import Path
from lib.my_io import parse_file_to_dict, write_dict_to_file, get_new_id, copy_file_if_exists

from tqdm import tqdm


def transSampleRateFile(inf, outf, outSample):
    cmd = f"sox {inf} -r {outSample} {outf}"
    os.system(cmd)


def transSampleRateDir(Inputdir, Outputdir, OutSample):
    os.makedirs(Outputdir, exist_ok=True)
    files = [file for file in os.listdir(Inputdir) if file.endswith(".wav")]
    pbar = tqdm(files)
    pbar.set_description("sox 转换进度")
    for file in pbar:
        inf = os.path.join(Inputdir, file)
        outf = os.path.join(Outputdir, file)
        transSampleRateFile(inf, outf, OutSample)


Inputdir = "/home/meichaoyang/dataset/tingyun_YZ00617_YZ02507"
Outputdir = "/home/meichaoyang/dataset/tingyun_YZ00617_YZ02507_16k/wav"
OutSample = 16000
transSampleRateDir(Inputdir, Outputdir, OutSample)

# wav.scp

wav_list_16k = list(Path(Outputdir).rglob("*.wav"))
wav_scp = {}
for path_item in wav_list_16k:
    wav_path = str(path_item)
    wav_scp[os.path.basename(os.path.splitext((wav_path))[0])] = wav_path

# text = {}
# with open(os.path.dirname(Outputdir) + '/text', 'r') as f:
#     lines = f.readlines()
#     for line in lines:
#         data = line.split()
#         text[data[0]] = "".join(data[1:])
#
# with open(os.path.dirname(Outputdir) + '/text.rio', 'w') as f:
#     for i in sorted(text):
#         f.write(i + '\t' + text[i] + '\n')

with open(os.path.dirname(Outputdir) + '/wav.scp', 'w') as f:
    for i in sorted(wav_scp):
        f.write(i + '\t' + wav_scp[i] + '\n')

new_wav_scp = parse_file_to_dict(os.path.dirname(Outputdir) + "/wav.scp", assert2fields=True)
utts = list(new_wav_scp.keys())
utt2spk = {}
for utt in utts:
    if utt.startswith("A"):
        spk = utt
    else:
        spk = utt.split("W")[0]
    utt2spk[utt] = spk

write_dict_to_file(utt2spk, os.path.dirname(Outputdir) + '/utt2spk')
write_dict_to_file(utt2spk, os.path.dirname(Outputdir) + '/spk2utt')

## 提取特征和解码

os.system(
    'cd ext_feats && bash ext_fbank.sh {dir} && utils/fix_data_dir.sh {dir}'.format(dir=os.path.dirname(Outputdir)))
os.system(
    'cd chain && bash decode.sh --nj 2 --stage 1 exp/chain/combine_data_exp/graph_5000_blm {dir} {dir}/result'.format(
        dir=os.path.dirname(Outputdir)))


