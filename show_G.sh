

. ./cmd.sh ## You'll want to change cmd.sh to something that will work on your system.
           ## This relates to the queue.
. ./path.sh
. ./utils/parse_options.sh

lang=$1
out=$2

#sed 's/$/\ 1/' seg.dict > seg_lm.dict
python seg_word/segmentword.py seg.dict corpus.txt corpus.seg oov_file
sed 's/[^\s]*\s//' corpus.seg > corpus_lm.txt
ngram-count -text corpus_lm.txt -order 3 -unk -map-unk "<UNK>" -interpolate -lm corpus.lm
arpa2fst --disambig-symbol=#0 \
             --read-symbol-table=${lang}/words.txt corpus.lm ${out}/G.fst

fstdraw --isymbols=${lang}/words.txt --osymbols=${lang}/words.txt ${out}/G.fst ${out}/G1.dot