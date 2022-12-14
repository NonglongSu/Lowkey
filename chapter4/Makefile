#!/bin/bash
#usage: make gill100 target=k3 omega_l=3
####### make gsam100 target=k3 omega_l=3
####### make gimp100 target=k3 omega_l=3
default:all
all:

.PHONY: para_space gill100 gsam100 rm_gap gimp100 plot_trueVsSim plot_sim plot_im plot_simVsIm

################################################
RSCRIPT=Rscript --vanilla
RM=rm -i

#path
SCR=../Script/chapter4

len        := 999
sim_size   := 500
sample_size:= 100
omega_z    := 0
omega_l    ?= 12  #12 is default
target     ?= k12

#################################################100 simulations
#Pick a parameter space (100)
para_space:$(SCR)/para_space_wz.R
	$(RSCRIPT) $<

nameL  := $(shell test -f index.txt && cat index.txt)
gill100:  $(patsubst %, $(target)/Gs/%, $(nameL))
gsam100:  $(patsubst %, $(target)/Results/Gse/%.est.json, $(nameL))
gimp100:  $(patsubst %, $(target)/Results/Pise/%.est.json,$(nameL))
Gs:          gill100
Results/Gse: gsam100
Results/Pise:gimp100


#100 gillespie simulations
$(target)/Gs/%: $(SCR)/haha_gillespie100_wz.R trueP.100.txt
	$(RSCRIPT) $< $@ $(word 2,$^) $(len) $(omega_z) $(sim_size) $(omega_l)

#100 gillespie simu estimates
$(target)/Results/Gse/%.est.json: $(SCR)/gillespie_sim_est_wz.R $(target)/Gs/%
	$(RSCRIPT) $< $(word 2,$^) $@ $(omega_l)

#generate original seqs
rm_gap:runbash100.sh
	bash $< 100 500 k12

#100/10k
$(target)/Results/Pise/%.est.json: $(SCR)/phase_im_sampling_wz.R $(target)/Gs_trim/% $(target)/JsonD/%/
	$(RSCRIPT) $< $(word 2,$^) $(word 3,$^) $@ $(sample_size) $(omega_l)


#################################
#plot the true vs sim and vs im estimates
plot_sim: $(SCR)/plot_trueVsSim.R
	$(RSCRIPT) $< $(target) 1

plot_im: $(SCR)/plot_trueVsSim.R
	$(RSCRIPT) $< $(target) 0

#plot the sim vs im estimates, and sum stats
plot_simVsIm: $(SCR)/plot_trueVsSim.R
	$(RSCRIPT) $< $(target) 16



####################################
#compare wz with omegaz
