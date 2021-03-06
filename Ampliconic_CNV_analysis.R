#load REQUIRED packages
require(outliers)
require(plyr)
require(reshape2)
require(ggplot2)
require(ape)
require(ggtree)
require(ggrepel)
require(MASS)
require(nlme)

dat<-read.table('Table_S1A_ddPCR_outlier_analysis',header=T,sep="\t")

#remove RPP30
dat<-dat[-which(dat$Gene=="RPP30"),]

###outlier removal####
#count number of nonmissing observations for each person

dat$n<-apply(dat[,c(3:5)],1,function(x){length(which(is.na(x)=="FALSE"))})

#calculate cv for each row before outlier removal
dat$sd1<-apply(dat[,c(3:5)],1,sd,na.rm=T)
dat$mean1<-apply(dat[,c(3:5)],1,mean,na.rm=T)
dat$cv1<-dat$sd1/dat$mean1
dat$median1<-apply(dat[,c(3:5)],1,median,na.rm=T)

#plot cv for each gene before outlier removal
fig_s1a<-ggplot()+geom_boxplot(data=dat,aes(Gene,cv1),color="blue",outlier.shape=NA)+geom_point(data=dat,aes(Gene,cv1),position="jitter",alpha=0.7,color="blue")+theme_bw()+labs(x="Gene",y="Coefficient of Variation")+geom_hline(yintercept=median(dat$cv1,na.rm=T),color="red",linetype="dashed",size=1)+ylim(c(0,0.57))


#determine which of the three replicates is the most distant from the other two. 
dat$outlier<-NA
for(i in 1:nrow(dat)){
  if(dat$n[i]>2){
    if(length(unique(as.character(dat[i,c('a','b','c')])))>1){
      g1<-dat[i,c('a','b','c')]-dat[i,'median1']
      distant.obs<-which(abs(g1)==max(abs(g1)))
      if(length(distant.obs)>1){dat$outlier[i]<-sample(distant.obs,1)}else{dat$outlier[i]<-distant.obs}
  }
  }
}

#create new dataframe and replace outlier values with NA

dat2<-dat[,c(1:6)]
for(i in 1:nrow(dat2)){
  if(is.na(dat$outlier[i])=="FALSE"){
    outlier.index<-dat$outlier[i]
    dat2[i,c('a','b','c')][outlier.index]<-NA
  }
}

#calculate mean, sd and coefficient of variation per gene per individual after outlier removal
dat2$n<-apply(dat2[,c(3:5)],1,function(x){length(which(is.na(x)=="FALSE"))})
dat2$mean<-apply(dat2[,c('a','b','c')],1,mean,na.rm=T)
dat2$sd<-apply(dat2[,c('a','b','c')],1,sd,na.rm=T)
dat2$cv<-dat2$sd/dat2$mean



#read table with haplogroup information for each ID
haplo<-read.table('haplogroup_info_11202017.txt',sep="\t",header=T)

#merge copy number with haplogroup info in one dataframe
dat3<-merge(dat2,haplo,by="IID",sort=F)

#plot coefficient of variation for each gene and red line with median cv across all genes after outlier removal
fig_s1b<-ggplot()+geom_boxplot(data=dat3,aes(Gene,cv),color="blue",outlier.shape=NA)+geom_point(data=dat3,aes(Gene,cv),position="jitter",alpha=0.7,color="blue")+theme_bw()+labs(x="Gene",y="Coefficient of Variation")+geom_hline(yintercept=median(dat3$cv,na.rm=T),color="red",linetype="dashed",size=1)

#pivot table so that ids are rows and columns are genes. average copy number across replicates
dat4<-dcast(dat3,IID~Gene,value.var="mean")
dat4$IID<-as.character(dat4$IID)
dat4<-join(dat4,haplo,by="IID")

#plot mean and variance of ampliconic genes
sum.dat4<-data.frame(Gene=colnames(dat4)[c(2:10)],Median=apply(dat4[,c(2:10)],2,median,na.rm=T),Variance=apply(dat4[,c(2:10)],2,var,na.rm=T))
fig_1<-ggplot(sum.dat4,aes(log(Median),log(Variance),color=Gene))+geom_point()+stat_smooth(method="lm",se=F,color="grey")+theme_bw()+geom_text_repel(aes(log(Median),log(Variance),label=Gene))

#read y haplogrup tree
ytree<-read.tree('tree.nwk')

#convert tree to dataframe for easier plotting and labeling
ydat<-fortify(ytree)

#split label into individual id and haplogroup info
ydat$IID<-sapply(ydat$label,function(x){unlist(strsplit(x,split="_"))[1]})
ydat$haplogroup<-sapply(ydat$label,function(x){unlist(strsplit(x,split="_"))[2]})
ydat$major_haplo<-sapply(ydat$haplogroup,function(x){unlist(strsplit(x,split=""))[1]})

#add copy number data to phylogeny table and round off to 2 decimal places
ydat<-join(ydat,dat4,by="IID")

#plot y phylogeny with haplogroups colored
groupInfo<-split(ydat$label,ydat$major_haplo)
ytree<-groupOTU(ytree,groupInfo)

p<-ggtree(ytree,aes(color=group))+geom_segment(data=ydat[which(is.na(ydat$haplogroup)=="FALSE"),],aes(x=x,xend=0.09,y=y,yend=y,color=major_haplo),linetype="dotted")

#add scale
p<-p+geom_treescale(y=-2,offset=-2)

ydat[,c('BPY','CDY','DAZ','HSFY','PRY','RBMY','TSPY','VCY','XKRY')]<-apply(ydat[,c('BPY','CDY','DAZ','HSFY','PRY','RBMY','TSPY','VCY','XKRY')],2,function(x){format(round(x,2),nsmall=2)})
ydat<-ydat[which(is.na(ydat$major_haplo)=="FALSE"),]

#add copy number information
fig_2<-p+geom_text(data=ydat,aes(x=0.096,label=CDY,y=y,color=major_haplo))+geom_text(data=ydat,aes(x=0.100,label=BPY,y=y,color=major_haplo))+geom_text(data=ydat,aes(x=0.104,label=DAZ,y=y,color=major_haplo))+geom_text(data=ydat,aes(x=0.108,label=PRY,y=y,color=major_haplo))+geom_text(data=ydat,aes(x=0.112,label=RBMY,y=y,color=major_haplo))+geom_text(data=ydat,aes(x=0.116,label=HSFY,y=y,color=major_haplo))+geom_text(data=ydat,aes(x=0.120,label=XKRY,y=y,color=major_haplo))+geom_text(data=ydat,aes(x=0.124,label=VCY,y=y,color=major_haplo))+geom_text(data=ydat,aes(x=0.128,label=TSPY,y=y,color=major_haplo))+geom_text(aes(x=0.096,y=106,label="CDY"),color="black",angle=90,size=10)+geom_text(aes(x=0.100,y=106,label="BPY"),color="black",angle=90,size=10)+geom_text(aes(x=0.104,y=106,label="DAZ"),color="black",angle=90,size=10)+geom_text(aes(x=0.108,y=106,label="PRY"),color="black",angle=90,size=10)+geom_text(aes(x=0.112,y=106,label="RBMY"),color="black",angle=90,size=10)+geom_text(aes(x=0.116,y=106,label="HSFY"),color="black",angle=90,size=10)+geom_text(aes(x=0.120,y=106,label="XKRY"),color="black",angle=90,size=10)+geom_text(aes(x=0.124,y=106,label="VCY"),color="black",angle=90,size=10)+geom_text(aes(x=0.128,y=106,label="TSPY"),color="black",angle=90,size=10)

#plot copy number by gene and haplogroup
fig_3<-ggplot(dat3,aes(major_haplo,mean))+geom_boxplot(outlier.shape=NA,position=position_dodge(width=1))+geom_point(alpha=0.5,color="blue",position="jitter",size=0.7)+facet_wrap(~Gene,scale="free_y")+theme_bw()+theme()+labs(x="Y - Haplogroup",y="Copy Number")

#run pca on SNP genotype data with plink
#system('plink --bfile ched_polysnps2 --pca 300 --out pca_11182017')

#load eigenvector and eigenvalue files for SNPs into R
eigval.snps<-read.table('pca_11182017.eigenval',header=F)
eigvec.snps<-read.table('pca_11182017.eigenvec',header=F)
colnames(eigvec.snps)<-c("FID","IID",paste("PC",seq(1,length(eigvec.snps)-2,1),sep=""))

#plot screeplot/proportion of variance explained by each PC - snps - part of fig_s2
eigval.snps$prop<-eigval.snps$V1/sum(eigval.snps$V1)
eigval.snps$PC<-seq(1,nrow(eigval.snps),1)
screesnps<-ggplot(eigval.snps,aes(PC,prop))+geom_point()+geom_line()+theme_bw()+labs(y="Prop. of variance explained")+scale_x_continuous(breaks=seq(1,9,1),limits=c(1,9)) # limit no. of PCs in plot to 9

#add haplogroup info to PCs for plotting
eigvec.snps<-join(eigvec.snps,haplo,by="IID")

#plot PC1 v PC2 for SNPs - part of fig_4 - combine in illustrator
snps.p1vp2<-ggplot(eigvec.snps,aes(PC1,PC2,color=major_haplo))+geom_point(alpha=0.7)+theme_bw()+labs(color="Haplogroup")
#plot PC1 v PC3 for SNPs - part of fig_4 - combine in illustrator
snps.p1vp3<-ggplot(eigvec.snps,aes(PC1,PC3,color=major_haplo))+geom_point(alpha=0.7)+theme_bw()+labs(color="Haplogroup")

#run pca on ampliconic gene copy number - remove rows with missing values first
dat.pca<-dat4[which(is.na(dat4$CDY)=="FALSE"),]
pca<-prcomp(dat.pca[,c(2:10)],center=T,scale=T)

#load eigenvalues and eigenvectors for ampliconic genes
eigval.cnv<-data.frame(V1=pca$sdev)
eigvec.cnv<-data.frame(pca$x)
eigvec.cnv$IID<-as.character(dat.pca$IID)
eigvec.cnv$major_haplo<-as.character(dat.pca$major_haplo)

#plot screeplot/proportion of variance explained by each PC - cnv - part of fig_s2
eigval.cnv$prop<-eigval.cnv$V1/sum(eigval.cnv$V1)
eigval.cnv$PC<-seq(1,nrow(eigval.cnv),1)
screecnv<-ggplot(eigval.cnv,aes(PC,prop))+geom_point()+geom_line()+theme_bw()+labs(y="Prop. of variance explained")+scale_x_continuous(breaks=seq(1,9,1),limits=c(1,9)) # limit no. of PCs in plot to 10


#plot PC1 v PC2 for CNVs - part of fig_4 - combine in illustrator
cnv.p1vp2<-ggplot(eigvec.cnv,aes(PC1,PC2,color=major_haplo))+geom_point(alpha=0.7)+theme_bw()+labs(color="Haplogroup")
#plot PC1 v PC3 for CNVs - part of fig_4 - combine in illustrator
cnv.p1vp3<-ggplot(eigvec.cnv,aes(PC1,PC3,color=major_haplo))+geom_point(alpha=0.7)+theme_bw()+labs(color="Haplogroup")


#one-way Anova for every gene
#BPY
anova(lm(data=dat4,BPY~major_haplo))
#CDY
anova(lm(data=dat4,CDY~major_haplo))
#DAZ
anova(lm(data=dat4,DAZ~major_haplo))
#HSFY
anova(lm(data=dat4,HSFY~major_haplo))
#PRY
anova(lm(data=dat4,PRY~major_haplo))
#RBMY
anova(lm(data=dat4,RBMY~major_haplo))
#TSPY
anova(lm(data=dat4,TSPY~major_haplo))
#VCY
anova(lm(data=dat4,VCY~major_haplo))
#XKRY
anova(lm(data=dat4,XKRY~major_haplo))

###phylogenetic Anova###

##Eve requires three files - phylogenetic file, trait data file, number of individuals within each haplogroup

#1. write phylogenetic file

##root phylogenetic tree
#C and E haplogroups are the oldest in our tree. get MRCA for any two descendants from them
getMRCA(ytree,c(95,74)) # ydat are node labels in ydat
# 173 is the parent node for these two lineages
rooted.ytree<-reroot(ytree,node=173) # this is not very important


#collapse all branches within each clade
col.ytree<-drop.tip(rooted.ytree,c(1:19,21:24,26:28,30:33,35:47,49:52,54:67,69:72,74:77,79:99))
#relabel the tips with their haplogroup
col.ytree$tip.label<-c("R","Q","L","T","O","J","I","G","C","E")

#make tree ultrametric - i.e. calibrate tree based on timing of root = 261.5 kya
mycalibration <- makeChronosCalib(col.ytree, node="root", age.max=261.5)
cal.col.ytree <- chronos(col.ytree, lambda = 1, model = "relaxed", calibration = mycalibration, control = chronos.control() )

#write.tree to file
write.tree(cal.col.ytree,'y_timetree_haplo.nwk')

#add 10 as the first line - number of haplogroups -EVE requires this  
system('echo 10 | cat - y_timetree_haplo.nwk > y_timetree_haplo_eve.nwk')


#2. write trait/copy number data file

#create new dataframe to work with
copy.number<-dat4[,c(1:10,13)]

#remove row with missing data for CDY
copy.number2<-copy.number[which(is.na(copy.number$CDY)=="FALSE"),]

#order rows by haplogroups in the order of the phylogenetic tree file
copy.number2$order<-NA
copy.number2[which(copy.number2$major_haplo=="T"),'order']<-4
copy.number2[which(copy.number2$major_haplo=="L"),'order']<-3
copy.number2[which(copy.number2$major_haplo=="Q"),'order']<-2
copy.number2[which(copy.number2$major_haplo=="R"),'order']<-1
copy.number2[which(copy.number2$major_haplo=="E"),'order']<-10
copy.number2[which(copy.number2$major_haplo=="C"),'order']<-9
copy.number2[which(copy.number2$major_haplo=="G"),'order']<-8
copy.number2[which(copy.number2$major_haplo=="I"),'order']<-7
copy.number2[which(copy.number2$major_haplo=="J"),'order']<-6
copy.number2[which(copy.number2$major_haplo=="O"),'order']<-5
copy.number3<-copy.number2[order(copy.number2$order),]

#transpose so genes are rows and individuals are columns
tcopy.number3<-t(copy.number3[,-c(1,2,12)])

#write to file
write.table(tcopy.number3,'y.exprdat',row.names=T,col.names=F,quote=F,sep=" ")

#add 9 - number of genes to as first line - EVE requires this.
system('echo 9 | cat - y.exprdat > y_eve.exprdat')


#3. write individual file - number of individuals per haplogroup in the SAME order as phylogenetic tree

#order levels of major_haplogroup to match phylogeny
copy.number3$major_haplo<-factor(copy.number3$major_haplo,levels=c("R","Q","L","T","O","J","I","G","C","E"))

#write frequency of observations per haplogroup in dataframe to file
write.table(t(table(copy.number3$major_haplo)),'y_eve.nindv',col.names=F,row.names=F,quote=F)

##run EVE in terminal
#assuming EVE binary and input data are in current directory 
#Read README file for more detail
#./EVEmodel -S -n 12 -t y_timetree_haplo_eve.nwk -i y_eve.nindiv -d y_eve.exprdat -f _trialRun -v 10

##### Linear Discriminant Analysis ######


# run LDA with major haplogroup as category and gene counts as predictors
ld2<-lda(data=copy.number3,major_haplo~BPY+CDY+DAZ+HSFY+PRY+RBMY+TSPY+VCY+XKRY,CV=T,method="mle",prior=rep(1,10)/10)

#write function to plot posterior probabilities
plt.ld<-function(x,df){
  ldpx<-x$posterior
  ldpx<-as.data.frame(ldpx)
  ldpx$IID<-df$IID
  ldpx$major_haplo<-df$major_haplo
  haplos=c("R","Q","L","T","O","J","I","G","C","E")
  ldpx$pmatch<-NA
  ldpx$pmismatch<-NA
  for(i in 1:10){
    ldpx$pmatch[which(ldpx$major_haplo==haplos[i])]<-ldpx[which(ldpx$major_haplo==haplos[i]),haplos[i]]
    ldpx$pmismatch[which(ldpx$major_haplo==haplos[i])]<-apply(ldpx[which(ldpx$major_haplo==haplos[i]),haplos[-which(haplos==haplos[i])]],1,sum)
  }
  mldpx<-melt(ldpx[,c('IID','major_haplo','pmatch','pmismatch')],id.vars=c("IID",'major_haplo'))
  p<-ggplot(mldpx,aes(as.character(IID),value,fill=variable))+geom_bar(stat="identity",width=1)+facet_wrap(~major_haplo,scales="free_x",nrow=2)+theme_bw()+theme(axis.text.x=element_blank())
  p<-p+scale_fill_manual(values=c("#377eb8","#ff7f00"),labels=c("match","mismatch"))
  p<-p+labs(x="Individuals",y="Posterior Probability",fill="Match/Mismatch")
  return(p)
}

#plot!
plt.ld(ld2,copy.number3)


####haplotype analysis comes here######

#round mean copy number to nearest integer

copy.integer<-copy.number3
copy.integer[,c(2:10)]<-apply(copy.integer[,c(2:10)],2,round)

##testing effect of rounding mean copy number to integer on number of haplotypes
mcopy.number<-melt(copy.number3,id.vars = c("IID","major_haplo","order"))
colnames(mcopy.number)[c(4,5)]<-c("Gene","copy_number")

#create limits of window within which values will be randomly rounded up or down
#lower limit
mcopy.number$floor<-floor(mcopy.number$copy_number)+0.25
#upper limit
mcopy.number$ceiling<-ceiling(mcopy.number$copy_number)-0.25
#new column indicating which observations fall within this window
mcopy.number$hairy<-NA
mcopy.number$hairy[which(mcopy.number$copy_number<mcopy.number$ceiling & mcopy.number$copy_number>mcopy.number$floor)]<-1
mcopy.number$hairy[-which(mcopy.number$copy_number<mcopy.number$ceiling & mcopy.number$copy_number>mcopy.number$floor)]<-0

#function to randomly round up or down an observation x
rand.round<-function(x){
  flip<-rbinom(1,1,0.5)
  if(flip==1){y=ceiling(x)}
  if(flip==0){y=floor(x)}
  return(y)
}

#function to randomly round up or down an observation x
rand.round<-function(x){
  flip<-rbinom(1,1,0.5)
  if(flip==1){y=ceiling(x)}
  if(flip==0){y=floor(x)}
  return(y)
}

#apply rand.round function to data 100 times
rand.mat<-matrix(NA,900,100)
for(i in 1:100){
  rand.mat[which(mcopy.number$hairy==1),i]<-sapply(mcopy.number[which(mcopy.number$hairy==1),'copy_number'],rand.round)
  rand.mat[which(mcopy.number$hairy==0),i]<-round(mcopy.number[which(mcopy.number$hairy==0),'copy_number'])
}

#cleanup
rand.mat<-as.data.frame(rand.mat)
rand.mat$IID<-mcopy.number$IID
rand.mat$Gene<-mcopy.number$Gene
mrand.mat<-melt(rand.mat,id.vars=c("Gene","IID"))
dmrand.mat<-dcast(mrand.mat,IID+variable~Gene,value.var="value")


######haplotype networkanalysis####


######calculating number of differences between pairs of haplotypes within and between haplogroups######

#create vector of haplogroups
haplos<-levels(copy.number3$major_haplo)

#randomly select from within haplogroups
wn.diffs<-matrix(NA,1000,9)
wn.haplo<-matrix(NA,1000,1)
for(i in 1:1000){
  test.haplo<-sample(haplos,1)
  wn.haplo[i,1]<-test.haplo
  test.dat<-copy.integer[which(copy.integer$major_haplo==test.haplo),]
  test.dat<-test.dat[sample(nrow(test.dat),2),]
  wn.diffs[i,]<-as.matrix(abs(test.dat[1,c("BPY","CDY","DAZ","HSFY","PRY","RBMY","TSPY","VCY","XKRY")]-test.dat[2,c("BPY","CDY","DAZ","HSFY","PRY","RBMY","TSPY","VCY","XKRY")]))
}

#randomly select from between haplogroups
bw.diffs<-matrix(NA,1000,9)
bw.haplo<-matrix(NA,1000,2)
for(i in 1:1000){
  test.haplos<-sample(haplos,2)
  bw.haplo[i,]<-test.haplos
  test.dat1<-copy.integer[which(copy.integer$major_haplo==test.haplos[1]),]
  test.dat2<-copy.integer[which(copy.integer$major_haplo==test.haplos[2]),]
  test.dat<-rbind(test.dat1[sample(nrow(test.dat1),1),],test.dat2[sample(nrow(test.dat2),1),])
  bw.diffs[i,]<-as.matrix(abs(test.dat[1,c("BPY","CDY","DAZ","HSFY","PRY","RBMY","TSPY","VCY","XKRY")]-test.dat[2,c("BPY","CDY","DAZ","HSFY","PRY","RBMY","TSPY","VCY","XKRY")]))
}

colnames(wn.diffs)<-colnames(bw.diffs)<-c("BPY","CDY","DAZ","HSFY","PRY","RBMY","TSPY","VCY","XKRY")
bw.diffs<-as.data.frame(bw.diffs)
wn.diffs<-as.data.frame(wn.diffs)

bw.diffs$comparison<-"Between Haplogroups"
wn.diffs$comparison<-"Within Haplogroups"

comb.diffs<-rbind(bw.diffs,wn.diffs)
mcomb.diffs<-melt(comb.diffs,id.vars=c("comparison"))
colnames(mcomb.diffs)<-c("comparison","Gene","Difference")
fig_6d<-ggplot()+geom_boxplot(data=mcomb.diffs,aes(Gene,Difference,fill=comparison))+theme_bw()+labs(y="Copy number difference b/w two randomly picked haplotypes")


#####Phenotype-CNV correlations#######

#load phenotype data
pheno<-read.table('ched_phenotypes.txt',header=T,sep="\t")
ytree$tip.label<-sapply(ytree$tip.label,function(x){unlist(strsplit(x,split="_"))[1]})
pheno<-pheno[which(pheno$IID%in%ytree$tip.label),]
pheno<-join(pheno,copy.number,by="IID")
row.names(pheno)<-as.character(pheno$IID)

#running one-way ANOVA (no phylogenetic correction between height and BPY). Run separately for each gene
height.bpy<-lm(data=pheno,Height_cm~BPY,na.action="na.exclude")
height.cdy<-lm(data=pheno,Height_cm~CDY,na.action="na.exclude")
height.daz<-lm(data=pheno,Height_cm~DAZ,na.action="na.exclude")
height.hsfy<-lm(data=pheno,Height_cm~HSFY,na.action="na.exclude")
height.pry<-lm(data=pheno,Height_cm~PRY,na.action="na.exclude")
height.rbmy<-lm(data=pheno,Height_cm~RBMY,na.action="na.exclude")
height.tspy<-lm(data=pheno,Height_cm~TSPY,na.action="na.exclude")
height.vcy<-lm(data=pheno,Height_cm~VCY,na.action="na.exclude")
height.xkry<-lm(data=pheno,Height_cm~XKRY,na.action="na.exclude")

#running phylogenetic linear model between height and BPY. Run separately for each gene
height.phylo<-gls(Height_cm~BPY,correlation=corBrownian(phy=ytree),data=pheno,method="ML",na.action="na.exclude") #run full model

#running phylogenetic linear model between fmf and BPY. Run separately for each gene
#some missing data present in pheno. remove and run

missing_ids<-pheno[which(is.na(pheno$FMF)=="TRUE"),'IID']
nodes2drop<-ydat$node[which(ydat$IID%in%missing_ids)]
ytree.red<-drop.tip(ytree,tip=nodes2drop)

pheno.red<-pheno[-which(pheno$IID%in%missing_ids),]

fmf.phylo<-gls(FMF~BPY,correlation=corBrownian(phy=ytree.red),data=pheno.red,method="ML",na.action="na.exclude") #run full model



