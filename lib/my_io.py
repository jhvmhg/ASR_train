import os

"""
从steps/data/reverberate_data_dir.py中提取的
"""

def parse_file_to_dict(file, assert2fields = False, value_processor = None):
    """ This function parses a file and pack the data into a dictionary
        It is useful for parsing file like wav.scp, utt2spk, text...etc
    """
    if value_processor is None:
        value_processor = lambda x: x[0]
    dict = {}
    for line in open(file, 'r', encoding='utf-8'):
        parts = line.split()
        if assert2fields:
            assert(len(parts) == 2)

        dict[parts[0]] = value_processor(parts[1:])
    return dict

def write_dict_to_file(dict, file_name):
    """ This function creates a file and write the content of a dictionary into it
    """
    file = open(file_name, 'w', encoding='utf-8')
    keys = sorted(dict.keys())
    for key in keys:
        value = dict[key]
        if type(value) in [list, tuple] :
            if type(value) is tuple:
                value = list(value)
            value = sorted(value)
            value = ' '.join(str(value))
        file.write('{0} {1}\n'.format(key, value))
    file.close()
    
def get_new_id(utt, utt_modifier_type, utt_modifier):
    """ This function generates a new id from the input id
        This is needed when we have to create multiple copies of the original data
        E.g. get_new_id("swb0035", prefix="rvb", copy=1) returns a string "rvb1_swb0035"
    """
    if utt_modifier_type == "suffix" and len(utt_modifier) > 0:
        new_utt = utt + "-" + utt_modifier
    elif utt_modifier_type == "prefix" and len(utt_modifier) > 0:
        new_utt = utt_modifier + "-" + utt
    else:
        new_utt = utt

    return new_utt

def copy_file_if_exists(input_file, output_file, utt_modifier_type,
                        utt_modifier, fields=[0]):
    """
    fields：[0]为不改变spk-id，[0, 1]为spk-id加前后缀
    """
    if os.path.isfile(input_file):
        clean_dict = parse_file_to_dict(input_file,
            value_processor = lambda x: " ".join(x))
        new_dict = {}
        for key in clean_dict.keys():
            modified_key = get_new_id(key, utt_modifier_type, utt_modifier)
            if len(fields) > 1:
                values = clean_dict[key].split(" ")
                modified_values = values
                for idx in range(1, len(fields)):
                    modified_values[idx-1] = get_new_id(values[idx-1],
                                            utt_modifier_type, utt_modifier)
                new_dict[modified_key] = " ".join(modified_values)
            else:
                new_dict[modified_key] = clean_dict[key]
        write_dict_to_file(new_dict, output_file)