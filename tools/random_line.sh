#运行 sh random_line.sh wavin 1 wavout
#三个参数为 输入文档名 比例(例子中为1%) 输出文档名

export LC_ALL=C

intxt=$1
rate=$2
outtxt=$3

total=`sed -n '$=' $intxt`
echo $total

t1=$((rate*total/100))
echo $t1

shuf -n $t1 $intxt > tmptxt
sort tmptxt > $outtxt
rm tmptxt
