import sys
sys.path.insert(0, '..')
from lib.IO import parse_file_to_dict, write_dict_to_file

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

    parser.add_argument("all_lat_scp", type=str,
                        help="Alignment info file. ")
    parser.add_argument("ori_lat_scp", type=str,
                        help="File to write targets matrix archive in text "
                             "format")
    parser.add_argument("dest_lat_scp", type=str,
                        help="File to write targets matrix archive in text "
                             "format")
    args = parser.parse_args()
    return args

def run(args):

    lat_scp = parse_file_to_dict(args.all_lat_scp)
    lat_scp_JOB = parse_file_to_dict(args.ori_lat_scp)
    lat_scp_new = {}
    for utt in lat_scp_JOB:
        a = utt.split("-", 1)
        if len(a) == 2:
            prefix = a[0]
            utt_ori = a[1]
        else:
            prefix = ""
            utt_ori = a[0]
        if "sp" in prefix:
            lat_scp_new[utt] = lat_scp[utt]
        else:
            lat_scp_new[utt] = lat_scp[utt_ori]


    write_dict_to_file(lat_scp_new,args.dest_lat_scp)



def main():
    args = get_args()

    try:
        run(args)
    except Exception:
        raise


if __name__ == "__main__":
    main()