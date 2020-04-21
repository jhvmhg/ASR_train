#!/bin/bash

# Copyright 2012-2015  Johns Hopkins University (Author: Daniel Povey).
# Apache 2.0.

# This script does decoding with a neural-net.

# Begin configuration section.
stage=1
nj=1 # number of decoding jobs.
acwt=1.0  # Just a default value, used for adaptation and beam-pruning..
post_decode_acwt=10.0  # can be used in 'chain' systems to scale acoustics by 10 so the
                      # regular scoring script works.
cmd=run.pl
beam=9.0
frames_per_chunk=50
max_active=5000
min_active=200
lattice_beam=8.0 # Beam we use in lattice generation.
iter=final
num_threads=40 # if >1, will use gmm-latgen-faster-parallel
extra_left_context=0
extra_right_context=0
extra_left_context_initial=-1
extra_right_context_final=-1
minimize=false
# End configuration section.

echo "$0 $@"  # Print the command line for logging

. ./cmd.sh ## You'll want to change cmd.sh to something that will work on your system.
           ## This relates to the queue.
. ./path.sh
. utils/parse_options.sh || exit 1;

if [ $# -ne 3 ]; then
  echo "Usage: $0 [options] <graph-dir> <data-dir> <decode-dir>"
  echo "e.g.:   steps/nnet3/decode.sh --nj 8 \\"
  echo "    exp/tri4b/graph_bg data/test_eval92_hires $dir/decode_bg_eval92"
  echo "main options (for others, see top of script file)"
  echo "  --config <config-file>                   # config containing options"
  echo "  --nj <nj>                                # number of parallel jobs"
  echo "  --cmd <cmd>                              # Command to run in parallel with"
  echo "  --beam <beam>                            # Decoding beam; default 15.0"
  echo "  --iter <iter>                            # Iteration of model to decode; default is final."
  echo "  --num-threads <n>                        # number of threads to use, default 1."
  exit 1;
fi

graphdir=$1
data=$2
dir=$3
srcdir=`dirname $graphdir`; # Assume model directory one level up from decoding directory.
model=$srcdir/$iter.mdl

for f in $graphdir/HCLG.fst $graphdir/words.txt $data/feats.scp $data/utt2spk $model $srcdir/cmvn_opts; do
  [ ! -f $f ] && echo "$0: no such file $f" && exit 1;
done

sdata=$data/split$nj;
cmvn_opts=`cat $srcdir/cmvn_opts` || exit 1;
thread_string=
if [ $num_threads -gt 1 ]; then
  thread_string="-parallel --num-threads=$num_threads"
  queue_opt="--num-threads $num_threads"
fi

mkdir -p $dir/log
[[ -d $sdata && $data/feats.scp -ot $sdata ]] || split_data.sh $data $nj || exit 1;
echo $nj > $dir/num_jobs


## Set up features.
echo "$0: feature type is raw"

feats="ark,s,cs:apply-cmvn $cmvn_opts --utt2spk=ark:$sdata/JOB/utt2spk scp:$sdata/JOB/cmvn.scp scp:$sdata/JOB/feats.scp ark:- |"

#if [ "$post_decode_acwt" == 1.0 ]; then
#  lat_wspecifier="ark:|gzip -c >$dir/lat.JOB.gz"
#else
#  lat_wspecifier="ark:|lattice-scale --acoustic-scale=$post_decode_acwt ark:- ark:- | gzip -c >$dir/lat.JOB.gz"
#fi

frame_subsampling_opt=
if [ -f $srcdir/frame_subsampling_factor ]; then
  # e.g. for 'chain' systems
  frame_subsampling_opt="--frame-subsampling-factor=$(cat $srcdir/frame_subsampling_factor)"
fi

#lat_wspecifier="ark:>/dev/null"
lat_wspecifier="ark,t:|gzip -c > $dir/lat.JOB.gz"
words_wspecifier="ark,t:$dir/log/words.JOB.txt"
if [ $stage -le 1 ]; then
  $cmd $queue_opt JOB=1:$nj $dir/log/decode.JOB.log \
    nnet3-latgen-faster$thread_string $frame_subsampling_opt \
     --frames-per-chunk=$frames_per_chunk \
     --extra-left-context=$extra_left_context \
     --extra-right-context=$extra_right_context \
     --extra-left-context-initial=$extra_left_context_initial \
     --extra-right-context-final=$extra_right_context_final \
     --minimize=$minimize --max-active=$max_active --min-active=$min_active --beam=$beam \
     --lattice-beam=$lattice_beam --acoustic-scale=$acwt --allow-partial=true \
     --word-symbol-table=$graphdir/words.txt "$model" \
     $graphdir/HCLG.fst "$feats" "$lat_wspecifier" "$words_wspecifier" || exit 1;
fi

if [ $stage -le 2 ]; then
  if [ -f $dir/recognized.txt ]; then
    rm $dir/recognized.txt
  fi

  for((i=1;i<=$nj;i=i+1)); do
    utils/int2sym.pl -f 2- $graphdir/words.txt $dir/log/words.$i.txt >> $dir/recognized.txt;
  done
  if [ -f $data/text ]; then
    echo "start computing cer!";
    local/count_bianji_distance.py $data/text $dir/recognized.txt $dir/result.stat;
  fi
fi

echo "Decoding done."
exit 0;

