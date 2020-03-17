#!/bin/bash

. ./cmd.sh ## You'll want to change cmd.sh to something that will work on your system.
           ## This relates to the queue.
. ./path.sh

lm=$1
lang_dir=$2
am_dir=$3
lexicon=$4/lexicon.txt

stage=1


if [ $stage -le 1 ]; then
  gzip -c $lm > $lang_dir/lm.gz || exit 1;
  utils/format_lm.sh $lang_dir $lang_dir/lm.gz $lexicon $lang_dir || exit 1
fi


if [ $stage -le 2 ]; then
  # Note: it might appear that this $lang directory is mismatched, and it is as
  # far as the 'topo' is concerned, but this script doesn't read the 'topo' from
  # the lang directory.
  utils/mkgraph.sh --self-loop-scale 1.0 $lang_dir $am_dir $am_dir/graph
fi

echo "Done";
exit 0;
