
dir=$1

python lib/trans_wav.py $dir $dir/16k

cd ext_feats && bash ext_fbank.sh $dir/16k && utils/fix_data_dir.sh $dir/16k

cd ../chain && bash decode.sh --nj 2 --stage 1 exp/combine_data_exp_no2/graph $dir/16k $dir/16k