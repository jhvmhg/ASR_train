#!/bin/bash

set -e

nj=24

# configs for 'chain'
stage=9
train_stage=-10
get_egs_stage=-10

chunk_width=40,30,20
chunk_left_context=40
chunk_right_context=0
label_delay=5
srand=0


# training options
num_epochs=4
initial_effective_lrate=0.001
final_effective_lrate=0.0001
leftmost_questions_truncate=-1
max_param_change=2.0
final_layer_normalize_target=0.5
num_jobs_initial=1
num_jobs_final=2
minibatch_size=128
frames_per_eg=150
remove_egs=false
common_egs_dir=
xent_regularize=0.1

# End configuration section.
echo "$0 $@"  # Print the command line for logging

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh


dir=$1

if ! cuda-compiled; then
  cat <<EOF && exit 1
This script is intended to be used with GPUs but you have not compiled Kaldi with CUDA
If you want to use GPUs (and have them), go to src/, and configure and make on a machine
where "nvcc" is installed.
EOF
fi

train_mfcc=../train_mfcc
train_fbank=../train_fbank
ali_dir=exp/tri4b_ali
lang=data/lang




if [ $stage -le 12 ]; then
  echo "$0: creating neural net configs using the xconfig parser";
  num_targets=$(tree-info $ali_dir/tree |grep num-pdfs|awk '{print $2}')
  learning_rate_factor=$(echo "print 0.5/$xent_regularize" | python)

  mkdir -p $dir/configs
  cat <<EOF > $dir/configs/network.xconfig
  input dim=40 name=input

  # please note that it is important to have input layer with the name=input
  # as the layer immediately preceding the fixed-affine-layer to enable
  # the use of short notation for the descriptor
  fixed-affine-layer name=lda input=Append(-2,-1,0,1,2) affine-transform-file=$dir/configs/lda.mat

  # the first splicing is moved before the lda layer, so no splicing here
  relu-renorm-layer name=tdnn1 dim=520
  relu-renorm-layer name=tdnn2 dim=520 input=Append(-1,0,1)
  fast-lstmp-layer name=lstm1 cell-dim=520 recurrent-projection-dim=130 non-recurrent-projection-dim=130 decay-time=20 delay=-3
  relu-renorm-layer name=tdnn3 dim=520 input=Append(-3,0,3)
  relu-renorm-layer name=tdnn4 dim=520 input=Append(-3,0,3)
  fast-lstmp-layer name=lstm2 cell-dim=520 recurrent-projection-dim=130 non-recurrent-projection-dim=130 decay-time=20 delay=-3
  relu-renorm-layer name=tdnn5 dim=520 input=Append(-3,0,3)
  relu-renorm-layer name=tdnn6 dim=520 input=Append(-3,0,3)
  fast-lstmp-layer name=lstm3 cell-dim=520 recurrent-projection-dim=130 non-recurrent-projection-dim=130 decay-time=20 delay=-3

  output-layer name=output input=lstm3 output-delay=$label_delay dim=$num_targets max-change=1.5
EOF
  steps/nnet3/xconfig_to_configs.py --xconfig-file $dir/configs/network.xconfig --config-dir $dir/configs/
fi


if [ $stage -le 13 ]; then
  steps/nnet3/train_rnn.py --stage=$train_stage \
    --cmd="$decode_cmd" \
    --use-gpu wait \
    --feat.cmvn-opts="--norm-means=false --norm-vars=false" \
    --trainer.srand=$srand \
    --trainer.max-param-change=2.0 \
    --trainer.num-epochs=6 \
    --trainer.deriv-truncate-margin=10 \
    --trainer.samples-per-iter=20000 \
    --trainer.optimization.num-jobs-initial=2 \
    --trainer.optimization.num-jobs-final=4 \
    --trainer.optimization.initial-effective-lrate=0.0003 \
    --trainer.optimization.final-effective-lrate=0.00003 \
    --trainer.optimization.shrink-value 0.99 \
    --trainer.rnn.num-chunk-per-minibatch=128,64 \
    --trainer.optimization.momentum=0.5 \
    --egs.chunk-width=$chunk_width \
    --egs.chunk-left-context=$chunk_left_context \
    --egs.chunk-right-context=$chunk_right_context \
    --egs.chunk-left-context-initial=0 \
    --egs.chunk-right-context-final=0 \
    --egs.dir="$common_egs_dir" \
    --cleanup.remove-egs=$remove_egs \
    --use-gpu=wait \
    --feat-dir=${train_fbank} \
    --ali-dir=$ali_dir \
    --lang=$lang \
    --reporting.email="$reporting_email" \
    --dir=$dir  || exit 1;

fi

echo "Done";
exit 0;

