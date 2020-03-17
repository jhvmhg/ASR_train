TMP_PATH:=$(addsuffix :`pwd`, $(PATH))
export PATH=$(TMP_PATH)

DATA=`pwd`/data
TRAIN=$(DATA)/train
DEV=$(DATA)/cv

AM_DIR=exp/chain/tdnn_attend
LM=/home1/meichaoyang/Workspace/wake_up/corpus.lm

prepare_lang:
	utils/prepare_lang.sh --position-dependent-phones false $(DATA)/dict "SPOKEN_NOISE" $(DATA)/local/lang $(DATA)/lang
gmm:
	local/train_gmm.sh $(TRAIN) $(DEV)
chain:
	local/train_chain.sh $(AM_DIR)
make_graph:
	local/make_graph.sh $(LM) $(DATA)/lang $(AM_DIR) $(DATA)/dict
