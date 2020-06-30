
stage=0

ori_fbank=/home1/meichaoyang/workspace/git/ASR_train/data/train_fank_ori
ori_lat=/home1/meichaoyang/workspace/git/ASR_train/train_ori_lat
aug_fbank=/home1/meichaoyang/workspace/git/ASR_train/data/train_fbank_ori_aug
aug_lat=/home1/meichaoyang/workspace/git/ASR_train/lats/train_ori_aug_lat
speed_fbank=/home1/meichaoyang/workspace/git/ASR_train/data/train_fbank_speed
speed_lat=/home1/meichaoyang/workspace/git/ASR_train/lats/train_speed_lat

combined_data=/home1/meichaoyang/workspace/git/ASR_train/data/combine_data
combined_lat=/home1/meichaoyang/workspace/git/ASR_train/lats/train_all_lat

echo "$0 $@"  # Print the command line for logging

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

if [ $stage -le 0 ]; then
    # combine all original data and alignment
    bash utils/data/combine_data.sh $ori_fbank /home1/meichaoyang/dataset/magic_aug/data /home1/meichaoyang/dataset/16k_filter /home1/meichaoyang/dataset/aishell_16k_mix/data

    bash steps/combine_lat_dirs.sh --cmd run.pl $ori_fbank $ori_lat /home1/meichaoyang/dataset/magic_aug/data_ali/ \
    /home1/meichaoyang/dataset/16k_filter_ali /home1/meichaoyang/dataset/aishell_16k_mix/data_ali
fi

if [ $stage -le 1 ]; then
    # combine all augmented data and generate augmented alignment
    bash utils/data/combine_data.sh $aug_fbank \
    /home1/meichaoyang/dataset/aishell_16k_mix/data_reverb /home1/meichaoyang/dataset/aishell_16k_mix/data_babble \
    /home1/meichaoyang/dataset/aishell_16k_mix/data_music /home1/meichaoyang/dataset/aishell_16k_mix/data_noise \
    /home1/meichaoyang/dataset/16k_filter_reverb  /home1/meichaoyang/dataset/16k_filter_babble \
    /home1/meichaoyang/dataset/16k_filter_music /home1/meichaoyang/dataset/16k_filter_noise \
    /home1/meichaoyang/dataset/magic_aug/data_reverb /home1/meichaoyang/dataset/magic_aug/data_noise

    bash steps/copy_lat_dir.sh --prefixes "reverb1 babble music noise" \
    --include-original true --cmd run.pl $aug_fbank $ori_lat $aug_lat
    bash steps/copy_ali_dir.sh --prefixes "reverb1 babble music noise" \
    --include-original true --cmd run.pl $aug_fbank $ori_lat $aug_lat
fi

if [ $stage -le 2 ]; then
    # combine all speed augmented data and generate speed augmented alignment
    bash utils/data/combine_data.sh $speed_fbank \
    /home1/meichaoyang/dataset/magic_aug/data_speed \
    /home1/meichaoyang/dataset/aishell_16k_mix/data_speed \
    /home1/meichaoyang/dataset/16k_filter_speed

    bash steps/combine_lat_dirs.sh --cmd run.pl $speed_fbank $speed_lat \
    /home1/meichaoyang/dataset/magic_aug/data_speed_ali \
    /home1/meichaoyang/dataset/aishell_16k_mix/data_speed_ali /home1/meichaoyang/dataset/16k_filter_speed_ali
fi

if [ $stage -le 3 ]; then
    # combine all data and alignment
    bash utils/data/combine_data.sh $combined_data \
    $ori_fbank $aug_fbank $speed_fbank

    bash steps/combine_lat_dirs.sh --cmd run.pl $combined_data \
    $combined_lat $aug_lat $speed_lat
fi