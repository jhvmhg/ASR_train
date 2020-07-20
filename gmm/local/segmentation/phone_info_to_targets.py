import argparse
import numpy as np
import sys

from kaldiio import ReadHelper
from kaldiio import WriteHelper

sys.path.insert(0, 'steps')
import libs.common as common_lib

def get_args():
    parser = argparse.ArgumentParser(
        description="""This script converts phone alignment into targets for training
        speech activity detection network. The output is a matrix archive
        with each matrix having 2 columns -- silence and speech.
        The posterior probabilities of the phones of each of the classes are
        summed up to get the target matrix values.
        """)

    parser.add_argument("--silence-phones", type=str,
                        required=True,
                        help="File containing a list of phones that will be "
                             "treated as silence")
    # parser.add_argument("--garbage-phones", type=str,
    #                     required=True,
    #                     help="File containing a list of phones that will be "
    #                          "treated as garbage class")
    parser.add_argument("--max-phone-length", type=int, default=50,
                        help="""Maximum number of frames allowed for a speech
                        phone above which the arc is treated as garbage.""")

    parser.add_argument("phone_ali_info", type=str,
                        help="Alignment info file. ")
    parser.add_argument("targets_file", type=str,
                        help="File to write targets matrix archive in text "
                             "format")
    args = parser.parse_args()
    return args
def run(args):
    silence_phones = {}
    with common_lib.smart_open(args.silence_phones) as silence_phones_fh:
        for line in silence_phones_fh:
            silence_phones[line.strip().split()[0]] = 1

    if len(silence_phones) == 0:
        raise RuntimeError("Could not find any phones in {silence}"
                           "".format(silence=args.silence_phones))

    ali = {}
    with ReadHelper(args.phone_ali_info) as reader:
        for key, numpy_array in reader:
            ali[key] = numpy_array

    target = {}
    with WriteHelper(args.targets_file, compression_method=2) as writer:
        for utt in ali:
            target[utt] = np.zeros((len(ali[utt]), 2), dtype=np.int32)
            for i in range(len(ali[utt])):
                if ali[utt][i] in silence_phones:
                    target[utt][i][0] += 1
                else:
                    target[utt][i][1] += 1
            writer(utt, target[utt])





def main():
    args = get_args()

    try:
        run(args)
    except Exception:
        raise


if __name__ == "__main__":
    main()