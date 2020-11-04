# MCY

import os
import sys
from pathlib import Path

sys.path.append("./")
from lib.io import parse_file_to_dict, write_dict_to_file, get_new_id, copy_file_if_exists
import shutil


def relace_utt(oridir, destdir, file):
    """ This function genarate destdir/file from oridir/file contain utt in destdir/wav.scp
        E.g. relace_utt("magic_aug/data", "magic_aug/data_reverb", "utt2dur")
    """

    utt2dur = parse_file_to_dict(oridir + os.sep + file, value_processor=lambda x: " ".join(x))

    des_scp = parse_file_to_dict(destdir + os.sep + "wav.scp")

    des_utt2dur = {}
    for utt in des_scp:
        typ, utt_ori = utt.split("-")
        des_utt2dur[utt] = utt2dur[utt_ori]

    write_dict_to_file(des_utt2dur, destdir + os.sep + file)


def genarate_wav_scp(wav_dir):
    """ This function generates wav.scp (.wav file at dir)
        If wav.scp already exists,  move it to directory (wav_dir/.backup/)
        E.g. genarate_wav_scp("dataset/aishell_16k_mix/data_babble")
    """
    wav_list = list(Path(wav_dir).rglob("*.wav"))
    wav_scp = {}
    for path_item in wav_list:
        wav_path = str(path_item)
        wav_scp[os.path.basename(os.path.splitext((wav_path))[0])] = wav_path
    if os.path.isfile(wav_dir + os.sep + "wav.scp"):
        if not os.path.exists(wav_dir + os.sep + ".backup"):
            os.mkdir(wav_dir + os.sep + ".backup")
        shutil.copy(wav_dir + os.sep + "wav.scp", wav_dir + os.sep + ".backup/wav.scp")
    write_dict_to_file(wav_scp, wav_dir + os.sep + "wav.scp")


def main():
    if len(sys.argv) != 4 and len(sys.argv) != 2:
        print("replace_utt.py <original_dir> <dest_dir> <file>")
        print("or replace_utt.py <wav_dir> to genarate wav.scp")
        exit(1)
    if len(sys.argv) == 4:
        oridir = sys.argv[1]
        destdir = sys.argv[2]
        file = sys.argv[3]
        relace_utt(oridir, destdir, file)
    else:
        genarate_wav_scp(sys.argv[1])


if __name__ == '__main__':
    main()

