#!/bin/bash

stage=0

. ./cmd.sh ## You'll want to change cmd.sh to something that will work on your system.
           ## This relates to the queue.
. ./path.sh
. ./utils/parse_options.sh

n=24

if [ $stage -le 0 ]; then
    #monophone
    steps/train_mono.sh --stage 20 --boost-silence 1.25 --nj $n --cmd "$train_cmd" $1 data/lang exp/mono || exit 1;

    #monophone_ali
    steps/align_si.sh --boost-silence 1.25 --nj $n --cmd "$train_cmd" $1 data/lang exp/mono exp/mono_ali || exit 1;
fi


if [ $stage -le 1 ]; then
    #triphone
    steps/train_deltas.sh --boost-silence 1.25 --cmd "$train_cmd" 10000 80000 $1 data/lang exp/mono_ali exp/tri1 || exit 1;

    #triphone_ali
    steps/align_si.sh --nj $n --cmd "$train_cmd" $1 data/lang exp/tri1 exp/tri1_ali || exit 1;
fi


if [ $stage -le 2 ]; then
    #lda_mllt
    steps/train_lda_mllt.sh --stage 2 --cmd "$train_cmd" --splice-opts "--left-context=3 --right-context=3" 12000 120000 $1 data/lang exp/tri1_ali exp/tri2b || exit 1;
    #lda_mllt_ali
    steps/align_si.sh  --nj $n --cmd "$train_cmd" --use-graphs true $1 data/lang exp/tri2b exp/tri2b_ali || exit 1;
fi


if [ $stage -le 3 ]; then
    #sat
    steps/train_sat.sh --cmd "$train_cmd" 15000 180000 $1 data/lang exp/tri2b_ali exp/tri3b || exit 1;
    #sat_ali
    steps/align_fmllr.sh --nj $n --cmd "$train_cmd" $1 data/lang exp/tri3b exp/tri3b_ali || exit 1;
fi


if [ $stage -le 4 ]; then
    #quick
    steps/train_quick.sh --cmd "$train_cmd" 18000 250000 $1 data/lang exp/tri3b_ali exp/tri4b || exit 1;
    #quick_ali
    steps/align_fmllr.sh --nj $n --cmd "$train_cmd" $1 data/lang exp/tri4b exp/tri4b_ali || exit 1;
    #quick_ali_cv
    #steps/align_fmllr.sh --nj $n --cmd "$train_cmd" $2 data/lang exp/tri4b exp/tri4b_ali_cv || exit 1;
fi


echo "Done";
exit 0;

