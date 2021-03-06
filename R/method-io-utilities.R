#' @keywords internal 
.internal_import_qiime2 <- function(otuqza, taxaqza=NULL, mapfilename=NULL, 
                                    refseqqza=NULL, treeqza=NULL, 
                                    parallel=FALSE,
                                    ...){
    otux <- read_qza(otuqza, parallel=parallel)
    otutab <- otux$otutab
    refseq <- reftree <- taxatab <- sampleda <- NULL
    if (!is.null(taxaqza)){
        taxax <- read_qza(taxaqza, parallel=parallel)
        taxax <- taxax[match(rownames(otutab), rownames(taxax)),,drop=FALSE]
        if (!is.null(otux$taxatab)){
            taxax <- otux$taxatab
        }
        flag <- guess_rownames(rownames(otutab))
        if (flag!="Other"){
            refseq <- rownames(otutab)
            refseqnm <- paste0("OTU_", seq_len(length(refseq)))
            rownames(otutab) <- refseqnm
            rownames(taxax) <- refseqnm
            names(refseq) <- refseqnm
        }
        taxatab <- as.matrix(taxax)
    }
    if (!is.null(mapfilename)){
        if (inherits(mapfilename, "character") && file.exists(mapfilename)){
            sampleda <- read_qiime_sample(mapfilename)
        }else if (!inherits(mapfilename, "data.frame")){
            rlang::abort("The mapfilename should be a file or data.frame contained sample information!")
        }else{
            sampleda <- mapfilename
        }
    }
    if (!is.null(refseqqza)){
        if (inherits(refseqqza, "XStringSet")){
            refseq <- refseqqza
        }else if (inherits(refseqqza, "character") && file.exists(refseqqza)){
            refseq <- read_qza(refseqqza)
        }
    }
    if (!is.null(refseq)){
        refseq <- build_refseq(refseq)
    }
    if (!is.null(treeqza)){
        if (inherits(treeqza, "treedata")){
            reftree <- treeqza
        }else if (inherits(treeqza, "character") && file.exists(treeqza)){
            reftree <- treeio::read.treeqza(treeqza)
        }
    }

    return (list(otutab=otutab, 
                sampleda=sampleda, 
                taxatab=taxatab, 
                refseq=refseq, 
                otutree=reftree))
}

.internal_import_qiime <- function(otufilename, mapfilename = NULL, otutree = NULL, refseq = NULL){
    x <- read_qiime_otu(otufilename)

    if (!is.null(mapfilename)){
        if (file.exists(mapfilename)){
            sampleda <- read_qiime_sample(mapfilename)
        }else if (!inherits(mapfilename, "data.frame")){
            sampleda <- NULL
        }else{
            sampleda <- mapfilename
        }
    }else{
        sampleda <- NULL
    }

    if (!is.null(otutree)){
        if (file.exists(otutree)){
            rlang::warn(c("The reftree is a tree file, it is parsing by read.tree function.",
                     "It is better to parse it with the function of treeio",
                     "then the treedata or phylo result all can be supported."))
            otutree <- ape::read.tree(otutree) %>% treeio::as.treedata()
        }else if (inherits(otutree, "phylo")){
            otutree <- otutree %>% treeio::as.treedata()
        }else if (!inherits(otutree, "treedata")){
            otutree <- NULL
        }
    }

    if (!is.null(refseq)){
        if (file.exists(refseq)){
            refseq <- seqmagick::fa_read(refseq)
        }else if (inherits(refseq, "character")){
            refseq <- build_tree(refseq)
        }else if (!inherits(refseq, "XStringSet")){
            refseq <- NULL
        }
    }

    return (list(otutab = x$otuda,
                 sampleda = sampleda,
                 taxatab = x$taxada,
                 refseq = refseq,
                 otutree = otutree))
}

#' @keywords internal
.internal_import_dada2 <- function(seqtab, 
                                   taxatab=NULL, 
                                   reftree=NULL,
                                   sampleda=NULL, 
                                   ...){
    refseq <- colnames(seqtab)
    refseqnm <- paste0("OTU_", seq_len(length(refseq)))
    colnames(seqtab) <- refseqnm
    names(refseq) <- refseqnm
    if (!is.null(taxatab)){
        if (!identical(colnames(seqtab), rownames(taxatab))){
            taxatab <- taxatab[match(refseq, rownames(taxatab)), , drop=FALSE]
        }
        rownames(taxatab) <- refseqnm
        taxatab <- fillNAtax(taxatab) 
        #taxatab <- phyloseq::tax_table(as.matrix(taxatab))
    }
    refseq <- build_refseq(refseq)
    if (!is.null(reftree)){
        if (inherits(reftree, "phylo")){
            reftree <- treeio::as.treedata(reftree)
        }else if(inherits(reftree, "character") && file.exists(reftree)){
            rlang::warn(c("The reftree is a tree file, it is parsing by read.tree function.",
                     "It is better to parse it with the function of treeio", 
                     "then the treedata or phylo result all can be supported."))
            reftree <- ape::read.tree(reftree) %>% treeio::as.treedata()
        }
    }
    if (!is.null(sampleda)){
        if (inherits(sampleda, "character") && file.exists(sampleda)){
           sampleda <- read_qiime_sample(sampleda)
        }else if (!inherits(sampleda, "data.frame")){
           rlang::abort("The sampleda should be a file or data.frame contained sample information!")
        }
    }

    return (list(otutab=data.frame(t(seqtab),check.names=FALSE),
                sampleda=sampleda,
                taxatab=taxatab,
                refseq=refseq,
                otutree=reftree))
}

.build_mpse <- function(res){
    
    otuda <- res$otutab
    sampleda <- res$sampleda
    taxatab <- res$taxatab
    otutree <- res$otutree
    refseq <- res$refseq

    rownm <- rownames(otuda)
    colnm <- colnames(otuda)

    if (is.null(sampleda)){
        sampleda <- S4Vectors::DataFrame(row.names=colnames(otuda))
    }else{
        rnm <- rownames(sampleda)
        flagn <- intersect(rnm, colnm)
        if(!check_equal_len(list(rnm, flagn, colnm))){
            rlang::warn(c("The number of samples in otu table is not equal the number of samples in sample data.", 
                     "The same samples will be extract automatically !"))
        
            sampleda <- sampleda[rnm %in% flagn, , drop = FALSE]
            otuda <- otuda[, colnm %in% flagn, drop=FALSE]
        }
    }

    if (!is.null(taxatab)){
        rnm <- rownames(taxatab)
        flagn <- intersect(rnm, rownm)
        if(! check_equal_len(list(rnm, flagn, rownm))){
            rlang::warn(c("The number of features in otu table is not equal the number of features in taxonomy annotation.",
                          "The same features will be extract automatically !"))
        
            taxatab <- taxatab[rnm %in% flagn, , drop = FALSE]
            otuda <- otuda[rownm %in% flagn, , drop = FALSE]
        }
        taxatree <- convert_to_treedata2(x=data.frame(taxatab))
    }else{
        taxatree <- NULL
    }

    if (!is.null(otutree)){
        flagn <- intersect(otutree@phylo$tip.label, rownm)
        if ( !check_equal_len(list(flagn, otutree@phylo$tip.label, rownm))){
            rlang::warn(c("The number of features in otu table is not equal the number of tips in otu tree.",
                          "The same features will be extract automatically !"))
            rmotus <- setdiff(rownm, flagn)
        }else{
            rmotus <- NULL
        }
        if (length(rmotus) > 0 && length(rmotus) != treeio::Ntip(otutree)){
            otutree <- treeio::drop.tip(otutree, tip=rmotus)
            otuda <- otuda[rownm %in% flagn, , drop = FALSE]
            if (!is.null(taxatree) && length(rmotus) != treeio::Ntip(taxatree)){
                taxatree <- treeio::drop.tip(taxatree, tip=rmotus, collapse.singles=FALSE)
            }else{
                taxatree <- NULL
            }
        }else{
            otutree <- NULL
        }
    }

    if (!is.null(refseq)){
        rnm <- names(refseq)
        flagn <- intersect(rnm, rownm)
        if ( !check_equal_len(list(rnm, flagn, rownm))){
            rlang::warn(c("The number of features in otu table is not equal the number of sequence in refseq.",
                          "The same features will be extract automatically !"))
            rmotus <- setdiff(rownm, flagn)
        }else{
            rmotus <- NULL
        }
        refseq <- refseq[flagn]
        if (length(rmotus) > 0){
            otuda <- otuda[rownm %in% flagn, , drop = FALSE]
            if (!is.null(otutree) && length(rmotus) != treeio::Ntip(otutree)){
                otutree <- treeio::drop.tip(otutree, tip=rmotus)
            }else{
                otutree <- NULL
            }
            if (!is.null(taxatree) && length(rmotus) != treeio::Ntip(taxatree)){
                taxatree <- treeio::drop.tip(taxatree, tip=rmotus, collapse.singles=FALSE)
            }else{
                taxatree <- NULL
            }
        }
    }

    mpse <- MPSE(
                 assays = list(Abundance=otuda),
                 colData = sampleda,
                 otutree = otutree,
                 taxatree =  taxatree,
                 refseq = refseq
            )

    methods::validObject(mpse)
    return(mpse)
}

.build_ps <- function(res){
    if (!is.null(res$otutree)){
        reftree <- res$otutree@phylo
    }else{
        reftree <- NULL
    }
    ps <- phyloseq::phyloseq(
          phyloseq::otu_table(res$otutab,taxa_are_rows=TRUE),
          phyloseq::sample_data(res$sampleda, FALSE),
          phyloseq::tax_table(as.matrix(res$taxatab), FALSE),
          phyloseq::phy_tree(reftree, FALSE),
          phyloseq::refseq(res$refseq, FALSE)
      )
    return(ps)
}

read_qiime_otu <- function(otufilename){
    skipn <- guess_skipnum(otufilename)
    xx <- utils::read.table(otufilename, sep="\t", skip=skipn, header=TRUE, 
                            row.names=1, comment.char="", quote="")
    indy <- vapply(xx, function(i)is.numeric(i), logical(1)) %>% setNames(NULL)
    otuda <- xx[, indy, drop=FALSE]
    if (!all(indy)){
        taxada <- xx[, !indy, drop=FALSE]
        taxada <- apply(taxada, 2, function(i)gsub(";\\s+", ";", i)) %>% 
                  data.frame() %>%
                  split_str_to_list(sep=";") %>% 
                  fillNAtax() %>% 
                  setNames(taxaclass[seq_len(ncol(.))])
    }else{
        taxada <- NULL
    }
    return(list(otuda=otuda, taxada=taxada))
}

taxaclass <- c("Kingdom", 
               "Phylum", 
               "Class", 
               "Order", 
               "Family", 
               "Genus", 
               "Speies", 
               "Rank8", 
               "Rank9", 
               "Rank10")

read_qiime_sample <- function(samplefile){
    sep <- guess_sep(samplefile)    
    sampleda <- utils::read.table(samplefile, header=TRUE, sep=sep, row.names=1, comment.char="")
    return(sampleda)
}

remove_na_taxonomy_rank <- function(x){
    x <- as.data.frame(x, check.names=FALSE)
    x <- remove_unclassfied(x) 
    indx <- vapply(x, 
                   function(i)all(is.na(i)),
                   FUN.VALUE=logical(1)) %>% 
            setNames(NULL)
    x <- x[, !indx, drop=FALSE]
    return(x)
}

build_refseq <- function(x){
    flag <- guess_rownames(x)
    refseq <- switch(flag,
                     DNA=Biostrings::DNAStringSet(x),
                     AA=Biostrings::AAStringSet(x),
                     RNA=Biostrings::RNAStringSet(x),
                     Other=NULL
                ) 
    return(refseq)
}

#' @keywords internal
#' this is refer to the seqmagick
guess_rownames <- function(string){
    a <- string
    a <- strsplit(toupper(a), split = "")[[1]]
    freq1 <- mean(a %in% c("A", "C", "G", "T", "X", "N", "-"))
    freq2 <- mean(a %in% c("A", "C", "G", "T", "N"))
    if (freq1 > 0.9 && freq2 > 0) {
        return("DNA")
    }
    freq3 <- mean(a %in% c("A", "C", "G", "U", "X", "N", "-"))
    freq4 <- mean(a %in% c("T"))
    freq5 <- mean(a %in% c("U"))
    freq6 <- mean(a %in% c("0", "1", "2", "3", "4", "5", "6", "7", "8", "9"))
    if (freq3 > 0.9 && freq4 == 0 && freq5 > 0) {
        return("RNA")
    }
    if (freq6 != 0){
        return("Other")
    }
    return("AA")
}

guess_skipnum <- function(otufilename){
    x <- readLines(otufilename, n=50)
    n <- sum(substr(x, 1, 1) == "#") - 1
    return(n)
}

guess_sep <- function(samplefile){
    xx <- readLines(samplefile, n = 8)
    indx <- vapply(strsplit(xx,split=","), function(i)length(i), numeric(1))
    if (all(indx > 1) && var(indx)==0){
        return(",")
    }else{
        return("\t")
    }
}

check_equal_len <- function(x){
   xx <- vapply(x, function(i)length(i), numeric(1))
   return (var(xx) == 0)
}
