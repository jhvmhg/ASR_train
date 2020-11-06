#!/usr/bin/env python
# coding: utf-8

import os
import sys
from pathlib import Path
from my_io import parse_file_to_dict, write_dict_to_file, get_new_id, copy_file_if_exists

from tqdm import tqdm


def list_files(path):
    res = []
    lsdir = os.listdir(path)
    dirs = [i for i in lsdir if os.path.isdir(os.path.join(path, i))]
    if dirs:
        for i in dirs:
            res.extend(list_files(os.path.join(path, i)))
    files = [i for i in lsdir if os.path.isfile(os.path.join(path, i))]
    for f in files:
        if f.endswith(".wav"):
            res.append(os.path.join(path, f))

    return res


def transSampleRateFile(inf, outf, outSample):
    cmd = f"sox {inf} -r {outSample} {outf}"
    os.system(cmd)


def transSampleRateDir(Inputdir, Outputdir, OutSample):
    os.makedirs(Outputdir, exist_ok=True)

    files = list(Path(Inputdir).rglob("*.wav"))
    pbar = tqdm(files)
    pbar.set_description("sox 转换进度")
    for file in pbar:
        inf = os.path.join(Inputdir, str(file))
        outf = os.path.join(Outputdir, os.path.basename(file))
        transSampleRateFile(file, outf, OutSample)


def main():
    Inputdir = sys.argv[1]
    Outputdir = sys.argv[2]
    OutSample = 16000
    transSampleRateDir(Inputdir, os.path.join(Outputdir, "wav"), OutSample)

    wav_list_16k = list(Path(Outputdir).rglob("*.wav"))
    wav_scp = {}
    for path_item in wav_list_16k:
        wav_path = str(path_item)
        wav_scp[os.path.basename(os.path.splitext((wav_path))[0])] = wav_path

    with open(Outputdir + '/wav.scp', 'w') as f:
        for i in sorted(wav_scp):
            f.write(i + '\t' + wav_scp[i] + '\n')

    new_wav_scp = parse_file_to_dict(Outputdir + "/wav.scp", assert2fields=True)
    utts = list(new_wav_scp.keys())
    utt2spk = {}
    for utt in new_wav_scp:
        spk = utt
        utt2spk[utt] = spk

    write_dict_to_file(utt2spk, Outputdir + '/utt2spk')
    write_dict_to_file(utt2spk, Outputdir + '/spk2utt')


if __name__ == "__main__":
    main()





