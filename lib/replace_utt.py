import os
import sys
from pathlib import Path
sys.path.append("./")
from lib.io import parse_file_to_dict, write_dict_to_file, get_new_id, copy_file_if_exists


def relace_utt(oridir, destdir, file):


    utt2dur = parse_file_to_dict(oridir + os.sep + file)
    wav_scp = parse_file_to_dict(oridir + os.sep + "wav.scp")

    des_scp = parse_file_to_dict(destdir + os.sep + "wav.scp")

    des_utt2dur = {}
    for utt in des_scp:
        typ, utt_ori = utt.split("-")
        des_utt2dur[utt] = utt2dur[utt_ori]

    write_dict_to_file(des_utt2dur, destdir + os.sep + file)


def genarate(dir):

    wav_list = list(Path(dir).rglob("*.wav"))
    wav_scp = {}
    for path_item in wav_list:
        wav_path = str(path_item)
        wav_scp[os.path.basename(os.path.splitext((wav_path))[0])] = wav_path
    write_dict_to_file(wav_scp, dir + os.sep + "wav.scp")

def main():
    if len(sys.argv) != 4:
        print("replace_utt.py <original_dir> <dest_dir> <file>")
        exit(1)
    oridir = sys.argv[1]
    destdir = sys.argv[2]
    file = sys.argv[3]
    relace_utt(oridir, destdir, file)

if __name__ == '__main__':
    main()

