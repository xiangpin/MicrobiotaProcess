#'  Permutational Multivariate Analysis of Variance Using Distance Matrices for MPSE or tbl_mpse object
#' @rdname mp_adonis-methods
#' @param .data MPSE or tbl_mpse object
#' @param .abundance the name of abundance to be calculated.
#' @param .formula Model formula right hand side gives the continuous variables 
#' or factors, and keep left empty, such as ~ group, it is required.
#' @param distmethod character the method to calculate pairwise distances, 
#' default is 'bray'.
#' @param action character "add" joins the cca result to the object, "only" return
#' a non-redundant tibble with the cca result. "get" return 'cca' object can
#' be analyzed using the related vegan funtion.
#' @param permutations the number of permutations required, default is 999.
#' @param seed a random seed to make the adonis analysis reproducible, default is 123.
#' @param ... additional parameters see also 'adonis' of vegan.
#' @return update object according action argument
#' @export
setGeneric("mp_adonis", function(.data, .abundance, .formula, distmethod="bray", action="get", permutations=999, seed=123, ...)standardGeneric("mp_adonis"))

.internal_cal_adonis <- function(.data, .abundance, .formula, distmethod="bray", action="get", permutations=999, seed=123, ...){

    action %<>% match.arg(c("add", "only", "get"))

    if (missing(.formula)){
        rlang::abort("The .formula is required, with no default")
    }

    .abundance <- rlang::enquo(.abundance)

    if (distmethod %in% distMethods$vegdist ){

        x <- .data %>% mp_extract_abundance(.abundance=!!.abundance, byRow=FALSE)

        sampleda <- .data %>%
                    mp_extract_sample() %>%
                    dplyr::arrange(match(rownames(x), !!as.symbol("Sample"))) %>%
                    tibble::column_to_rownames(var="Sample")        

        .formula <- paste0(c("x", .formula), collapse=" ") %>% as.formula()

        res <- withr::with_seed(seed, vegan::adonis(.formula, data=sampleda, method=distmethod, permutations=permutations, ...))

    }else{
        if(! distmethod %in% colnames(.data %>% mp_extract_sample())){
            if (rlang::quo_is_missing(.abundance)){
                rlang::abort("The .abundance must be required, when the distmethod is not present in the object.")
            }else{
                .data %<>% mp_cal_dist(.abundance=!!.abundance, distmethod=distmethod, action="add")
            }
        }
        
        distobj <- .data %>% 
                   mp_extract_dist(distmethod=distmethod) %>%
                   as.matrix()

        sampleda <- .data %>%
                    mp_extract_sample() %>%
                    dplyr::arrange(match(rownames(distobj), !!as.symbol("Sample"))) %>%
                    tibble::column_to_rownames(var="Sample")        

        .formula <- paste0(c("distobj", .formula), collapse=" ") %>% as.formula()
        res <- withr::with_seed(seed, vegan::adonis(.formula, data=sampleda, permutations=permutations, ...))
    }

    if (action == "get"){
        return(res)
    }else if(action == "only"){
        da <- mp_fortify(res)
        return(da)
    }else{
        message("The result of adonis has been saved to the internal attribute !")
        message("It can be extracted using this-object %>% mp_extract_internal_attr(name='adonis')")
        .data %<>%
            add_internal_attr(object=res, name="ADONIS")
        return(.data)
    }

}

#' @rdname mp_adonis-methods
#' @aliases mp_adonis,MPSE
#' @exportMethod mp_adonis
setMethod("mp_adonis", signature(.data="MPSE"), .internal_cal_adonis)

#' @rdname mp_adonis-methods
#' @aliases mp_adonis,tbl_mpse
#' @exportMethod mp_adonis
setMethod("mp_adonis", signature(.data="tbl_mpse"), .internal_cal_adonis)

#' @rdname mp_adonis-methods
#' @aliases mp_adonis,grouped_df_mpse
#' @exportMethod mp_adonis
setMethod("mp_adonis", signature(.data="grouped_df_mpse"), .internal_cal_adonis)


#' Analysis of Similarities (ANOSIM) with MPSE or tbl_mpse object
#' @rdname mp_anosim-methods
#' @param .data MPSE or tbl_mpse object
#' @param .abundance the name of abundance to be calculated.
#' @param .group The name of the column of the sample group information.
#' @param distmethod character the method to calculate pairwise distances,
#' default is 'bray'.
#' @param action character "add" joins the ANOSIM result to internal attribute of 
#' the object, "only" and "get" return 'anosim' object can be analyzed using the 
#' related vegan funtion.
#' @param permutations the number of permutations required, default is 999.
#' @param seed a random seed to make the ANOSIM analysis reproducible, default is 123.
#' @param ... additional parameters see also 'anosim' of vegan.
#' @return update object according action argument
#' @export
setGeneric("mp_anosim", function(.data, .abundance, .group, distmethod="bray", action="add", permutations=999, seed=123, ...)standardGeneric("mp_anosim"))

.internal_cal_anosim_mrpp <- function(.data, .abundance, .group, distmethod="bray", action="add", permutations=999, seed=123, method="anosim", ...){

    action %<>% match.arg(c("add", "get", "only"))
   
    .abundance <- rlang::enquo(.abundance)
    .group <- rlang::enquo(.group)

    defun <- switch(method,
                    anosim = vegan::anosim,
                    mrpp   = vegan::mrpp)

    sampleda <- .data %>%
                mp_extract_sample() %>%
                select(c(!!as.symbol("Sample"), !!.group)) 

    if (distmethod %in% distMethods$vegdist ){
        x <- .data %>% mp_extract_abundance(.abundance=!!.abundance, byRow=FALSE)

        sampleda %<>% dplyr::arrange(match(rownames(x), !!as.symbol("Sample"))) %>%
                      pull(!!.group)

        res <- withr::with_seed(seed, defun(x, grouping=sampleda, distance=distmethod, permutations=permutations, ...))

    }else{
        if(! distmethod %in% colnames(.data %>% mp_extract_sample())){
            if (rlang::quo_is_missing(.abundance)){
                rlang::abort("The .abundance must be required, when the distmethod is not present in the object.")
            }else{
                .data %<>% mp_cal_dist(.abundance=!!.abundance, distmethod=distmethod, action="add")
            }
        }

        distobj <- .data %>%
                   mp_extract_dist(distmethod=distmethod) %>%
                   as.matrix()

        sampleda %<>% dplyr::arrange(match(rownames(distobj), !!as.symbol("Sample"))) %>%
                      pull(!!.group)

        res <- withr::with_seed(seed, defun(distobj, grouping=sampleda, permutations=permutations, ...))
    }

    if (action == "get"){
        return(res)
    }else if (action=="only"){
        da <- mp_fortify(res, verbose=TRUE)
        return(da)
    }else{
        resname <- switch(method,
                          anosim = "anosim",
                          mrpp   = "mrpp")
        message(paste0("The result of ", resname," has been integrated to the internal attribute !"))
        message(paste0("It can be extracted using this-object %>% mp_extract_internal_attr(name='",resname,"')"))
        .data %<>%
            add_internal_attr(object=res, name=resname)
        return(.data)
    }

}

#' @rdname mp_anosim-methods
#' @aliases mp_anosim,MPSE
#' @exportMethod mp_anosim
setMethod("mp_anosim", signature(.data="MPSE"),
    function(.data, .abundance, .group, distmethod="bray", action="add", permutations=999, seed=123, ...){
    res <- .internal_cal_anosim_mrpp(.data=.data, 
                                     .abundance = !!rlang::enquo(.abundance),
                                     .group = !!rlang::enquo(.group),
                                     distmethod = distmethod,
                                     action = action,
                                     permutations = permutations,
                                     seed=seed,
                                     method="anosim",
                                     ...)
    return(res)      
})

#' @rdname mp_anosim-methods
#' @aliases mp_anosim,tbl_mpse
#' @exportMethod mp_anosim
setMethod("mp_anosim", signature(.data="tbl_mpse"), 
    function(.data, .abundance, .group, distmethod="bray", action="add", permutations=999, seed=123, ...){
    res <- .internal_cal_anosim_mrpp(.data=.data,
                                     .abundance = !!rlang::enquo(.abundance),
                                     .group = !!rlang::enquo(.group),
                                     distmethod = distmethod,
                                     action = action,
                                     permutations = permutations,
                                     seed=seed,
                                     method="anosim",
                                     ...)
    return(res)
})

#' @rdname mp_anosim-methods
#' @aliases mp_anosim,grouped_df_mpse
#' @exportMethod mp_anosim
setMethod("mp_anosim", signature(.data="grouped_df_mpse"), 
    function(.data, .abundance, .group, distmethod="bray", action="add", permutations=999, seed=123, ...){
    res <- .internal_cal_anosim_mrpp(.data=.data,
                                     .abundance = !!rlang::enquo(.abundance),
                                     .group = !!rlang::enquo(.group),
                                     distmethod = distmethod,
                                     action = action,
                                     permutations = permutations,
                                     seed=seed,
                                     method="anosim",
                                     ...)
    return(res)
})

#' Analysis of Multi Response Permutation Procedure (MRPP) with MPSE or tbl_mpse object
#' @rdname mp_mrpp-methods
#' @param .data MPSE or tbl_mpse object
#' @param .abundance the name of abundance to be calculated.
#' @param .group The name of the column of the sample group information.
#' @param distmethod character the method to calculate pairwise distances,
#' default is 'bray'.
#' @param action character "add" joins the ANOSIM result to internal attribute of
#' the object, "only" return a tibble contained the statistic information of MRPP 
#' analysis, and "get" return 'mrpp' object can be analyzed using the related vegan 
#' funtion.
#' @param permutations the number of permutations required, default is 999.
#' @param seed a random seed to make the MRPP analysis reproducible, default is 123.
#' @param ... additional parameters see also 'mrpp' of vegan.
#' @return update object according action argument
#' @export
setGeneric("mp_mrpp", function(.data, .abundance, .group, distmethod="bray", action="add", permutations=999, seed=123, ...)standardGeneric("mp_mrpp"))

#' @rdname mp_mrpp-methods
#' @aliases mp_mrpp,MPSE
#' @exportMethod mp_mrpp
setMethod("mp_mrpp", signature(.data="MPSE"),
    function(.data, .abundance, .group, distmethod="bray", action="add", permutations=999, seed=123, ...){
    res <- .internal_cal_anosim_mrpp(.data=.data,
                                     .abundance = !!rlang::enquo(.abundance),
                                     .group = !!rlang::enquo(.group),
                                     distmethod = distmethod,
                                     action = action,
                                     permutations = permutations,
                                     seed=seed,
                                     method="mrpp",
                                     ...)
    return(res)
})

#' @rdname mp_mrpp-methods
#' @aliases mp_mrpp,tbl_mpse
#' @exportMethod mp_mrpp
setMethod("mp_mrpp", signature(.data="tbl_mpse"),
    function(.data, .abundance, .group, distmethod="bray", action="add", permutations=999, seed=123, ...){
    res <- .internal_cal_anosim_mrpp(.data=.data,
                                     .abundance = !!rlang::enquo(.abundance),
                                     .group = !!rlang::enquo(.group),
                                     distmethod = distmethod,
                                     action = action,
                                     permutations = permutations,
                                     seed=seed,
                                     method="mrpp",
                                     ...)
    return(res)
})

#' @rdname mp_mrpp-methods
#' @aliases mp_mrpp,grouped_df_mpse
#' @exportMethod mp_mrpp
setMethod("mp_mrpp", signature(.data="grouped_df_mpse"),
    function(.data, .abundance, .group, distmethod="bray", action="add", permutations=999, seed=123, ...){
    res <- .internal_cal_anosim_mrpp(.data=.data,
                                     .abundance = !!rlang::enquo(.abundance),
                                     .group = !!rlang::enquo(.group),
                                     distmethod = distmethod,
                                     action = action,
                                     permutations = permutations,
                                     seed=seed,
                                     method="mrpp",
                                     ...)
    return(res)
})
