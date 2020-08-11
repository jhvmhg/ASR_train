#!/bin/bash

# Copyright 2017 Johns Hopkins University (Shinji Watanabe)
#  Apache 2.0  (http://www.apache.org/licenses/LICENSE-2.0)

. ./path.sh || exit 1;
. ./cmd.sh || exit 1;

# general configuration
backend=pytorch
stage=0        # start from 0 if you need to start from data preparation
stop_stage=100
ngpu=2         # number of gpus ("0" uses cpu, otherwise use gpu)
debugmode=1
dumpdir=dump   # directory to dump full features
N=0            # number of minibatches to be used (mainly for debugging). "0" uses all minibatches.
verbose=0      # verbose option
resume=        # Resume the training from snapshot

# feature configuration
do_delta=false

decode_config=conf/decode.yaml

# rnnlm related
lm_resume=         # specify a snapshot file to resume LM training
lmtag=             # tag for managing LMs

# decoding parameter
recog_model=model.acc.best # set a model to be used for decoding: 'model.acc.best' or 'model.loss.best'
n_average=10

# data dir, modify this to your AISHELL-2 data path

recog_set="/home1/meichaoyang/dataset/magictang/espnet/test"


lmexpdir=/home1/meichaoyang/workspace/git/espnet/egs/aishell2/asr1/lmexpdir/train_rnnlm_pytorch_lm
expdir=/home1/meichaoyang/workspace/git/espnet/egs/aishell2/asr1/train_sp_pytorch_train


# exp tag
tag="" # tag for managing experiments.

. utils/parse_options.sh || exit 1;

# Set bash to 'debug' mode, it will exit on :
# -e 'error', -u 'undefined variable', -o ... 'error in pipeline', -x 'print commands',
set -e
set -u
set -o pipefail

train_set=train_sp
train_dev=dev

dict=data/lang_1char/${train_set}_units.txt
echo "dictionary: ${dict}"

if [ ${stage} -le 0 ] && [ ${stop_stage} -ge 0 ]; then
    ### Task dependent. You have to make data the following preparation part by yourself.
    ### But you can utilize Kaldi recipes in most cases
    echo "stage 0: Data preparation"


    # Normalize text to capital letters
    for x in ${recog_set}; do
        mv ${x}/text ${x}/text.org
        paste <(cut -f 1 ${x}/text.org) <(cut -f 2 ${x}/text.org | tr '[:lower:]' '[:upper:]') \
            > ${x}/text
        rm ${x}/text.org
    done
fi

if [ ${stage} -le 1 ] && [ ${stop_stage} -ge 1 ]; then
    ### Task dependent. You have to design training and dev sets by yourself.
    ### But you can utilize Kaldi recipes in most cases
    echo "stage 1: Feature Generation"

    # Generate the fbank features; by default 80-dimensional fbanks with pitch on each frame
    for x in ${recog_set}; do
        steps/make_fbank_pitch.sh --cmd "$train_cmd" --nj 20 --write_utt2num_frames true \
            ${x}
    done


    # dump features for training
    split_dir=$(echo $PWD | awk -F "/" '{print $NF "/" $(NF-1)}')


    for rtask in ${recog_set}; do
        compute-cmvn-stats scp:${rtask}/feats.scp ${rtask}/cmvn.ark

        feat_recog_dir=${rtask}/dump/delta${do_delta}; mkdir -p ${feat_recog_dir}
        dump.sh --cmd "$train_cmd" --nj 20 --do_delta ${do_delta} \
            ${rtask}/feats.scp ${rtask}/cmvn.ark ${rtask}/log \
            ${rtask}/dump
    done
fi


if [ ${stage} -le 2 ] && [ ${stop_stage} -ge 2 ]; then
    ### Task dependent. You have to check non-linguistic symbols used in the corpus.
    echo "stage 2:Json Data Preparation"


    echo "make json files"


    for rtask in ${recog_set}; do
        feat_recog_dir=${rtask}/dump/delta${do_delta}
        data2json.sh --feat ${rtask}/dump/feats.scp \
		     ${rtask} ${dict} > ${feat_recog_dir}/data.json
    done
fi


if [ ${stage} -le 3 ] && [ ${stop_stage} -ge 3 ]; then
    echo "stage 3: Decoding"
    nj=12
#     recog_model=snapshot.ep.5
    recog_model=model.last10.avg.best


    pids=() # initialize pids
    for rtask in ${recog_set}; do
    (
        decode_dir=decode_avg_best_${lmtag}
        feat_recog_dir=${rtask}/dump/delta${do_delta}

        # split data
        splitjson.py --parts ${nj} ${feat_recog_dir}/data.json

        #### use CPU for decoding
        ngpu=0

        ${decode_cmd} JOB=1:${nj} ${rtask}/${decode_dir}/log/decode.JOB.log \
            asr_recog.py \
            --config ${decode_config} \
            --ngpu ${ngpu} \
            --backend ${backend} \
            --batchsize 0 \
            --recog-json ${feat_recog_dir}/split${nj}utt/data.JOB.json \
            --result-label ${rtask}/${decode_dir}/data.JOB.json \
            --model ${expdir}/results/${recog_model}  \
            --rnnlm ${lmexpdir}/results/rnnlm.model.best

        score_sclite.sh ${rtask}/${decode_dir} ${dict}

    ) &
    pids+=($!) # store background pids
    done
    i=0; for pid in "${pids[@]}"; do wait ${pid} || ((++i)); done
    [ ${i} -gt 0 ] && echo "$0: ${i} background jobs are failed." && false
    echo "Finished"
fi