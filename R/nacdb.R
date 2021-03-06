#' Builds a community database
#'
#' The key function of the nacdb package. When run with defaults, it
#' will download and build a database of species' traits from all the
#' manuscript sources in the package. This totals XXX
#' manuscripts/databases, XXX species, and XXX traits. Please note
#' that all parameters are interactive; thus specifying \code{species}
#' and \code{traits} constraints will constraint according to both,
#' for example. Please also note that specifying any kind of
#' constraints makes use of the package's built-in cache of what
#' species and traits information are available in each database;
#' making use of this on the GitHub (developer) build of this package
#' is not advisable, and (further) it is impossible for us to verify
#' whether the datasets NATDB searches have been updated since the
#' package was last built.
#' 
#' @param datasets Character vector of datasets to be searched for
#'     trait data. If not specified (the default) all trait datasets
#'     will be downloaded and returned.
#' @param cache Folder where cached downloads are stored
#' @param delay How long to wait between downloads (to save server
#'     overload); default is 5 seconds.
#' @return nacdb.data object. XXX
#' @author Will Pearse; Bodie; etc.
#' #@examples
#' # Limit the scope of these as they have to work online on servers!...
#' #@seealso 
#' @export
#' @importFrom gdata ls.funs
nacdb <- function(cache, datasets, delay=5){
    #Check datasets
    if(missing(datasets)){
        datasets <- Filter(Negate(is.function), ls(pattern="^\\.[a-z]*\\.[0-9]+", name="package:nacdb", all.names=TRUE))
    } else {
        datasets <- paste0(".", tolower(datasets))
        datasets <- gsub("..", ".", datasets, fixed=TRUE)
    }
    if(!all(datasets %in% datasets)){
        missing <- setdiff(datasets, ls.funs())
        stop("Error: ", paste(missing, collapse=", "), "not in nacdb")
    }
    
    #Do data loads
    output <- vector("list", length(datasets))
    for(i in seq_along(datasets)){
        prog.bar(i, length(datasets))
        if(!missing(cache)){
            if(!file.exists(cache))
                stop("Cache directory does not exist")
            path <- file.path(cache,paste0(datasets[i], ".RDS"))
        } else path <- NA
        if(!is.na(path) && file.exists(path)){
            output[[i]] <- readRDS(path)
            next()
        }
        if(FALSE){
            output[[i]] <- eval(as.name(datasets[i]))()
        
        output[[i]]$data$study <- datasets[i]
        output[[i]]$spp.metadata$study <- datasets[i]
        output[[i]]$site.metadata$study <- datasets[i]
        output[[i]]$study.metadata$study <- datasets[i]
        output[[i]]$data$site.id <- paste0(output[[i]]$data$site.id,datasets[i])
        output[[i]]$site.metadata$id <- paste0(output[[i]]$site.metadata$id,datasets[i])
        
        if(!is.na(path))
            saveRDS(output[[i]], path)
            Sys.sleep(delay)
        }
        
    }

    output <- output[!is.na(output)]
    
    # Merge data and return
    output <- list(
        data=do.call(rbind, lapply(output, function(x) x$data)),
        spp.metadata=do.call(rbind, lapply(output, function(x) x$spp.metadata)),
        site.metadata=do.call(rbind, lapply(output, function(x) x$site.metadata)),
        study.metadata=do.call(rbind, lapply(output, function(x) x$study.metadata))
    )
    class(output) <- "nacdb"
    return(output)
}

print.nacdb <- function(x, ...){
    # Argument handling
    if(!inherits(x, "nacdb"))
        stop("'", deparse(substitute(x)), "' must be of type 'nacdb'")
    
    # Create a simple summary matrix of species and sites in x
    n.species <- length(unique(species(x)))
    n.sites <- length(unique(sites(x)))
    n.total <- nrow(x$data)
    
    # Print it to screen
    cat("\nA Community DataBase containing:\nSpecies  : ", n.species, "\nSites    : ", n.sites, "\nTotal    : ", n.total,"\n")
    invisible(setNames(c(n.species,n.sites), c("n.species","n.sites")))
}

summary.nacdb <- function(x, ...){
    print.nacdb(x, ...)
}

"[.nacdb" <- function(x, sites, spp){
    # Argument handling
    if(!inherits(x, "nacdb"))
        stop("'", deparse(substitute(x)), "' must be of type 'nacdb'")

    # Setup null output in case of no match
    null <- list(
        data=data.frame(species=NA,site.id=NA,value=NA),
        study.metadata=data.frame(units=NA,other=NA),
        site.metadata=data.frame(id=NA,year=NA,name=NA,lat=NA,long=NA,address=NA,other=NA),
        spp.metadata=data.frame(species=NA, taxonomy=NA, other=NA)
    )
    class(null) <- "nacdb"

    # Site subsetting
    if(!missing(sites)){
        if(any(x$site.metadata$id %in% sites)){
            x$data <- x$data[x$data$site.id %in% sites,]
            x$spp.metadata <- x$spp.metadata[x$spp.metadata$species %in% x$data$species,]
            x$site.metadata <- x$site.metadata[x$site.metadata$id %in% sites,]
            x$study.metadata <- x$study.metadata[x$study.metadata$study %in% x$data$study,]
        } else {
            return(null)
        }
    }
    
    # Species subsetting
    if(!missing(spp)){
        if(any(x$spp.metadata$species %in% spp)){
            x$data <- x$data[x$data$species %in% spp,]
            x$spp.metadata <- x$spp.metadata[x$spp.metadata$species %in% spp,]
            x$site.metadata <- x$site.metadata[x$site.metadata$id %in% x$data$site,]
            x$study.metadata <- x$study.metadata[x$study.metadata$study %in% x$data$study,]
        } else {
            return(null)
        }
    }

    # Return (already checked for null case)
    return(x)
}

species <- function(x, ...){
    if(!inherits(x, "nacdb"))
        stop("'", deparse(substitute(x)), "' must be of type 'nacdb'")
    return(unique(x$spp.metadata$species))
    # Return a vector of the sites in nacdb (?)
}

sites <- function(x, ...){
    if(!inherits(x, "nacdb"))
        stop("'", deparse(substitute(x)), "' must be of type 'nacdb'")
    return(unique(x$site.metadata$id))
}

citations <- function(x){
    if(!inherits(x, "nacdb"))
        stop("'", deparse(substitute(x)), "' must be of type 'nacdb'")
    
    data(nacdb_citations)
    datasets <- Filter(Negate(is.function), ls(pattern="^\\.[a-z]*\\.[0-9]+[a-d]?", name="package:nacdb", all.names=TRUE))
    nacdb.citations$Name <- with(nacdb.citations, paste0(".", tolower(Author), ".", Year))

    return(as.character(nacdb.citations$BibTeX.citation[match(datasets, nacdb.citations$Name)]))
}

# I added this during ARGON, and while it's useful I think I need to
# think a little more coherently abotu how to let users interact with
# study-level meta-data
if(FALSE){
    #' @method subset nacdb
    #' @export
    subset.study <- function(x, studies, ...){
        if(!inherits(x, "nacdb"))
            stop("'", deparse(substitute(x)), "' must be of type 'nacdb'")

        x$data <- x$data[x$data$study %in% studies,]
        x$spp.metadata <- x$spp.metadata[x$spp.metadata$study %in% studies,]
        x$site.metadata <- x$site.metadata[x$site.metadata$study %in% studies,]
        x$study.metadata <- x$study.metadata[x$study.metadata$study %in% studies,]

        return(x)
    }
}
