#Data analysis of 90 species 
suppressWarnings(library(matlib))
suppressPackageStartupMessages(library(Biostrings))
suppressPackageStartupMessages(library(stringr))
suppressPackageStartupMessages(library(seqinr))
suppressPackageStartupMessages(library(R.utils))
suppressPackageStartupMessages(library(plyr))
suppressPackageStartupMessages(library(Matrix))
suppressPackageStartupMessages(library(expm))
suppressPackageStartupMessages(library(SQUAREM))
suppressPackageStartupMessages(library(jsonlite))
suppressPackageStartupMessages(library(matlib))


#setwd("~/Dropbox (ASU)/Indel_project/Script/90")
#getwd()

#######################PARTI:func setup
#create 64*64 N->N matrix
countN = function(file){
  seq  = readDNAStringSet(file, format="fasta")
  seqs = str_split(seq,'') 
  
  #codon trans matrix  
  nmat = matrix(0,61,61)
  i=1
  while(i<width(seq)[1]) {
    c1 = paste0(seqs[[1]][i:(i+2)], collapse = '')
    c2 = paste0(seqs[[2]][i:(i+2)], collapse = '')
    coor1 = which(codonstrs %in% c1)
    coor2 = which(codonstrs %in% c2)
    nmat[coor1,coor2] = nmat[coor1,coor2] + 1
    i=i+3
  }
  
  print(sum(nmat)*3)
  return(nmat)
}

#4*4 GTR matrix
GTR = function(Si, pai){
  r1 = matrix(0, 4, 4)
  r1[lower.tri(r1)] = Si
  r  = r1 + t(r1)
  r  = t(r*pai)
  diag(r) = -rowSums(r)
  return(r)
}

#Construct a 61*61 MG94 matrix
MG94 = function(g, oga, cod){
  R  = matrix(0, 61, 61)
  for (i in 1:61) {
    for (j in 1:61) {
      if(i == j){
        R[i, j] = 0
      }else if(sum(cod[i, ] != cod[j, ]) > 1){#more than 1 nucleotide changes
        R[i, j] = 0
      }else{
        if(codonstrs[j] %in% syn[[codonstrs[i]]]){#syn_subs
          w = 1
        }else{#nonsyn_subs
          w = oga
        }
        pos = which(cod[i, ] != cod[j, ])
        x   = which(DNA_BASES == cod[i, pos])
        y   = which(DNA_BASES == cod[j, pos])
        R[i, j] = w * g[x, y]
      }
    }
  }
  diag(R) = -rowSums(R)
  
  return(R)
}

#Log-likelihood
LL = function(theta){
  rmat  = GTR(theta[1:6], f0)
  Rmat  = MG94(rmat, theta[7], cod)
  llt = sum(log(expm(Rmat)*cf0)*dat1)
  return(llt)
}

#EM 
em = function(p){
  s   = p[1:6]
  w   = p[7]
  r   = GTR(s, f0)
  R   = MG94(r, w, cod)
  #print(sum(R) %>% round(13))
  
  #Simulate branch length
  T1   = -sum(diag(r)*f0)          
  #print(T1)
  
  ##make r, R symmetric
  fmat = outer(sqrt(cf0), 1/sqrt(cf0))
  S    = R * fmat
  
  ##calculate eigenvectors and values.
  eig = eigen(S)
  D   = eig$values
  V   = eig$vectors
  
  ##calculate Prob(b|a)
  pab = V %*% diag(exp(D)) %*% t(V)           
  Pab = pab * t(fmat)
  #print(rowSums(Pab))
  
  
  ##Log likelihood "the smaller, the better"
  ll = sum(log(Pab*cf0)*dat1)
  cat(sprintf("%.6f\n", ll))
  
  
  
  ##construct the Jkl matrix       
  J = outer(D/T1, D/T1, function(x,y) {
    ifelse(x-y == 0,
           T1*exp(x*T1),
           exp(y*T1)*(expm1((x-y)*T1))/(x-y))
  })
  
  ##calculate the expected values
  # W[a,b,i,i] is the expected time spent state i on a branch going from a -> b
  # U[a,b,i,j] is the expected number of events going from i -> j on a branch going from a->b
  W = array(0, c(61,61,61,61))     
  U = array(0, c(61,61,61,61))
  
  tm = system.time(
    for(a in 1:61) {
      for(b in 1:61) {
        for(i in 1:61) {
          for(j in 1:61) {
            ff = sqrt(cf0[i]*cf0[b]/cf0[a]/cf0[j])
            o  = outer(V[a,]*V[i,], V[j,]*V[b,])   ##cheat: V[i,] = t(V)[,i]
            W[a,b,i,j] = ff * sum(o*J)
          }
        }
        W[a,b,,] = W[a,b,,] / Pab[a,b]
        U[a,b,,] = R * W[a,b,,]
      }
    }
  ) 
  
  ##calculate expected values by summing over observations --a,b is sumable. 
  Wh = array(0, c(61,61))
  Uh = array(0, c(61,61))
  for(i in 1:61) {
    for(j in 1:61) {
      Wh[i,j] = sum(W[,,i,j] * dat1)
      Uh[i,j] = sum(U[,,i,j] * dat1)
    }
  }
  Wh = diag(Wh)
  
  ##M-Step maximize sigmas.
  sigma.Cij = sapply(seq(6), function(x){sum(Uh[sigma.id[[x]]])})
  sigma.Wij = c()
  for (k in 1:6) {
    ichunks   = ceiling(sigma.id[[k]]/61)
    sigma.Wij = c(sigma.Wij, sum(Wh[ichunks]* t(R)[sigma.id[[k]]])/s[k])
  }
  s = sigma.Cij/sigma.Wij
  
  
  ##M-Step maximize omega
  w.Cij = sum(sapply(omega.id, function(x){Uh[x[1], x[2]]}))
  Rii   = c()
  for (i in 1:61) {
    ith.non = omega.id[which(sapply(omega.id, "[[", 1) == i)]
    ith.sum = sum(sapply(ith.non, function(x){R[x[1], x[2]]})) / w    
    Rii     = c(Rii, ith.sum)
  }
  w.Wij = sum(Wh * Rii)
  w     = w.Cij/w.Wij
  
  ##reconstruct gtr and mg94.
  pNew = c(s,w)
  print(pNew)
  return(pNew)
}

##########################################PARTII: main funcs
# inD    = "../../test_90_species/Raw_data/concat"

main = function(Name,inD){
  
  #stop codon position
  stp = c(49,51,57)
  
  #codon structure
  cod64 = cbind(rep(DNA_BASES, each = 16),
                rep(DNA_BASES, times = 4, each = 4),
                rep(DNA_BASES, 16))
  cod        = cod64[-stp,]
  codonstrs  = apply(cod, 1, stringr::str_c, collapse = "")            
  syn        = syncodons(codonstrs)
  names(syn) = toupper(names(syn))
  syn        = lapply(syn, toupper)
  
  #setup global
  cod <<- cod
  codonstrs <<- codonstrs
  syn <<- syn
  
  #Build omega list for M-step.
  ##Locating all non-syn locations in 64*64 R matrix.
  omega.id = c()
  for (i in 1:61) {
    for (j in 1:61) {
      if((i != j) && 
         (sum(cod[i, ] != cod[j, ]) == 1) && 
         (!(codonstrs[j] %in% syn[[codonstrs[i]]])) ){
        omega.id = c(omega.id, i, j)          
      }
    }
  }
  omega.id = split(omega.id, ceiling(seq_along(omega.id) / 2))
  
  #Build sigma list for M-step
  ##Locating all 6-sigma locations in 64*64 R matrix.
  ii = GTR(1:6, rep(1,4))
  diag(ii) = 0
  I = matrix(0, 61, 61)
  for (i in 1:61) {
    for (j in 1:61) {
      if(i == j){
        I[i, j] = 0
      }else if(sum(cod[i, ] != cod[j, ]) > 1){
        I[i, j] = 0
      }else{
        pos = which(cod[i, ] != cod[j, ])
        x   = which(DNA_BASES == cod[i, pos])
        y   = which(DNA_BASES == cod[j, pos])
        I[i, j] = ii[x, y]
      }
    }
  }
  sigma.id = sapply(1:6, function(x){which(I == x)})
  
  
  #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>PARTII
  #read files 
  #Name = "Results/est90/ATGC389.json"
  name = str_extract(basename(Name), "[^.]+")
  file = paste0(inD,'/',name,'.clean.fasta')
  
  #determine mg94 dim
  dat1 = countN(file)
    
  ##empirical f
  f1     = rowSums(dat1) + colSums(dat1)  
  f1.id  = sapply(seq(61), function(x){match(cod[x, ], DNA_BASES)})
  base.f = c()
  for (i in seq(4)) {
    base.id = sapply(seq(61), function(x){length(which(f1.id[, x] == i))})
    base.f  = c(base.f, sum(base.id*f1))
  }
  f  = base.f/sum(base.f)
  print(sum(f)) 
  
  #em to obtain the est of f0
  f0=f
  sum_61 = sum(f1)
  for (i in 1:20) {
    Pi_stp = c(f0[1]^2*f0[4],f0[1]*f0[3]*f0[4],f0[3]*f0[1]*f0[4]) 
    Pi_61  = 1 - sum(Pi_stp)
    
    sum_stp  = sum_61/Pi_61 - sum_61      
    stp_norm = Pi_stp/sum(Pi_stp) *sum_stp
    
    #print the ll
    cf0 = sapply(seq(61), function(x){prod(f0[match(cod[x, ], DNA_BASES)])})
    ll  = sum(f1*log(cf0))- sum_61*log(Pi_61)                         
    #cat(sprintf("%i: %.6f\n", i, ll))
    
    denom = 3*(sum_61+sum_stp)
    
    f0 = c(base.f[1]+2*stp_norm[1]+stp_norm[2]+stp_norm[3], 
           base.f[2],
           base.f[3]+stp_norm[2]+stp_norm[3],
           base.f[4]+sum_stp)/denom
    #print(sum(f0))
  }
  cf0 = cf0/sum(cf0)
  
  #init sigma
  #create nuc transition matrix [4-fold-degeneracy-codons only]
  fourD_id = which(sapply(syn, function(x){length(x) == 4}))
  k=1
  ndat = matrix(0,4,4)
  while (k<length(fourD_id)) {
    i = j = fourD_id[k:(k+3)]
    ndat = ndat+dat1[i,j]
    k=k+4
  }
  fn = rowSums(ndat) + colSums(ndat)        #neutral freq
  fn = fn/sum(fn)
  #print(sum(fn))
  
  #symmetric average of dat
  sdat  = matrix(0,4,4)
  diag(sdat) = diag(ndat)
  sdat  = (ndat + t(ndat))/2
  sf    = colSums(sdat)/sum(sdat)
  #print(sum(sf))
  Dhat  = diag(sf)
  phat  = t(sdat/colSums(sdat))
  
  #logm(phat)
  eigP  = eigen(phat)
  Athat = eigP$vectors %*% diag(log(eigP$values)) %*%  inv(eigP$vectors)
  that  = -sum(diag(Athat*Dhat))
  #print(that)      
  Ahat = t(Athat)/that
  #print(Ahat)
  s  = Ahat[lower.tri(t(Ahat))]
  
  #>>
  if(any(s<0)){
    cat(sprintf("neg-s0:  %s\n",name))
    s = runif(6)
  }
  
  #init omega
  #obs non-syn change. 
  obs.non = sum(sapply(omega.id, function(x){dat1[x[1],x[2]]}))
  
  #exp non-syn change
  gtr2  = GTR(s, f0)
  mg942 = MG94(gtr2, 1, cod)
  P942  = expm(mg942)
  print(sum(P942))
  
  exp.non = 0
  for (i in 1:61) {
    ith.non = omega.id[which(sapply(omega.id,'[[',1)==i)]
    exp.non = exp.non + f1[i]*sum(sapply(ith.non, function(x){P942[x[1],x[2]]}))
  }
  w = obs.non/(exp.non/2)
  
  
  #init p >>>>>>>>>>>>>>>>>>>>
  #setup global
  f0       <<- f0
  cf0      <<- cf0
  dat1     <<- dat1
  omega.id <<- omega.id
  sigma.id <<- sigma.id
  
  
  p0   = c(s,w)
  tm4b = system.time({
    ps4b = fpiter(par=p0, fixptfn=em, control=list(tol=1e-4, trace=TRUE, intermed=TRUE))
  })
  
  #deal with bigger tau.
  # tm4    = system.time({
  #   ps4b = squarem(par=p0, fixptfn=em, control=list(tol=1e-4, trace=TRUE, intermed=TRUE))
  # })
  
  
  pd  = ps4b$p.intermed
  llv = c()
  tv  = c()
  for (i in 1:nrow(pd)) {
    rmat   = GTR(pd[i,1:6],f0)
    tv[i]  = -sum(diag(rmat)*f0) 
    llv[i] = LL(pd[i,1:7])
    }
  
  nuc.mat         = matrix(f0,nrow(pd),4,byrow=T)
  ps4b$p.intermed = cbind(pd,llv,tv,nuc.mat)
  ps4B            = toJSON(ps4b)
  
  #output 
  write(ps4B,Name)
  #write(ps4B,paste0("../../test_90_species/",Name))
  
}


#######################
args = commandArgs(trailingOnly = TRUE)
main(args[1],args[2])

