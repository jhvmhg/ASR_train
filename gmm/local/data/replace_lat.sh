cmd=run.pl
nj=4
src_id=4
stage=1
temp_dir=
acoustic_scale='1.0'

[[ -f path.sh ]] && . ./path.sh
. parse_options.sh || exit 1

data=$1
dest=$2


if [ $stage -le 1 ]; then
    mkdir -p $dest || exit 1
    temp_dir=$(mktemp -d $dest/temp.XXXXXX) || exit

    $cmd JOB=1:$src_id $dest/log/generate_lat_scp.JOB.log \
        lattice-copy \
        "ark:gunzip -c $data/lat.JOB.gz |" "ark,scp:$temp_dir/lat.JOB.ark,$temp_dir/lat.JOB.scp"
fi

#generate new lattice scp from lat.*scp ,then contiune
# python3
#lat_scp = parse_file_to_dict("lats/train_fbank_lat_replace_test/temp.gzGkzG/lat.all.scp")
#for i in range(1,5):
#    lat_scp_2 = parse_file_to_dict("lats/train_fbank_lat_replace_test/temp.gzGkzG/lat."+str(i)+".scp")
#    lat_scp_new={}
#    for utt in lat_scp_2:
#        a = utt.split("-",1)
#        if len(a) == 2:
#            prefix = a[0]
#            utt_ori = a[1]
#        else:
#            prefix = ""
#            utt_ori = a[0]
#        if "sp" in prefix:
#            lat_scp_new[utt]=lat_scp[utt]
#        else:
#            lat_scp_new[utt] = lat_scp[utt_ori]
#
#    write_dict_to_file(lat_scp_new,"lats/train_fbank_lat_replace_test/temp.gzGkzG/lat."+str(i)+".new.scp")

if [ $stage -le 2 ]; then
    $cmd JOB=1:$src_id $dest/log/generate_new_lat_ark.JOB.log \
        lattice-copy \
          "scp:$temp_dir/lat.JOB.new.scp" \
          "ark:| gzip -c > $dest/lat.JOB.gz" || exit 1

fi

if [ $stage -le 3 ]; then
  # If generate_alignments is true, ali.*.gz is generated in lats dir
    $cmd JOB=1:$src_id $dir/log/generate_alignments.JOB.log \
        lattice-best-path --acoustic-scale=$acoustic_scale "ark:gunzip -c $dest/lat.JOB.gz |" \
        ark:/dev/null "ark:|gzip -c >$dest/ali.JOB.gz" || exit 1;
fi