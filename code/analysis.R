
#load libraries used in the following data analysis, make vector of colors 
#for cluster visualization and set seed for downsampling

library(Seurat)
library(xlsx)
library(RColorBrewer)
library(tidyr)
library(viridis)
library(caret)
library(dplyr)
library(Seurat)
library(ggplot2)
library(sctransform)
library(ggpubr)
library(cowplot)
library(harmony)
library(colorspace)
library(SeuratWrappers)
library(DropletUtils)
colors.use <- c(brewer.pal(8, 'Set1'), brewer.pal(7, 'Dark2'),  'blue4',
'orangered', 'orangered4',"firebrick","black","green","purple","pink")
set.seed(05062020)

#read in Gsmo and Msmo seurat objects
#alternatively, if using DGEs, skip this step

GSMO <- readRDS('pathname/to/GSMO/Seurat/object')
MSMO <- readRDS('pathname/to/MSMO/Seurat/object')

#remove unwanted transcript
#if using DGEs, read in GSMO DGE to test and
#MSMO DGE to test1

test <- GetAssayData(object = GSMO, slot = 'data')
remove <- c("CRE-RECOMBINASE","Prm1")
test <- test[!rownames(test) %in% remove, ]
test <- downsampleMatrix(test, .6, bycol=TRUE)
GSMO <- CreateSeuratObject(test, project = "SeuratProject", assay = "RNA",
  min.cells = 0, min.features = 0, names.field = 1,
  names.delim = "_", meta.data = NULL)
  
test1 <- GetAssayData(object = MSMO, slot = 'data')
remove <- c("CRE-RECOMBINASE","Prm1")
test1 <- test1[!rownames(test1) %in% remove, ]
MSMO <- CreateSeuratObject(test1, project = "SeuratProject", assay = "RNA",
  min.cells = 0, min.features = 0, names.field = 1,
  names.delim = "_", meta.data = NULL)
  
#add meta data to seurat objects

GSMO[["percent.mt"]] <- PercentageFeatureSet(GSMO, pattern = "^mt-")
GSMO[["tumor.model"]] <- "GSMO"
MSMO[["percent.mt"]] <- PercentageFeatureSet(MSMO, pattern = "^mt-")
MSMO[["tumor.model"]] <- "MSMO"

#merge MSMO and GSMO datasets to make single seurat object
#filter merged object based on QC criteria

merged <- merge(x = MSMO, y = GSMO,  merge.data = TRUE)
max.UMI <- 4*sd(merged@meta.data$nCount_RNA) + median(merged@meta.data$nCount_RNA)
max.Gene <- 4*sd(merged@meta.data$nFeature_RNA) + median(merged@meta.data$nFeature_RNA)
merged <- subset(merged, subset =  nCount_RNA > 500 & nCount_RNA < max.UMI & 
nFeature_RNA > 200 & nFeature_RNA < max.Gene & percent.mt < 10)

#normalize data, calculate PCs, UMAP coordinates , and louvain clustering

merged <- SCTransform(merged, vars.to.regress = 
c("percent.mt","nFeature_RNA","nCount_RNA"), verbose = T)
merged <- RunPCA(merged, verbose = T, seed.use = 42)
merged <- RunUMAP(merged, dims = 1:17, verbose = FALSE, seed.use = 42)
merged <- FindNeighbors(merged, dims = 1:17, verbose = FALSE)
merged <- FindClusters(merged, resolution = 1.2)

#calculate percent variation explained by 17 PCs

string <- Stdev(merged, reduction = "pca")
eig <- (string^2)
sum(eig[1:17]) / sum(eig)

#differential expression analysis of clusters

Idents(merged) <- "seurat_clusters"
for (i in 0:21) {
clust0 <- FindMarkers(merged,ident.1 = i,  logfc.threshold = .10)
clust0$ratio <- clust0[,3]/(clust0[,4]+.0000001)
out <- clust0[order(-clust0[,6]), ]
}


#figure 2a

pdf("figure_2a.pdf")
DimPlot(merged, group.by=c("seurat_clusters"), cols = colors.use,pt.size = 1)
dev.off()


#figure 2b

#make vectors designating which cell expresses a given stromal marker

all <- WhichCells(object = merged, expression = Olig2 > -1)
C1qb <- all %in% WhichCells(object = merged, expression = C1qb > 1)
Col3a1 <- all %in% WhichCells(object = merged, expression = Col3a1 > 1)
Meg3 <- all %in% WhichCells(object = merged, expression = Meg3 > 1.5)
Rbfox3 <- all %in% WhichCells(object = merged, expression = Rbfox3 > 1.25)
Sox10 <- all %in% WhichCells(object = merged, expression = Sox10 > 0.5)
Aqp4 <- all %in% WhichCells(object = merged, expression = Aqp4 > 1.5)
Pecam1 <- all %in% WhichCells(object = merged, expression = Pecam1 > 0.75)
Rsph1 <- all %in% WhichCells(object = merged, expression = Rsph1 > 1)
Mog <- all %in% WhichCells(object = merged, expression = Mog > 1)

#merge vectors and make column to be used for final identity designation

total <- data.frame(C1qb,Col3a1,Meg3,Sox10,Aqp4,Pecam1,Rsph1,Mog)
total$ident <- 'zzz'
  
#make identity vector and add it to meta data

for (i in 1:14633) {
  if(total[i,1]) {
    total[i,9] <- "C1qb"
  }
  if(total[i,2]) {
    total[i,9] <- "Col3a1"
  }
    if(total[i,3]) {
    total[i,9] <- "Meg3"
    }
    if(total[i,4]) {
    total[i,9] <- "Sox10"
    }
    if(total[i,5]) {
    total[i,9] <- "Aqp4"
    }
      if(total[i,6]) {
    total[i,9] <- "Pecam1"
      }
       if(total[i,7]) {
    total[i,9] <- "Rsph1"
       }
       if(total[i,8]) {
    total[i,9] <- "Mog"
  }
}

merged[["stromal"]] <- total[,9]

pdf("figure_2b.pdf")
DimPlot(merged, group.by=c("stromal"), order = c("Meg3","Sox10","C1qb",
"Aqp4","Col3a1","Pecam1","Rsph1","Mog",'zzz'),
cols = rev(c(colors.use[14:19],colors.use[21:22],"lightgrey")),pt.size = 1)
dev.off()


#figure 2c

#make vectors designating which cell expresses a given differentiation
#axis marker

Mki67 <- all %in% WhichCells(object = merged, expression = Mki67 > 1)
Gli1 <- all %in% WhichCells(object = merged, expression = Gli1 > .6)  
Barhl1 <- all %in% WhichCells(object = merged, expression = Barhl1 > 1)  
Cntn2 <- all %in% WhichCells(object = merged, expression = Cntn2 > 1.25)
Rbfox3 <- all %in% WhichCells(object = merged, expression = Rbfox3 > 1.25) 
Grin2b <- all %in% WhichCells(object = merged, expression = Grin2b > 0)

#merge vectors and make column to be used for final identity designation

total <- data.frame(Mki67,Gli1,Barhl1,Cntn2,Rbfox3,Grin2b)
total$ident <- 'zzz'
 
#make identity vector and add it to meta data

for (i in 1:14633) {
  if(total[i,5]) {
    total[i,7] <- "Rbfox3"
  }
  if(total[i,3]) {
    total[i,7] <- "Barhl1"
  }
       if(total[i,4]) {
    total[i,7] <- "Cntn2"
   }

    if(total[i,1]) {
    total[i,7] <- "Mki67"
    }
    if(total[i,6]) {
    total[i,7] <- "Grin2b"
  }
     if(total[i,2]) {
    total[i,7] <- "Gli1"
  }
}

merged[["gene_set"]] <- total[,7]

Idents(merged) <- "gene_set"

pdf("figure_2c.pdf")
DimPlot(merged, group.by=c("gene_set"), cols = c("lightgrey","tomato1",
"skyblue2","red",brewer.pal(10,'Paired')[c(9)],"tan1","yellowgreen"), 
order = rev(c("zzz","Rbfox3","Barhl1","Gli1","Mki67","Grin2b","Cntn2")), 
pt.size = 1)
dev.off()


#figure 2d

#deconvolute merged seurat object into and MSMO and GSMO object
Idents(merged) <-"tumor.model"
gsmo <- subset(merged, idents = "GSMO")
msmo <- subset(merged, idents = "MSMO")

pdf("figure_2d.pdf")
DimPlot(gsmo,pt.size = 1)
DimPlot(msmo,pt.size = 1)
dev.off()


#figure 2e

#make matrix of replicate cluster contribution normalized to
#total cells

y <- 22
q<- 0:(y-1)
percent_node <- matrix(0, nrow = y, ncol = 11)
mice <- c("M6","M7", "M8","M9", "M11","G6","G7","G8","G9","G10","G11")
Idents(merged)<-"seurat_clusters"
for (i in 1:y) {
  for(j in 1:length(mice)){
percent_node[i,j] <- length(grep(mice[[j]], WhichCells(merged, idents = (i-1)), value=T))
/ length(grep(mice[[j]], WhichCells(merged, idents = 0:21, value=T)))
  }
}
percent <- as.vector(percent_node)
cluster <- rep(0:(y-1),11)
model <- c(rep("MSMO",5*y), rep("GSMO",6*y))
df <- data.frame(percent,cluster,model)
df$model <- as.factor(df$model)
df$cluster <- as.factor(df$cluster)

pdf("figure_2e.pdf", width=11)
ggbarplot(df, x = "cluster", y = "percent", 
          add = c("mean_se", "jitter"),
          color = "model", palette = c("#00AFBB", "#E7B800"),
          position = position_dodge(0.8)) + stat_compare_means(aes(group = model),
          label = "p.signif",hide.ns=T)
dev.off()


#figure 2f

pdf("figure_2f.pdf")
FeaturePlot(merged, features = c( "Nes", "Vim"), split.by = "tumor.model", order=T)
FeaturePlot(merged, features = c( "Olig1","Olig2"), split.by = "tumor.model", order=T)
dev.off()


#make gene list for cluster 1,2,7 comparing GSMO
#to MSMO tumor clusters

Idents(merged) <- "tumor.model"
gsmo <- subset(x = merged, ident = "GSMO")
msmo <- subset(x = merged, ident = "MSMO")
Idents(gsmo) <- "seurat_clusters"
Idents(msmo) <- "seurat_clusters"
gsmo1 <- subset(x = gsmo, ident = 1,2,7)
msmo1 <- subset(x = msmo, ident = c(0,3:6,8:13))
test<- merge(gsmo1,msmo1)
Idents(test) <- "tumor.model"
clust0 <- FindMarkers(test,ident.1 = "GSMO",ident.2="MSMO",  logfc.threshold = .01,min.pct = 0.01)
clust0$ratio <- clust0[,3]/(clust0[,4]+.0000001)
out <- clust0[order(-clust0[,6]), ]

#figure 4 a-f

pdf("figure_4a-f.pdf")
FeaturePlot(merged, features = c(  "SmoM2-EYFP","Eomes"), split.by = "tumor.model", order=T)
FeaturePlot(merged, features = c(  "Barhl1", "Ascl1"), split.by = "tumor.model", order=T)
FeaturePlot(merged, features = c( "Pax3","Pax2"), split.by = "tumor.model", order=T)
VlnPlot(pbmc, features = c("Eomes"),slot = "data",cols = c("#00AFBB","#E7B800"))
VlnPlot(pbmc, features = c("Barhl1"),slot = "data",cols = c("#00AFBB","#E7B800"))
dev.off()


#read in normal P7 cerebellum seurat object from Ocasio et al.
#and add meta data

WT <- readRDS('pathname to WT Seurat object')
WT[["percent.mt"]] <- PercentageFeatureSet(WT, pattern = "^mt-")
WT[["harmony_stat"]] <- "wildtype"
merged[["harmony_stat"]] <- "tumor"

#normalize data, calculate PCs, Harmony, UMAP coordinates, and louvain clustering

merged1 <- merge(x = merged, y = WT,  merge.data = TRUE)
merged1 <- SCTransform(merged1, vars.to.regress = c("percent.mt","nFeature_RNA","nCount_RNA") , verbose = T)
merged1 <- RunPCA(merged1, verbose = FALSE, seed.use = 42)
merged1 <- RunHarmony(merged1, "harmony_stat", plot_convergence = F, assay.use="SCT")
merged1 <- RunUMAP(merged1, dims = 1:50, verbose = FALSE, seed.use = 42, reduction = "harmony")
merged1 <- FindNeighbors(merged1, dims = 1:50, verbose = FALSE,reduction = "harmony")
merged1 <- FindClusters(merged1, resolution = 1.5)

#differential expression 

Idents(merged1) <- "seurat_clusters"
for (i in 0:26) {
clust0 <- FindMarkers(merged1,ident.1 = i,  logfc.threshold = .25)
clust0$ratio <- clust0[,3]/(clust0[,4]+.0000001)
out <- clust0[order(-clust0[,6]), ]
}


# figure 5a

#same steps as for figure 2b

all <- WhichCells(object = merged1, expression = Olig2 > -1)
C1qb <- all %in% WhichCells(object = merged1, expression = C1qb > 1)
Col3a1 <- all %in% WhichCells(object = merged1, expression = Col3a1 > 1.5)
Meg3 <- all %in% WhichCells(object = merged1, expression = Meg3 > 1.5)
Rbfox3 <- all %in% WhichCells(object = merged1, expression = Rbfox3 > 1)
Sox10 <- all %in% WhichCells(object = merged1, expression = Sox10 > 0.8)
Aqp4 <- all %in% WhichCells(object = merged1, expression = Aqp4 > 1.5)
Pecam1 <- all %in% WhichCells(object = merged1, expression = Pecam1 > 0.75)
Rsph1 <- all %in% WhichCells(object = merged1, expression = Rsph1 > 1)
Mog <- all %in% WhichCells(object = merged1, expression = Mog > 1)
total <- data.frame(C1qb,Col3a1,Meg3,Sox10,Aqp4,Pecam1,Rsph1,Mog)
total$ident <- 'zzz'
  
 for (i in 1:21668) {
  if(total[i,1]) {
    total[i,9] <- "C1qb"
  }
  if(total[i,2]) {
    total[i,9] <- "Col3a1"
  }
    if(total[i,3]) {
    total[i,9] <- "Meg3"
    }
    if(total[i,4]) {
    total[i,9] <- "Sox10"
    }
    if(total[i,5]) {
    total[i,9] <- "Aqp4"
    }
      if(total[i,6]) {
    total[i,9] <- "Pecam1"
      }
       if(total[i,7]) {
    total[i,9] <- "Rsph1"
       }
       if(total[i,8]) {
    total[i,9] <- "Mog"
  }
}

merged1[["stromal"]] <- total[,9]

pdf("figure_5a.pdf")
DimPlot(merged1, group.by=c("stromal"), order = c("Meg3","Sox10","C1qb","Aqp4","Col3a1"
,"Pecam1","Rsph1","Mog",'zzz'), cols = rev(c(colors.use[14:19],colors.use[21:22],"lightgrey"))
,pt.size = 1)
dev.off()

# figure 5b-g

#set up color vectors
clust <- brewer.pal(n = 8, name = "Set2")

#for each stromal cluster (figures 5-7) normalize data,
#UMAP coordinates, differential gene lists,
#and louvain clustering followed by cluster contribution 
#analysis and cluster markers meta data designations

c12 <- subset(x = merged1, idents  = 20)
c12 <- SCTransform(c12, vars.to.regress = c("percent.mt","nFeature_RNA","nCount_RNA") , verbose = T)
c12 <- RunUMAP(c12, dims = 1:50, verbose = FALSE, seed.use = 42)
c12 <- FindNeighbors(c12, dims = 1:50, verbose = FALSE)
c12 <- FindClusters(c12, resolution = .4)

for (i in 0:1) {
clust0 <- FindMarkers(c12,ident.1 = i,  logfc.threshold = .10)
clust0$ratio <- clust0[,3]/(clust0[,4]+.0000001)
out <- clust0[order(-clust0[,6]), ]
}

y <- 2
q<- 0:(y-1)
percent_node <- matrix(0, nrow = y, ncol = 16)
mice <- c("M6","M7", "M8","M9", "M11","G6","G7","G8","G9","G10","G11",
"WT01" ,"WT02" ,"WT03" ,"WT04" ,"WT05")
Idents(c12) <- "seurat_clusters"
Idents(merged1) <- "seurat_clusters"
levels(c12)
for (i in 1:y) {
  for(j in 1:16){
percent_node[i,j] <- length(grep(mice[[j]], WhichCells(c12, idents = (i-1)), value=T))
/ length(grep(mice[[j]], WhichCells(merged1, idents = 0:26, value=T)))
  }
}

percent <- as.vector(percent_node)*100
cluster <- rep(0:(y-1),16)
model <- c(rep("MSMO",5*y), rep("GSMO",6*y), rep("WT",5*y))

df <- data.frame(percent,cluster,model)

df$model <- as.factor(df$model)
df$cluster <- as.factor(df$cluster)

all <- WhichCells(object = c12, expression = Pecam1 > -1)
Pecam1 <- all %in% WhichCells(object = c12, expression = Pecam1 > 0)
Cldn5 <- all %in% WhichCells(object = c12, expression = Cldn5 > 0)
total <- data.frame(Pecam1,Cldn5)
total$ident <- 'zzz'

for (i in 1:length(all)) {

    if(total[i,2]) {
    total[i,3] <- "Cldn5"
    }
          if(total[i,1]) {
    total[i,3] <- "Pecam1"
        }
}

c12[["total"]] <- total[,3]

Apln <- all %in% WhichCells(object = c12, expression = Apln > 0)
Aplnr <- all %in% WhichCells(object = c12, expression = Aplnr > 0)
total1 <- data.frame(Apln,Aplnr)
total1$ident <- 'zzz'

for (i in 1:length(all)) {

        if(total1[i,1]) {
    total1[i,3] <- "Apln"
        }
    if(total1[i,2]) {
    total1[i,3] <- "Aplnr"
    }
}

c12[["cluster_0"]] <- total1[,3]

Abcb1a <- all %in% WhichCells(object = c12, expression = Abcb1a > 1)
Cxcl12 <- all %in% WhichCells(object = c12, expression = Cxcl12 > 0)
Flt1 <- all %in% WhichCells(object = c12, expression = Flt1 > 1.2)
total11 <- data.frame(Abcb1a,Cxcl12,Flt1)
total11$ident <- 'zzz'

for (i in 1:length(all)) {

        if(total11[i,1]) {
    total11[i,4] <- "Abcb1a"
        }

      if(total11[i,2]) {
    total11[i,4] <- "Cxcl12"
      }
        if(total11[i,3]) {
    total11[i,4] <- "Flt1"
      }
}

c12[["cluster_1"]] <- total11[,4]


pdf("figure_5b-g.pdf")
DimPlot(c12, group.by=c("seurat_clusters"), cols = colors.use ,pt.size = 3)
DimPlot(c12, group.by=c("tumor.model"),pt.size = 3)
ggbarplot(df, x = "cluster", y = "percent", 
          add = c("mean_se", "jitter"),
          color = "model", palette = c("#00AFBB", "#E7B800", "red"),
          position = position_dodge(0.8)) + stat_compare_means(aes(group = model), label = "p.signif",hide.ns=T)
DimPlot(c12, group.by=c("total"), cols = c(clust[1], clust[2],"lightgrey") ,pt.size = 3)
DimPlot(c12, group.by=c("cluster_0"), cols = c(clust[1],clust[2],"lightgrey") ,pt.size = 3)
DimPlot(c12, group.by=c("cluster_1"), cols = c(clust[1], clust[2], clust1[3],"lightgrey") ,pt.size = 3)
dev.off()


# figure 6a-h

c12 <- subset(x = merged1, idents  = 15)
c12 <- SCTransform(c12, vars.to.regress = c("percent.mt","nFeature_RNA","nCount_RNA") , verbose = T)
c12 <- RunUMAP(c12, dims = 1:50, verbose = FALSE, seed.use = 05112020)
c12 <- FindNeighbors(c12, dims = 1:50, verbose = FALSE)
c12 <- FindClusters(c12, resolution = .4)

for (i in 0:4) {
clust0 <- FindMarkers(c12,ident.1 = i,  logfc.threshold = .10)
clust0$ratio <- clust0[,3]/(clust0[,4]+.0000001)
out <- clust0[order(-clust0[,6]), ]
}

y <- 5
q<- 0:(y-1)
percent_node <- matrix(0, nrow = y, ncol = 16)
mice <- c("M6","M7", "M8","M9","G6","G7","G8","G9","G10",
"G11","WT01" ,"WT02" ,"WT03" ,"WT04" ,"WT05")

Idents(c12) <- "seurat_clusters"
Idents(merged1) <- "seurat_clusters"
levels(c12)
for (i in 1:y) {
  for(j in 1:16){
percent_node[i,j] <- length(grep(mice[[j]], WhichCells(c12, idents = (i-1)), value=T))
/ length(grep(mice[[j]], WhichCells(merged1, idents = 0:26, value=T)))
  }
}

percent <- as.vector(percent_node)*100
cluster <- rep(0:(y-1),16)
model <- c(rep("MSMO",5*y), rep("GSMO",6*y), rep("WT",5*y))

df <- data.frame(percent,cluster,model)
head(df)

df$model <- as.factor(df$model)
df$cluster <- as.factor(df$cluster)

all <- WhichCells(object = c12, expression = Mrc1 > -1)

Meis1 <- all %in% WhichCells(object = c12, expression = Meis1 > 0)
Cnn3 <- all %in% WhichCells(object = c12, expression = Cnn3 > 1)
C1qb <- all %in% WhichCells(object = c12, expression = C1qb > 0)
total5 <- data.frame(Meis1 ,Cnn3,C1qb)
total5$ident <- 'zzz'

for (i in 1:length(all)) {
 if(total5[i,3]) {
    total5[i,4] <- "C1qb"
        }
        if(total5[i,1]) {
    total5[i,4] <- "Meis1"
        }
    if(total5[i,2]) {
    total5[i,4] <- "Cnn3"
    }
}

c12[["meyloid"]] <- total5[,4]

Sparc <- all %in% WhichCells(object = c12, expression = Sparc > 0)
Cx3cr1 <- all %in% WhichCells(object = c12, expression = Cx3cr1 > 1.5)
total2 <- data.frame(Sparc ,Cx3cr1)
total2$ident <- 'zzz'

for (i in 1:length(all)) {

        if(total2[i,1]) {
    total2[i,3] <- "Sparc"
        }
    if(total2[i,2]) {
    total2[i,3] <- "Cx3cr1"
    }
}

c12[["cluster_0"]] <- total2[,3]


Mrc1 <- all %in% WhichCells(object = c12, expression = Mrc1 > 0)
Igf1 <- all %in% WhichCells(object = c12, expression = Igf1 > 1)
Wfdc17 <- all %in% WhichCells(object = c12, expression = Wfdc17 > 0)

total3 <- data.frame(Mrc1,Igf1,Wfdc17)
total3$ident <- 'zzz'
  

for (i in 1:length(all)) {

        if(total3[i,3]) {
    total3[i,4] <- "Wfdc17"
        }
    if(total3[i,2]) {
    total3[i,4] <- "Igf1"
  }
  if(total3[i,1]) {
    total3[i,4] <- "Mrc1"
  }

}

c12[["cluster_1"]] <- total3[,4]

all <- WhichCells(object = c12, expression = Mrc1 > -1)
H2 <- all %in% WhichCells(object = c12, expression = `H2-Ea-ps` > 0)
Il1b <- all %in% WhichCells(object = c12, expression = Il1b > 0)
Ccr2 <- all %in% WhichCells(object = c12, expression = Ccr2 > .5)
Cd74 <- all %in% WhichCells(object = c12, expression = Cd74 > 1)

total4 <- data.frame(H2,Il1b,Ccr2,Cd74)
total4$ident <- 'zzz'
  

for (i in 1:length(all)) {

      if(total4[i,4]) {
    total4[i,5] <- "Cd74"
      }
    if(total4[i,1]) {
    total4[i,5] <- "H2-Ea-ps"
  }
        if(total4[i,3]) {
    total4[i,5] <- "Ccr2"
        }
    if(total4[i,2]) {
    total4[i,5] <- "Il1b"
  }
}

c12[["cluster_2"]] <- total4[,5]

Mrc1 <- all %in% WhichCells(object = c12, expression = Mrc1 > 0)
Cd163 <- all %in% WhichCells(object = c12, expression = Cd163 > 0)
total5 <- data.frame(Mrc1 ,Cd163)
total5$ident <- 'zzz'

for (i in 1:length(all)) {

        if(total5[i,1]) {
    total5[i,3] <- "Mrc1"
        }
    if(total5[i,2]) {
    total5[i,3] <- "Cd163"
    }
}

c12[["cluster_3"]] <- total5[,3]


#####
pdf("figure_6a-k.pdf")
DimPlot(c12, group.by=c("seurat_clusters"), cols = colors.use ,pt.size = 3)
DimPlot(c12, group.by=c("meyloid"), cols = c(clust[1], clust[2], clust1[3],"lightgrey") ,pt.size = 3)
DimPlot(c12, group.by=c("tumor.model"),pt.size = 3)
ggbarplot(df[-c(17:20),], x = "cluster", y = "percent", 
          add = c("mean_se", "jitter"),
          color = "model", palette = c("#00AFBB", "#E7B800", "red"),
          position = position_dodge(0.8)) + stat_compare_means(aes(group = model), label = "p.signif", hide.ns = T)
DimPlot(c12, group.by=c("cluster_0"), cols = c(clust[1], clust[2],"lightgrey") ,pt.size = 3)
DimPlot(c12, group.by=c("cluster_1"), cols = c(clust[1], clust[2], clust1[3],"lightgrey") ,pt.size = 3)
DimPlot(c12, group.by=c("cluster_2"), cols = c(clust[1], clust[2], clust1[3],clust[4],"lightgrey") ,pt.size = 3)
DimPlot(c12, group.by=c("cluster_3"), cols = c(clust[1], clust[2],"lightgrey") ,pt.size = 3)
VlnPlot(merged, features = c("Mif"),slot = "data",cols = c("#00AFBB","#E7B800"))
dev.off()


# figure 7a-g

c12 <- subset(x = merged1, idents  = 18)
c12 <- SCTransform(c12, vars.to.regress = c("percent.mt","nFeature_RNA","nCount_RNA") , verbose = T)
c12 <- RunUMAP(c12, dims = 1:50, verbose = FALSE, seed.use = 42)
c12 <- FindNeighbors(c12, dims = 1:50, verbose = FALSE)
c12 <- FindClusters(c12, resolution = .4)

for (i in 0:2) {
clust0 <- FindMarkers(c12,ident.1 = i,  logfc.threshold = .10)
clust0$ratio <- clust0[,3]/(clust0[,4]+.0000001)
out <- clust0[order(-clust0[,6]), ]
}

y <- 3
q<- 0:(y-1)
percent_node <- matrix(0, nrow = y, ncol = 16)
mice <- c("M6","M7", "M8","M9", "M11","G6","G7","G8","G9","G10","G11",
"WT01" ,"WT02" ,"WT03" ,"WT04" ,"WT05")

Idents(c12) <- "seurat_clusters"
Idents(merged1) <- "seurat_clusters"
for (i in 1:y) {
  for(j in 1:16){
percent_node[i,j] <- length(grep(mice[[j]], WhichCells(c12, idents = (i-1)), value=T))  / length(grep(mice[[j]], WhichCells(merged1, idents = 0:26, value=T)))
  }
}

percent <- as.vector(percent_node)*100
cluster <- rep(0:(y-1),16)
model <- c(rep("MSMO",5*y), rep("GSMO",6*y), rep("WT",5*y))

df <- data.frame(percent,cluster,model)
head(df)

df$model <- as.factor(df$model)
df$cluster <- as.factor(df$cluster)

all <- WhichCells(object = c12, expression = Penk > -1)

Penk <- all %in% WhichCells(object = c12, expression = Penk > 0.5)
Axin2 <- all %in% WhichCells(object = c12, expression = Axin2 > 0.5)
tot <- data.frame(Penk,Axin2)
tot$ident <- 'zzz'

for (i in 1:length(all)) {

        if(tot[i,1]) {
    tot[i,3] <- "Penk"
        }
          if(tot[i,2]) {
    tot[i,3] <- "Axin2"
        }
}

c12[["cluster_0"]] <- tot[,3]

Moxd1 <- all %in% WhichCells(object = c12, expression = Moxd1 > 0)
Igfbp6 <- all %in% WhichCells(object = c12, expression = Igfbp6 > 0)
tot1 <- data.frame(Moxd1,Igfbp6)
tot1$ident <- 'zzz'

for (i in 1:length(all)) {

        if(tot1[i,1]) {
    tot1[i,3] <- "Moxd1"
        }
          if(tot1[i,2]) {
    tot1[i,3] <- "Igfbp6"
        }
}

c12[["cluster_1"]] <- tot1[,3]

Htra3 <- all %in% WhichCells(object = c12, expression = Htra3 > 0)
tot2 <- data.frame(Htra3)
tot2$ident <- 'zzz'

for (i in 1:length(all)) {
        if(tot2[i,1]) {
    tot2[i,2] <- "Htra3"
        }
}

c12[["cluster_2"]] <- tot2[,2]

Fabp5 <- all %in% WhichCells(object = c12, expression = Fabp5 > 0)
Rbp4 <- all %in% WhichCells(object = c12, expression = Rbp4 > 0)
Crabp2 <- all %in% WhichCells(object = c12, expression = Crabp2 > 0)
tot11 <- data.frame(Fabp5,Rbp4,Crabp2)
tot11$ident <- 'zzz'

for (i in 1:length(all)) {

        if(tot11[i,1]) {
    tot11[i,4] <- "Fabp5"
        }
              if(tot11[i,3]) {
    tot11[i,4] <- "Crabp2"
        }
          if(tot11[i,2]) {
    tot11[i,4] <- "Rbp4"
          }
}

c12[["extra"]] <- tot11[,4]


pdf("figure_7a-g.pdf")
DimPlot(c12, group.by=c("seurat_clusters"), cols = colors.use ,pt.size = 3)
DimPlot(c12, group.by=c("tumor.model"),pt.size = 3)
ggbarplot(df, x = "cluster", y = "percent", 
          add = c("mean_se", "jitter"),
          color = "model", palette = c("#00AFBB", "#E7B800", "red"),
          position = position_dodge(0.8)) + stat_compare_means(aes(group = model), label = "p.signif", hide.ns = T)
DimPlot(c12, group.by=c("cluster_0"), cols = c(clust[1],clust[2],"lightgrey") ,pt.size = 3)
DimPlot(c12, group.by=c("cluster_1"), cols = c(clust[1],clust[2]],"lightgrey") ,pt.size = 3)
DimPlot(c12, group.by=c("cluster_2"), cols = c( clust[1],"lightgrey") ,pt.size = 3)
DimPlot(c12, group.by=c("extra"), cols = c(clust[1],clust[2],clust[3],"lightgrey") ,pt.size = 3)
dev.off()
