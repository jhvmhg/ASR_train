#!/bin/bash

. ./cmd.sh

# Usage:sh wav_aug_common.sh --aug-list "speed reverb" --srcdir wav/noise/
# Note:此脚本默认做babble和music增强时使用的是背景噪音，做noise时使用的是前景噪音，如需改变，需修改此脚本

set -e
aug_list="reverb music noise babble"
num_reverb_copies=1
sample_rate=16000
dump_wavs=false

SHELL_FOLDER=$(dirname $(readlink -f "$0"))
musan_path=$SHELL_FOLDER/musan
rirs_noises_path=$SHELL_FOLDER/RIRS_NOISES

srcdir=datasrc

. ./path.sh
. ./utils/parse_options.sh

augs=($aug_list)
augs_available=(reverb music noise babble volume speed)

srcdir=${srcdir%*/}
if [ ! -f $srcdir/wav.scp ]; then
    echo "Cannot find wav.scp, exit!"
    exit 1
fi

function contains() {
    local n=$#
    local value=${!n}
    for ((i=1;i < $#;i++)) {
        if [ "${!i}" == "${value}" ]; then
            echo "y"
            return 0
        fi
    }
    echo "n"
    return 1
}

function dump_files() {
    local param=$1
    mkdir -p ${srcdir}_${param}/wav
    cat ${srcdir}_${param}/wav.scp | local/dump_wavs.py ${srcdir}_${param} >/dev/null 2>&1 &
    echo "Wait for a few minutes, the new wavs are dumping to disk!"
}
    

for param in ${augs[*]};
do
    if [ $(contains "${augs_available[@]}" $param) == "n" ]; then
        echo "Illegal data augmentation param:"$param"! Check it!"
        exit 1
    fi
done

make_musan_done=false

for param in ${augs[*]};
do
    case "$param" in
        reverb)    
            # Adding simulated RIRs to the original data directory
            echo "$0: Preparing ${srcdir}_reverb directory"

            if [ ! -d "$rirs_noises_path" ]; then
                # Download the package that includes the real RIRs, simulated RIRs, isotropic noises and point-source noises
                wget --no-check-certificate http://www.openslr.org/resources/28/rirs_noises.zip
                unzip rirs_noises.zip
            fi
            
            rirs_noises=`realpath RIRS_NOISES`

            if [ ! -f $srcdir/reco2dur ]; then
                utils/data/get_reco2dur.sh --nj 16 --cmd "$train_cmd" $srcdir || exit 1;
            fi

            # Make a version with reverberated speech
            rvb_opts=()
            rvb_opts+=(--rir-set-parameters "0.5, "$rirs_noises"/simulated_rirs/smallroom/rir_list")
            rvb_opts+=(--rir-set-parameters "0.5, "$rirs_noises"/simulated_rirs/mediumroom/rir_list")

            # Make a reverberated version of the SWBD train_nodup.
            # Note that we don't add any additive noise here.
            steps/data/reverberate_data_dir.py \
                "${rvb_opts[@]}" \
                --speech-rvb-probability 1 \
                --prefix "reverb" \
                --pointsource-noise-addition-probability 0 \
                --isotropic-noise-addition-probability 0 \
                --num-replications $num_reverb_copies \
                --source-sampling-rate $sample_rate \
                $srcdir ${srcdir}_reverb
            if $dump_wavs; then
                dump_files $param
            fi
            ;;
        babble|music|noise)
            if ! $make_musan_done; then
                # Prepare the MUSAN corpus, which consists of music, speech, and noise
                # We will use them as additive noises for data augmentation.
               steps/data/make_musan.sh --sampling-rate $sample_rate --use-vocals "true" \
                   $musan_path musan/tmp
               make_musan_done=true
            fi
            case "$param" in
                babble)
                    steps/data/augment_data_dir.py --utt-prefix "babble" --modify-spk-id "true" \
                        --bg-snrs "20:17:15:13" --num-bg-noises "3:4:5:6:7" \
                        --bg-noise-dir "musan/tmp/musan_speech" \
                        ${srcdir} ${srcdir}_babble
                    if $dump_wavs; then
                        dump_files $param
                    fi
                    ;;
                music)
                    steps/data/augment_data_dir.py --utt-prefix "music" --modify-spk-id "true" \
                        --bg-snrs "15:10:8:5" --num-bg-noises "1" --bg-noise-dir "musan/tmp/musan_music" \
                        ${srcdir} ${srcdir}_music
                    if $dump_wavs; then
                        dump_files $param
                    fi
                    ;;
                noise)
                    steps/data/augment_data_dir.py --utt-prefix "noise" --modify-spk-id "true" \
                        --fg-interval 1 --fg-snrs "15:10:5:0" --fg-noise-dir "musan/tmp/musan_noise" \
                        ${srcdir} ${srcdir}_noise
                    if $dump_wavs; then
                        dump_files $param
                    fi
                    ;;
            esac
            ;;
        volume)
            local/perturb_data_dir_volume.sh --scale_low 0.3 --scale_high 1.2 ${srcdir} ${srcdir}_volume
            if $dump_wavs; then
                dump_files $param
            fi
            ;;
        speed)
            utils/data/perturb_data_dir_speed_3way.sh --always-include-prefix true ${srcdir} ${srcdir}_speed
            if $dump_wavs; then
                dump_files $param
            fi
            ;;
    esac
done


