suppressWarnings(suppressMessages(library(tidyverse)))
suppressPackageStartupMessages(library(stats))
suppressPackageStartupMessages(library(jsonlite))
suppressPackageStartupMessages(library(ggplot2))
suppressPackageStartupMessages(library(ggrepel))
suppressPackageStartupMessages(library(ggpubr))
suppressPackageStartupMessages(library(gridExtra))

#setwd("~/Dropbox (ASU)/Indel_project/chapter3")

#read file
readFile = function(inD, pat){
  Files= list.files(inD,pattern=pat,full.names=T)
  index = as.numeric(str_extract(basename(Files),'[^.]+')) #rectify the order
  Files = Files[order(index)]
  return(Files)
}

#without wz
doMat17 = function(Files,n){
  dMat = matrix(0,n,nvar)
  colnames(dMat)=c('A','C','G','T','s1','s2','s3','s4','s5','s6','omega','tau','ext.I','ext.D','r0*t', 'r1*t','r2*t')
  for (i in 1:n) {
    Jmp      = fromJSON(Files[i])
    go       = Jmp$gap.openning
    go.comb  = c(go[1]+go[4],go[2]+go[5],go[3]+go[6])
    rt       = -log(1-go.comb)
    ge       = Jmp$gap.extension
    dMat[i,] = c(Jmp$nuc.freq, Jmp$sigmas, Jmp$omega, Jmp$branch.length, ge, rt) 
  }
  return(dMat)
}

#with wz
doMat16 = function(Files,n){
  dMat  = matrix(0,n,nvar)
  colnames(dMat)=c('A','C','G','T','s1','s2','s3','s4','s5','s6','omega','tau','ext.I','ext.D','r*t','omegaZ')
  for (i in 1:n) {
    Jmp       = fromJSON(Files[i])
    g         = Jmp$gap.openning
    rt        = -log(1-2*g)/2
    ge        = Jmp$gap.extension
    dMat[i,]  = c(Jmp$nuc.freq, Jmp$sigmas, Jmp$omega, Jmp$branch.length, ge, rt, Jmp$omega.z) 
  }
  return(dMat)
}

####################################
readMatrix = function(inD){
  Files = readFile(inD,'est')
  n     = length(Files)
  
  if(nvar==17){
    res.mat = doMat17(Files,n)
  }else{
    res.mat = doMat16(Files,n)
  }
  return(res.mat)
}

plt_err = function(tM,dM,ouD){
  ouFig  = paste0(ouD,"/","error_distr.pdf")
  ouF    = paste0(ouD,"/","error_stat.csv")
  
  xm  = abs(dM-tM)/tM
  
  #generate a mean/var table
  xdf = data.frame(xm)
  vars= xdf %>% summarise_if(is.numeric,var) 
  avgs= colMeans(xm) 
  tb  = rbind(avgs,vars) %>% round(3)
  tb = apply(tb, 2, function(x){sprintf("%.3f",x)})
  rownames(tb) = c('u','s')
  write.csv(tb,ouF,row.names=T,quote=F)
  
  ##output figure
  pdf(ouFig,onefile=T,paper='a4',pointsize=18,width=8, height=15)
  Pdf = as.data.frame(as.table(xm))
  Pdf = Pdf %>% rename(Parameters=Var2, Error_percentage=Freq)
  g   = ggplot(Pdf, aes(x=Parameters,y=Error_percentage,color=Parameters)) + geom_violin() + xlab("") + ylab("Error Percentage") 
        
  gg  = g + geom_jitter(size=1,alpha=0.25,width=0.2) + stat_summary(fun=mean,geom='point',size=4) 
        #annotation_custom(tableGrob(tb,theme=ttheme_default(base_size=8)), xmin=-0.9,xmax=Inf,ymin=0.17,ymax=0.2) 
  
  gg2 = gg + scale_x_discrete(labels=para) + scale_color_hue(labels=para) 

  print(gg2)
  dev.off()
}

#############################################
#sim: num=1
#im:  num=0

#targ = "NULL"
#targ ='k12'


main = function(targ,num){
  n = as.numeric(num)
  
  #read true input
  inF  = "trueP.100.txt"
  tP   = read.table(inF,header=T)
  tMat = as.matrix(tP)
  nvar <<- ncol(tMat)
  
  para <<- c(bquote(sigma*1),bquote(sigma*2),bquote(sigma*3),bquote(sigma*4),bquote(sigma*5),bquote(sigma*6),
             bquote(omega),bquote(tau),expression('e'[i]),expression('e'[d]),'r0','r1','r2')
  
  #read simulated input
  if(targ!="NULL"){
    inD1 = paste0(targ,"/Results/Gse")
    inD2 = paste0(targ,"/Results/Pise")
    ouD1 = paste0(targ,"/Figure/500_sim")
    ouD2 = paste0(targ,"/Figure/500_im")
  }else{
    inD1 = "Results/Gse"
    inD2 = "Results/Pise"
    ouD1 = "Figure/500_sim"
    ouD2 = "Figure/500_im"
  }
  
  if(n==1){
    dMat    = readMatrix(inD1)
    plt_err(tMat[,5:nvar],dMat[,5:nvar],ouD1)
  }else{
    dMat    = readMatrix(inD2)
    plt_err(tMat[,5:nvar],dMat[,5:nvar],ouD2)
  }
  
}


###############################
args=commandArgs(trailingOnly=T)
main(args[1],args[2])