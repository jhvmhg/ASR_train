import sys

def main():
    lm_class_txt = sys.argv[1]
    print("2    3    #nonterm_begin <eps>")
    print("0    1    #nonterm_end <eps>")
    with open(lm_class_txt, 'r') as f:
        for line in f:
            words = line.split()
            prob = 0.69314718055994/len(words)
            for i in range(len(words)-1):
                print("{fro}    {t}    {wor}  {wor}    {pro}".format(fro=i+3,t=i+4,wor=words[i],pro=prob))
            print("{fro}    {t}    {wor}  {wor}    {pro}".format(fro=len(words)+2, t=0,wor=words[-1],pro=prob))
    print(1)

if __name__ == "__main__":
    main()