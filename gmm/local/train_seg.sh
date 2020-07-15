#!/bin/bash

set -e

nj=24

# configs for 'chain'
stage=9
train_stage=-10
get_egs_stage=-10


# training options
num_epochs=4
initial_effective_lrate=0.001
final_effective_lrate=0.0001
leftmost_questions_truncate=-1
max_param_change=2.0
final_layer_normalize_target=0.5
num_jobs_initial=1
num_jobs_final=3
minibatch_size=128
frames_per_eg=150
remove_egs=false
common_egs_dir=
xent_regularize=0.1

lang=.data/lang_aud
feat_dir=../data/combine_data
ali_dir=../lats/train_all_lat
targets_dir=exp/segmentation1a/train_fbank_combine_targets

# End configuration section.
echo "$0 $@"  # Print the command line for logging

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh


dir=$1



if [ $stage -le 11 ]; then

    bash local/segmentation/ali_to_targets.sh \
      --silence-phones ../gmm/data/lang/phones/optional_silence.txt \
      --max-phone-duration 0.5 \
      $feat_dir $lang \
      $ali_dir $targets_dir
fi

if [ $stage -le 12 ]; then
  mkdir -p $dir
  echo "$0: creating neural net configs using the xconfig parser";

  num_targets=3

  mkdir -p $dir/configs
  cat <<EOF > $dir/configs/network.xconfig
  input dim=40 name=input

  # please note that it is important to have input layer with the name=input
  # as the layer immediately preceding the fixed-affine-layer to enable
  # the use of short notation for the descriptor
#   fixed-affine-layer name=lda input=Append(-2,-1,0,1,2,ReplaceIndex(ivector, t, 0)) affine-transform-file=$dir/configs/lda.mat

  # the first splicing is moved before the lda layer, so no splicing here
  relu-renorm-layer name=tdnn1 dim=650 input=Append(-2,-1,0,1,2)
  relu-renorm-layer name=tdnn2 dim=650 input=Append(-1,0,1)
  relu-renorm-layer name=tdnn3 dim=650 input=Append(-1,0,1)
  relu-renorm-layer name=tdnn4 dim=650 input=Append(-3,0,3)
  relu-renorm-layer name=tdnn5 dim=650 input=Append(-6,-3,0)
  output-layer name=output dim=$num_targets max-change=1.5
EOF
  steps/nnet3/xconfig_to_configs.py --xconfig-file $dir/configs/network.xconfig --config-dir $dir/configs/
fi


if [ $stage -le 13 ]; then
  steps/nnet3/train_raw_dnn.py --stage $train_stage \
    --cmd "$decode_cmd" \
    --use-gpu wait \
    --feat.cmvn-opts "--norm-means=false --norm-vars=false" \
    --targets-scp exp/segmentation1a/train_fbank_combine_targets/targets.scp \
    --egs.dir "$common_egs_dir" \
    --egs.stage $get_egs_stage \
    --trainer.num-epochs $num_epochs \
    --trainer.optimization.num-jobs-initial $num_jobs_initial \
    --trainer.optimization.num-jobs-final $num_jobs_final \
    --trainer.optimization.initial-effective-lrate $initial_effective_lrate \
    --trainer.optimization.final-effective-lrate $final_effective_lrate \
    --trainer.max-param-change $max_param_change \
    --cleanup.remove-egs $remove_egs \
    --feat-dir $feat_dir \
    --dir $dir  || exit 1;

fi