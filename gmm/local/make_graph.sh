#!/bin/bash

stage=1
graph_dir=
mkgraph_opt="--self-loop-scale 1.0" #chain model defalut
. ./cmd.sh ## You'll want to change cmd.sh to something that will work on your system.
           ## This relates to the queue.
. ./path.sh
. ./utils/parse_options.sh

lm=$1
lang_dir=$2
am_dir=$3
lexicon=$4

if [ -z $graph_dir ]; then
  graph_dir=$am_dir/graph
fi

if [ $# -ne 4 ]; then
  echo "Usage: $0 <arpa-LM> <lang_dir> <am_dir> <lexicon>"
  echo "E.g.: $0 trigramlm.arpa data/lang exp/aug_exp/tdnn_attend_noise data/dict/lexicon.txt"
  echo "main options (for others, see top of script file)"
  echo "  --graph_dir <graph-dir>                        # graph out dir,defalut $am_dir/graph"
  echo "  --mkgraph_opt                                  # option pass to utils/mkgraph.sh."
  echo "Generate HCLG.fst";
  exit 1;
fi

if [ $stage -le 1 ]; then
  gzip -c $lm > $lang_dir/lm.gz || exit 1;
  utils/format_lm.sh $lang_dir $lang_dir/lm.gz $lexicon $lang_dir || exit 1
fi


if [ $stage -le 2 ]; then
  # Note: it might appear that this $lang directory is mismatched, and it is as
  # far as the 'topo' is concerned, but this script doesn't read the 'topo' from
  # the lang directory.
  utils/mkgraph.sh $mkgraph_opt $lang_dir $am_dir $graph_dir
fi

echo "Done";
exit 0;




