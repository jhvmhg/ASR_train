from ltp import LTP

ltp = LTP()

seg, hidden = ltp.seg(["他叫汤姆去拿外衣。"])
ner = ltp.ner(hidden)
# [['他', '叫', '汤姆', '去', '拿', '外衣', '。']]
# [[('Nh', 2, 2)]]

tag, start, end = ner[0][0]
print(tag,":", "".join(seg[0][start:end + 1]))
# Nh : 汤姆