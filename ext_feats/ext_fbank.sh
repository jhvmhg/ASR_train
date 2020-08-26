#!/bin/bash

. ./cmd.sh
. ./path.sh

nj=48

. ./utils/parse_options.sh

data_path=$1
if [ ! -f $data_path/wav.scp ];then
    echo 'No wav.scp exists!'
    exit 1
fi

steps/make_fbank.sh --nj $nj --cmd "$train_cmd" $data_path $data_path/log $data_path/_fbank || exit 1;
steps/compute_cmvn_stats.sh $data_path $data_path/cmvn_log $data_path/_cmvn || exit 1;
