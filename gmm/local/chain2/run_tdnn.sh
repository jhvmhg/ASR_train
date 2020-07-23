#!/usr/bin/env bash


# Set -e here so that we catch if any executable fails immediately
set -euo pipefail

# First the options that are passed through to run_ivector_common.sh
# (some of which are also used in this script directly).

nj=24
stage=0


# The rest are configs specific to this script.  Most of the parameters
# are just hardcoded at this level, in the commands below.

train_stage=-10
get_egs_stage=-10
num_jobs_initial=1
num_jobs_final=4


# training options
# training chunk-options
chunk_width=140,100,160
xent_regularize=0.1
bottom_subsampling_factor=1  # I'll set this to 3 later, 1 is for compatibility with a broken ru.
frame_subsampling_factor=3
langs="default"  # list of language names

# The amount of extra left/right context we put in the egs.  Note: this could
# easily be zero, since we're not using a recurrent topology, but we put in a
# little extra context so that we have more room to play with the configuration
# without re-dumping egs.
egs_extra_left_context=5
egs_extra_right_context=5

# The number of chunks (of length: see $chunk_width above) that we group
# together for each "speaker" (actually: pseudo-speaker, since we may have
# to group multiple speaker together in some cases).
chunks_per_group=4

# training options
srand=0
remove_egs=true
reporting_email=

frame_subsampling_factor=3
alignment_subsampling_factor=3

# data path
ali_model_dir=exp/chain/tdnn_attend
ali_feats=../train_fbank_combine_fake
ali_dir=../lats/chain2_lats
lat_dir=

train_feats=../train_fbank_combine

tree_dir=exp/chain/chain_tree_again
lang=data/lang
lang_new=data/lang_chain


# End configuration section.
echo "$0 $@"  # Print the command line for logging

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

if ! cuda-compiled; then
  cat <<EOF && exit 1
This script is intended to be used with GPUs but you have not compiled Kaldi with CUDA
If you want to use GPUs (and have them), go to src/, and configure and make on a machine
where "nvcc" is installed.
EOF
fi


if [ -z $lat_dir ]; then
  lat_dir=$ali_dir
fi

dir=$1



if [ $stage -le 9 ]; then
  # Get the alignments as lattices (gives the chain training more freedom).
  # use the same num-jobs as the alignments
    steps/nnet3/align_lats.sh --nj $nj --cmd "$train_cmd"  --scale-opts '--transition-scale=1.0 --self-loop-scale=1.0' \
      --acoustic_scale 1.0 --generate_ali_from_lats true $ali_feats $lang $ali_model_dir $lat_dir

      rm ${ali_dir}/fsts.*.gz # save space
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
      --context-opts "--context-width=2 --central-position=1" \
      --cmd "$train_cmd" 7000 $train_feats $lang_new $ali_dir $tree_dir
fi




# $dir/configs will contain xconfig and config files for the initial
# models.  It's a scratch space used by this script but not by
# scripts called from here.
mkdir -p $dir/configs/
# $dir/init will contain the initial models
mkdir -p $dir/init/

learning_rate_factor=$(echo "print (0.5/$xent_regularize)" | python)

if [ $stage -le 14 ]; then

  # Note: we'll use --bottom-subsampling-factor=3, so all time-strides for the
  # top network should be interpreted at the 30ms frame subsampling rate.
  num_leaves=$(tree-info $tree_dir/tree |grep num-pdfs|awk '{print $2}')

  echo "$0: creating top model"
  cat <<EOF > $dir/configs/default.xconfig
  input dim=100 name=ivector
  input dim=40 name=input

  # please note that it is important to have input layer with the name=input
  # as the layer immediately preceding the fixed-affine-layer to enable
  # the use of short notation for the descriptor
  fixed-affine-layer name=lda input=Append(-2,-1,0,1,2,ReplaceIndex(ivector, t, 0)) affine-transform-file=$dir/configs/lda.mat

  # the first splicing is moved before the lda layer, so no splicing here
  relu-renorm-layer name=tdnn1 dim=512
  relu-renorm-layer name=tdnn2 dim=512 input=Append(-1,0,1)
  relu-renorm-layer name=tdnn3 dim=512 input=Append(-1,0,1)
  relu-renorm-layer name=tdnn4 dim=512 input=Append(-3,0,3)
  relu-renorm-layer name=tdnn5 dim=512 input=Append(-3,0,3)
  relu-renorm-layer name=tdnn6 dim=512 input=Append(-6,-3,0)
  relu-renorm-layer name=prefinal-chain dim=512 target-rms=0.5
  output-layer name=output include-log-softmax=false dim=$num_leaves max-change=1.5
  output-layer name=output-default input=prefinal-chain include-log-softmax=false dim=$num_leaves max-change=1.5
  relu-renorm-layer name=prefinal-xent input=tdnn6 dim=512 target-rms=0.5
  output-layer name=output-xent dim=$num_leaves learning-rate-factor=$learning_rate_factor max-change=1.5
  output-layer name=output-default-xent input=prefinal-xent dim=$num_leaves learning-rate-factor=$learning_rate_factor max-change=1.5
EOF
  steps/nnet3/xconfig_to_configs.py --xconfig-file $dir/configs/default.xconfig --config-dir $dir/configs/
  if [ $dir/init/default_trans.mdl ]; then # checking this because it may have been copied in a previous run of the same script
      copy-transition-model $tree_dir/final.mdl $dir/init/default_trans.mdl  || exit 1 &
  else
      echo "Keeping the old $dir/init/default_trans.mdl as it already exists."
  fi
fi
wait;

init_info=$dir/init/info.txt
if [ $stage -le 15 ]; then

  if [ ! -f $dir/configs/ref.raw ]; then
      echo "Expected $dir/configs/ref.raw to exist"
      exit
  fi

  nnet3-info $dir/configs/ref.raw  > $dir/configs/temp.info
  model_left_context=`fgrep 'left-context' $dir/configs/temp.info | awk '{print $2}'`
  model_right_context=`fgrep 'right-context' $dir/configs/temp.info | awk '{print $2}'`
  cat >$init_info <<EOF
frame_subsampling_factor $frame_subsampling_factor
langs $langs
model_left_context $model_left_context
model_right_context $model_right_context
EOF
  rm $dir/configs/temp.info
fi

# Make phone LM and denominator and normalization FST
if [ $stage -le 16 ]; then
  echo "$0: Making Phone LM and denominator and normalization FST"
  mkdir -p $dir/den_fsts/log

  # We may later reorganize this.
  cp $tree_dir/tree $dir/default.tree

  echo "$0: creating phone language-model"
  $train_cmd $dir/den_fsts/log/make_phone_lm_default.log \
    chain-est-phone-lm --num-extra-lm-states=2000 \
       "ark:gunzip -c $ali_dir/ali.*.gz | ali-to-phones $ali_dir/final.mdl ark:- ark:- |" \
       $dir/den_fsts/default.phone_lm.fst

  echo "$0: creating denominator FST"
  $train_cmd $dir/den_fsts/log/make_den_fst.log \
     chain-make-den-fst $dir/default.tree $dir/init/default_trans.mdl $dir/den_fsts/default.phone_lm.fst \
     $dir/den_fsts/default.den.fst $dir/den_fsts/default.normalization.fst || exit 1;
fi

model_left_context=$(awk '/^model_left_context/ {print $2;}' $dir/init/info.txt)
model_right_context=$(awk '/^model_right_context/ {print $2;}' $dir/init/info.txt)
if [ -z $model_left_context ]; then
    echo "ERROR: Cannot find entry for model_left_context in $dir/init/info.txt"
fi
if [ -z $model_right_context ]; then
    echo "ERROR: Cannot find entry for model_right_context in $dir/init/info.txt"
fi
# Note: we add frame_subsampling_factor/2 so that we can support the frame
# shifting that's done during training, so if frame-subsampling-factor=3, we
# train on the same egs with the input shifted by -1,0,1 frames.  This is done
# via the --frame-shift option to nnet3-chain-copy-egs in the script.
egs_left_context=$[model_left_context+(frame_subsampling_factor/2)+egs_extra_left_context]
egs_right_context=$[model_right_context+(frame_subsampling_factor/2)+egs_extra_right_context]



if [ $stage -le 17 ]; then
  echo "$0: about to dump raw egs."
  # Dump raw egs.
  steps/chain2/get_raw_egs.sh --cmd "$train_cmd" \
    --lang "default" \
    --cmvn-opts "--norm-means=false --norm-vars=false" \
    --left-context $egs_left_context \
    --right-context $egs_right_context \
    --frame-subsampling-factor $frame_subsampling_factor \
    --alignment-subsampling-factor $frame_subsampling_factor \
    --frames-per-chunk ${chunk_width} \
    ${train_feats} ${dir} ${lat_dir} ${dir}/raw_egs
fi

if [ $stage -le 18 ]; then
  echo "$0: about to process egs"
  steps/chain2/process_egs.sh  --cmd "$train_cmd" \
      --num-repeats 1 \
    ${dir}/raw_egs ${dir}/processed_egs
fi

if [ $stage -le 19 ]; then
  echo "$0: about to randomize egs"
  steps/chain2/randomize_egs.sh --frames-per-job 3000000 \
    ${dir}/processed_egs ${dir}/egs
fi

if [ $stage -le 20 ]; then
    echo "$0: Training pre-conditioning matrix"
    num_lda_jobs=`find ${dir}/egs/ -iname 'train.*.scp' | wc -l | cut -d ' ' -f2`
    steps/chain2/compute_preconditioning_matrix.sh --cmd "$train_cmd" \
        --nj $num_lda_jobs \
        $dir/configs/init.raw \
        $dir/egs \
        $dir || exit 1
fi

if [ $stage -le 21 ]; then
    echo "$0: Preparing initial acoustic model"
    if [ -f $dir/configs/init.config ]; then
            $train_cmd ${dir}/log/add_first_layer.log \
                    nnet3-init --srand=${srand} ${dir}/configs/init.raw \
                    ${dir}/configs/final.config ${dir}/init/default.raw || exit 1
    else
            $train_cmd ${dir}/log/init_model.log \
               nnet3-init --srand=${srand} ${dir}/configs/final.config ${dir}/init/default.raw || exit 1
    fi

    $train_cmd $dir/log/init_mdl.log \
        nnet3-am-init ${dir}/init/default_trans.mdl $dir/init/default.raw $dir/init/default.mdl || exit 1
fi

if [ $stage -le 22 ]; then
  echo "$0: about to train model"
  steps/chain2/train.sh \
    --stage $train_stage --cmd "$cuda_cmd" \
    --xent-regularize $xent_regularize --leaky-hmm-coefficient 0.1 \
    --max-param-change 2.0 \
    --num-jobs-initial $num_jobs_initial \
    --num-jobs-final $num_jobs_final \
    --groups-per-minibatch 256,128,64 \
     $dir/egs $dir || exit 1;
fi


exit 0;


