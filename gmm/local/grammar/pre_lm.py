from ltp import LTP

ltp = LTP()

# !python seg_word/segmentword.py seg.dict corpus.txt corpus.seg oov_file


vocab_file = "seg.dict"
trans_file = "/home1/meichaoyang/workspace/git/ASR_train/data/combine_data/text"
word_segmented_trans = "/home1/meichaoyang/workspace/git/ASR_train/data/combine_data/text.ori"

# jieba.set_dictionary(vocab_file)
with open(word_segmented_trans, "w") as f:
    for line in open(trans_file):
        e1 = line.strip().split()
        #       words = jieba.cut(trans, HMM=False) # turn off new word discovery (HMM-based)
        new_line = e1[0] + '\t' + "".join(e1[1:])
        f.write(new_line + "\n")

with open("/home1/meichaoyang/dataset/weixin/text50k.txt", "r") as f:
    a = f.readlines()
with open("/home1/meichaoyang/dataset/weixin/text50k_nr.txt", "w") as f:
    for line in a:
        wri = False
        utt, txt = line.strip().split()
        seg, hidden = ltp.seg([txt])
        ner = ltp.ner(hidden)
        app = ""
        for i in ner[0]:
            if i[0] == 'Ns':
                wri = True
                start, end = i[1], i[2]
                seg[0][start] = "Nr"
                del seg[0][start + 1:end + 1]
        #                 new_txt="".join(seg[0])+"||" + "".join(seg[0][start:end + 1])
        if wri:
            new_txt = "".join(seg[0]) + app
            print(new_txt)
            f.write(new_txt + "\n")
            f.flush()
