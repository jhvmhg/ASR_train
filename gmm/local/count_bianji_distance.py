#!/usr/bin/python3
# coding:utf-8

import sys
import re

shuzi = {'零':['0'], '一':['1'], '幺':['1'], '二':['2'], '三':['3'], '四':['4'], '五':['5'], '六':['6'], '七':['7'], '八':['8'], '九':['9'], '0':['零'], '1':['一','幺'], '2':['二'], '3':['三'], '4':['四'], '5':['五'], '6':['六'], '7':['七'], '8':['八'], '9':['九']}

class string_diff_analysis:
    _addcount = 0
    _subcount = 0
    _errcount = 0
    _samecount = 0
    _allcount = 0

    _cer = 0.0

    _srcstring = ''
    _dststring = ''
    _diffstring = ''

    _refcount = 0

    def __init__(self, srcstring, dststring):
        self._srcstring = srcstring
        self._dststring = dststring

        return

    def equals(self, char_a,char_b):
        if(str.lower(char_a) == str.lower(char_b)):
            return True

        if char_a in shuzi:
            if char_b in shuzi[char_a]:
                return True
        return False

    def lcsc(self, seqx, seqy):
        lenx = len(seqx)
        leny = len(seqy)

        table = [[[] for x in range(leny + 1)] for y in range(lenx + 1)]
        Matrix = [[0 for x in range(leny + 1)] for y in range(lenx + 1)]
        for tmp in range(0, lenx + 1):
            Matrix[tmp][0] = tmp
        for tmp in range(0, leny + 1):
            Matrix[0][tmp] = tmp

        Matrix[0][0] = 0

        for xline in range(1, lenx + 1):
            for yline in range(1, leny + 1):
                MinCost1 = Matrix[xline-1][yline] + 1
                MinCost2 = Matrix[xline][yline-1] + 1
                MinCost = min(MinCost1, MinCost2)

                if self.equals(seqx[xline-1],seqy[yline-1]):
                    ReplaceCost = 0
                else:
                    ReplaceCost = 1

                if ReplaceCost + Matrix[xline-1][yline-1] < MinCost:
                    MinCost = ReplaceCost + Matrix[xline-1][yline-1]
                    table[xline][yline].extend(table[xline-1][yline-1])
                    if ReplaceCost == 0:
                        table[xline][yline].append([xline-1, yline-1])
                elif MinCost2 ==  MinCost1:
                    if len(table[xline][yline-1]) >= len(table[xline-1][yline]):
                        table[xline][yline] = table[xline][yline-1]
                    else:
                        table[xline][yline] = table[xline-1][yline]
                elif MinCost2 <  MinCost1:
                    table[xline][yline] = table[xline][yline-1]
                else:
                    table[xline][yline] = table[xline-1][yline]

                Matrix[xline][yline] = MinCost

        seqcls = table[lenx][leny]
        seqcls.append([lenx, leny])
        return seqcls

    def calclate_diff_lcs2(self):

        srcparts = self._srcstring.split()
        dstparts = self._dststring.split()

        if len(dstparts) <= 0:
            self._subcount = len(srcparts)
            self._allcount = len(srcparts)
            if self._allcount == 0:
                self._cer = 0.0
                return 0
            self._cer = 1.0
            return 0

        lcsparts = self.lcsc(srcparts, dstparts)
        if len(lcsparts) == 0:
            self._errcount = len(dstparts)
            self._allcount = len(srcparts)
            self._cer = 1.0 * (self._errcount) / self._allcount
            return 0

        allcount = len(srcparts)
        samecount = 0

        diffparts = []

        addcount = 0
        subcount = 0
        errcount = 0

        srcindex = 0
        dstindex = 0
        lcsindex = 0

        while lcsindex < len(lcsparts):
            src = lcsparts[lcsindex][0]
            dst = lcsparts[lcsindex][1]
            while srcindex < src and dstindex < dst:
                diffparts.append('(')
                diffparts.append(srcparts[srcindex])
                diffparts.append(':')
                diffparts.append(dstparts[dstindex])
                diffparts.append(')')

                errcount = errcount + 1

                srcindex = srcindex + 1
                dstindex = dstindex + 1

            if srcindex < src:
                diffparts.append('[')
                while srcindex < src:
                    diffparts.append(srcparts[srcindex])

                    subcount = subcount + 1
                    srcindex = srcindex + 1
                diffparts.append(']')


            if dstindex < dst:
                diffparts.append('<')
                while dstindex < dst:
                    diffparts.append(dstparts[dstindex])

                    addcount = addcount + 1
                    dstindex = dstindex + 1
                diffparts.append('>')

            if lcsindex != len(lcsparts) - 1:
                diffparts.append(dstparts[dstindex])

                samecount = samecount + 1

                srcindex = srcindex + 1
                dstindex = dstindex + 1
            lcsindex = lcsindex + 1

        self._diffstring = ''
        for part in diffparts:
            self._diffstring = self._diffstring + ' ' + part

        try:
            cer = 1.0 * (addcount + subcount + errcount) / len(srcparts)
        except ZeroDivisionError:
            if addcount + subcount + errcount == 0:
                cer = 0.0
            else:
                cer = float('inf')

        self._cer = cer
        self._addcount = addcount
        self._subcount = subcount
        self._errcount = errcount

        self._allcount = allcount
        self._samecount = samecount
        if samecount != len(lcsparts) - 1:
            print ('error samecount is not equal lcsparts length')
            sys.exit()

            return 0

        return len(diffparts)


def process_text(text):
    data = {}
    with open(text, encoding="utf-8") as f:
        for line in f.readlines():
            line = line.strip()
            try:
                line_tag, line_content = line.split(maxsplit=1)
            except ValueError:
                line_tag = line
                line_content = ''
            if line_tag in data:
                print (text + "中含有重复的行标志：%s，请检查！" % (line_tag))
                sys.exit(1)
            data[line_tag] = line_content
    return data

def clean_line(line):
    result = ''
    index = 0
    line = re.sub('[^\u4E00-\u9FA5|0-9A-Za-z\s]', ' ', line)
    line = ' '.join(line)
    while index < len(line)-2:
        result = result + line[index]
        if re.match('[a-zA-Z]\s[a-zA-Z]', line[index:index+3]):
            index += 2
        else:
            index += 1
    result = result + line[index:]
    return re.sub('\s+', ' ', result)


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print ("Usage: python3 count_bianji_distance.py labeled_file recognized_file result_file")
        sys.exit(1)

    labeled_file = sys.argv[1]
    recognized_file = sys.argv[2]
    result_file = sys.argv[3]

    labeled_data = process_text(labeled_file)
    recognized_data = process_text(recognized_file)

    total_add, total_del, total_err, total_cost, total_len = 0, 0, 0, 0, 0
    err_sentence, total_sentence = 0, 0

    stats = {}
    for i in recognized_data:
        recognized_line = recognized_data[i]
        try:
            labeled_line = labeled_data[i]
        except KeyError:
            print ("Cannot find LINE:%s in labeled_file!" % (i))
            continue
        total_sentence += 1
        src_string = clean_line(labeled_line)
        dst_string = clean_line(recognized_line)
        string_diff = string_diff_analysis(src_string, dst_string)
        string_diff.calclate_diff_lcs2()
        more = string_diff._addcount
        less = string_diff._subcount
        err = string_diff._errcount
        cost = more + less + err
        try:
            err_rate = cost / len(src_string.split())
        except ZeroDivisionError:
            if cost == 0:
                err_rate = 0.0
            else:
                err_rate = float('inf')
        flag = string_diff._diffstring
        if err_rate != 0:
            err_sentence += 1
        err_show = "total: %d, add: %d, del: %d, err: %d, cer: %.4f%% " % (len(src_string.split()), more, less, err, err_rate*100)
        stats[i.strip()] = i.strip() + "\t" + labeled_line + "\n" + \
                           i.strip() + "\t" + recognized_line + "\n" + \
                           flag.strip() + "\n" + \
                           err_show + "\n\n"

        total_add += more
        total_del += less
        total_err += err
        total_cost += cost
        total_len += len(src_string.split())

    try:
        total_err_rate = total_cost / total_len * 100
    except ZeroDivisionError:
        if total_cost == 0:
            total_err_rate = 0.0
        else:
            total_err_rate = float('inf')
    try:
        toal_err_rate_exclude_add = (total_del + total_err) / total_len * 100
    except ZeroDivisionError:
        if total_del + total_err != 0:
            toal_err_rate_exclude_add = float('inf')
        else:
            toal_err_rate_exclude_add = 0.0
    final = "total: %d, add: %d, del: %d, err: %d, cer: %.4f%%, ser: %.2f%%, cer(exclude_add): %.4f%%" % (total_len, total_add, total_del, total_err, total_err_rate, err_sentence / total_sentence *100, toal_err_rate_exclude_add)
    print(final)

    with open(result_file, 'w', encoding="utf-8") as f:
        f.write('file:' + result_file + '\n\n')
        f.write("说明：[]——丢字，()——错字，<>——多字，cer——字错误率，ser——句错误率\n\t仅考虑标注文本中的中英字符及阿拉伯数字\n\n")
        f.write("=====================================\n")
        for i in sorted(stats.keys()):
            f.write(stats[i])
        f.write("=====================================\n")
        f.write("STAT：" + final + '\n')
