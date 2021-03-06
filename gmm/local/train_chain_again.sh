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
num_jobs_initial=2
num_jobs_final=3
minibatch_size=128
frames_per_eg=150
remove_egs=false
common_egs_dir=
xent_regularize=0.1

frame_subsampling_factor=3
alignment_subsampling_factor=3

# data path
ali_model_dir=exp/chain/tdnn_attend
ali_feats=../train_fbank_combine_fake
ali_dir=exp/chain/chain_combine_fake_align_lat

train_feats=../train_fbank_combine

lang=${ali_model_dir}/lang
lang_new=data/lang_aud_new
tree_dir=exp/chain/chain_tree_again

# config for generate lat and ali from origanl_lat_dir
use_origanl=false
origanl_lat_dir=
prefixes_aug=reverb

# End configuration section.
echo "$0 $@"  # Print the command line for logging

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

if [ -z $lat_dir ]; then
  lat_dir=$ali_dir
fi

dir=$1



if ! cuda-compiled; then
  cat <<EOF && exit 1
This script is intended to be used with GPUs but you have not compiled Kaldi with CUDA
If you want to use GPUs (and have them), go to src/, and configure and make on a machine
where "nvcc" is installed.
EOF
fi



if [ $stage -le 9 ]; then
  # Get the alignments as lattices (gives the LF-MMI training more freedom).
  # use the same num-jobs as the alignments
  if ! ${use_origanl}; then
      steps/nnet3/align_lats.sh --nj $nj --cmd "$train_cmd"  --scale-opts '--transition-scale=1.0 --self-loop-scale=1.0' \
      --acoustic_scale 1.0 --generate_ali_from_lats true $ali_feats $lang $ali_model_dir $ali_dir

      rm ${ali_dir}/fsts.*.gz # save space
  else
      steps/copy_lat_dir.sh --cmd "$train_cmd" --nj $nj --prefixes $prefixes_aug $ali_feats \
      ${origanl_lat_dir} ${ali_dir}
      steps/copy_ali_dir.sh --cmd "$train_cmd" --nj $nj --prefixes $prefixes_aug $ali_feats \
      ${origanl_lat_dir} ${ali_dir}
  fi
fi


if [ $stage -le 10 ]; then
  # Create a version of the lang/ directory that has one state per phone in the
  # topo file. [note, it really has two states.. the first one is only repeated
  # once, the second one has zero or more repeats.]
  rm -rf $lang_new
  mkdir $lang_new
  cp -r ${lang}/* $lang_new
  silphonelist=$(cat $lang_new/phones/silence.csl) || exit 1;
  nonsilphonelist=$(cat $lang_new/phones/nonsilence.csl) || exit 1;
  # Use our special topology... note that later on may have to tune this
  # topology.
  steps/nnet3/chain/gen_topo.py $nonsilphonelist $silphonelist >$lang_new/topo
fi


if [ $stage -le 11 ]; then
  # Build a tree using our new topology. This is the critically different
  # step compared with other recipes.
  steps/nnet3/chain/build_tree.sh --frame-subsampling-factor $frame_subsampling_factor \
      --alignment-subsampling-factor $alignment_subsampling_factor \
      --leftmost-questions-truncate $leftmost_questions_truncate \
      --context-opts "--context-width=2 --central-position=1" \
      --cmd "$train_cmd" 7000 $train_feats $lang_new $ali_dir $tree_dir
fi


if [ $stage -le 12 ]; then
  echo "$0: creating neural net configs using the xconfig parser";
  num_targets=$(tree-info $tree_dir/tree |grep num-pdfs|awk '{print $2}')
  learning_rate_factor=$(echo "print 0.5/$xent_regularize" | python)

  mkdir -p $dir/configs
  cat <<EOF > $dir/configs/network.xconfig
  input dim=40 name=input

  # please note that it is important to have input layer with the name=input
  # as the layer immediately preceding the fixed-affine-layer to enable
  # the use of short notation for the descriptor
  fixed-affine-layer name=lda input=Append(-1,0,1,0) affine-transform-file=$dir/configs/lda.mat

  # the first splicing is moved before the lda layer, so no splicing here
  relu-batchnorm-layer name=tdnn1 dim=625
  relu-batchnorm-layer name=tdnn2 input=Append(-1,0,1) dim=625
  relu-batchnorm-layer name=tdnn3 input=Append(-1,0,1) dim=625
  relu-batchnorm-layer name=tdnn4 input=Append(-3,0,3) dim=625
  relu-batchnorm-layer name=tdnn5 input=Append(-3,0,3) dim=625
  relu-batchnorm-layer name=tdnn6 input=Append(-3,0,3) dim=625
  attention-relu-renorm-layer name=attention1 num-heads=15 value-dim=80 key-dim=40 num-left-inputs=5 num-right-inputs=2 time-stride=3

  ## adding the layers for chain branch
  relu-batchnorm-layer name=prefinal-chain input=attention1 dim=625 target-rms=0.5
  output-layer name=output include-log-softmax=false dim=$num_targets max-change=1.5

  # adding the layers for xent branch
  # This block prints the configs for a separate output that will be
  # trained with a cross-entropy objective in the 'chain' models... this
  # has the effect of regularizing the hidden parts of the model.  we use
  # 0.5 / args.xent_regularize as the learning rate factor- the factor of
  # 0.5 / args.xent_regularize is suitable as it means the xent
  # final-layer learns at a rate independent of the regularization
  # constant; and the 0.5 was tuned so as to make the relative progress
  # similar in the xent and regular final layers.
  relu-batchnorm-layer name=prefinal-xent input=attention1 dim=625 target-rms=0.5
  output-layer name=output-xent dim=$num_targets learning-rate-factor=$learning_rate_factor max-change=1.5

EOF
  steps/nnet3/xconfig_to_configs.py --xconfig-file $dir/configs/network.xconfig --config-dir $dir/configs/

fi


if [ $stage -le 13 ]; then
  steps/nnet3/chain/train.py --stage $train_stage \
    --cmd "$decode_cmd" \
    --use-gpu wait \
    --feat.cmvn-opts "--norm-means=false --norm-vars=false" \
    --chain.xent-regularize $xent_regularize \
    --chain.leaky-hmm-coefficient 0.1 \
    --chain.l2-regularize 0.00005 \
    --chain.apply-deriv-weights false \
    --chain.lm-opts="--num-extra-lm-states=2000" \
    --egs.dir "$common_egs_dir" \
    --egs.stage $get_egs_stage \
    --egs.opts "--frames-overlap-per-eg 0" \
    --egs.chunk-width $frames_per_eg \
    --trainer.num-chunk-per-minibatch $minibatch_size \
    --trainer.frames-per-iter 1500000 \
    --trainer.num-epochs $num_epochs \
    --trainer.optimization.num-jobs-initial $num_jobs_initial \
    --trainer.optimization.num-jobs-final $num_jobs_final \
    --trainer.optimization.initial-effective-lrate $initial_effective_lrate \
    --trainer.optimization.final-effective-lrate $final_effective_lrate \
    --trainer.max-param-change $max_param_change \
    --chain.frame-subsampling-factor ${frame_subsampling_factor} \
    --chain.alignment-subsampling-factor ${alignment_subsampling_factor} \
    --cleanup.remove-egs $remove_egs \
    --feat-dir ${train_feats} \
    --tree-dir $tree_dir \
    --lat-dir $lat_dir \
    --dir $dir  || exit 1;

fi

echo "Done";
exit 0;





