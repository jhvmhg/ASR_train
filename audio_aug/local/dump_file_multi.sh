#!/usr/bin/env bash

nj=12
cmd=run.pl



echo "$0 $@"  # Print the command line for logging.

if [ -f path.sh ]; then . ./path.sh; fi
. parse_options.sh || exit 1;


srcdir=$1
scp=${srcdir}/wav.scp

if [ $# -ge 2 ]; then
  logdir=$2
else
  logdir=${srcdir}/log
fi

mkdir -p $logdir || exit 1;
mkdir -p ${srcdir}/wav || exit 1;

name=`basename $srcdir`
# End configuration section.

split_scps=
for n in $(seq $nj); do
  split_scps="$split_scps $logdir/wav_${name}.$n.scp"
done


utils/split_scp.pl $scp $split_scps || exit 1;


for n in $(seq $nj); do
    cat $logdir/wav_${name}.$n.scp | local/dump_wavs.py ${srcdir} >/dev/null 2>&1 &
done

echo "Wait for a few minutes, the new wavs are dumping to disk!"

