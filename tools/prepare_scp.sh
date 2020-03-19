#!/bin/bash
# coding:utf-8

wavPath=$1
realPath=`realpath $wavPath`

[[ -f $realPath"/temp" ]] && rm $realPath"/temp" 2>/dev/null
[[ -f $realPath"/wav.scp" ]] && rm $realPath"/wav.scp" 2>/dev/null
[[ -f $realPath"/spk2utt" ]] && rm $realPath"/spk2utt" 2>/dev/null
[[ -f $realPath"/utt2spk" ]] && rm $realPath"/utt2spk" 2>/dev/null

for wav in `ls $realPath`
do
	if [[ $wav == *"wav" ]]
	then
		wavName=`echo $wav | cut -d '.' -f 1`
		echo $wavName >> $realPath"/temp"
	fi
done

export LC_ALL=C
sort $realPath"/temp" > $realPath"/temp1"
export LC_ALL=

for line in `cat $realPath"/temp1"`
do
	echo -e $line"\t"$realPath"/"$line".wav" >> $realPath"/wav.scp"
done

paste -d " " $realPath"/temp" $realPath"/temp" > $realPath"/spk2utt"
cp $realPath"/spk2utt" $realPath"/utt2spk"

cd /home1/gongxingwei/chain_base/ext_feats/ && sh ext_fbank.sh $realPath
cd -
exit 0
