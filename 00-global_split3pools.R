# project basics ------------------------------------------------------------------------------

if (file.exists("~/.Renviron")) readRenviron("~/.Renviron") ## GITHUB_PAT
if (file.exists("LandR_CBM.Renviron")) readRenviron("LandWeb.Renviron") ## database credentials

.ncores <- min(parallel::detectCores() / 2, 32L)
.nodename <- Sys.info()[["nodename"]]
.starttime <- Sys.time()
.user <- Sys.info()[["user"]]

prjDir <- "~/GitHub/LandR_CBM"

stopifnot(identical(normalizePath(prjDir), normalizePath(getwd())))

options(
  Ncpus = .ncores,
  repos = c(CRAN = "https://cran.rstudio.com"),
  Require.RPackageCache = "default" ## will use default package cache directory: `RequirePkgCacheDir()`
)

## this is a work-around for working from PFC...R cannot connect to URL
## TODO: improve conditional by only using wininet if *at* PFC, not just on a PFC machine
if ((.Platform$OS.type == "windows") && grepl("[L|W]-VIC", .nodename)) {
  options("download.file.method" = "wininet")
}

# install and load packages -------------------------------------------------------------------

pkgDir <- file.path(tools::R_user_dir(basename(prjDir), "data"), "packages",
                    version$platform, getRversion()[, 1:2])
dir.create(pkgDir, recursive = TRUE, showWarnings = FALSE)
.libPaths(pkgDir, include.site = FALSE)
message("Using libPaths:\n", paste(.libPaths(), collapse = "\n"))

### In this section, only load the minimum of packages (Require, SpaDES.install)
#so all packages can be installed with correct version numbering. If we load a
#package too early and it is an older version that what may be required by a
#module, then we get an inconsistency

if (!"remotes" %in% rownames(installed.packages(lib.loc = .libPaths()[1]))) {
  install.packages("remotes")
}

Require.version <- "PredictiveEcology/Require@development"
if (!"Require" %in% rownames(installed.packages(lib.loc = .libPaths()[1])) ||
    packageVersion("Require", lib.loc = .libPaths()[1]) < "0.2.4.9003") {
  remotes::install_github(Require.version)
}

library(Require)

## temporarily until new Rcpp release on CRAN in early 2023 ----------------------------------------
options("Require.otherPkgs" = setdiff(getOption("Require.otherPkgs"), "Rcpp")) ## remove Rcpp from "forced source"
RcppVersionNeeded <- package_version("1.0.9.3")

RcppVersionAvail <- if (!"Rcpp" %in% rownames(installed.packages(lib.loc = .libPaths()[1]))) {
  package_version(data.table::as.data.table(available.packages())[Package == "Rcpp", Version])
} else {
  package_version(packageVersion("Rcpp", lib.loc = .libPaths()[1]))
}

if (RcppVersionAvail < RcppVersionNeeded) {
  Require(paste0("Rcpp (>= ", RcppVersionNeeded, ")"),  repos = "https://rcppcore.github.io/drat",
          require = FALSE, verbose = 1)
}
## end temporary Rcpp

setLinuxBinaryRepo()

Require(c(
  "PredictiveEcology/SpaDES.project@transition (>= 0.0.7.9003)", ## TODO: use development once merged
  # "PredictiveEcology/SpaDES.config@development (>= 0.0.2.9040)", ## TODO: use config
  "PredictiveEcology/SpaDES.core@development (>= 1.1.0.9004)"
), upgrade = FALSE, standAlone = TRUE)

modulePkgs <- unname(unlist(packagesInModules(modulePath = file.path(prjDir, "modules"))))
otherPkgs <- c("archive", "details", "DBI", "s-u/fastshp", "logging", "RPostgres", "slackr")

Require(unique(c(modulePkgs, otherPkgs)), require = FALSE, standAlone = TRUE, upgrade = FALSE)

## NOTE: always load packages LAST, after installation above;
##       ensure plyr loaded before dplyr or there will be problems
Require(c("data.table", "plyr", "pryr", "SpaDES.core",
          "googledrive", "httr", "magrittr", "sessioninfo", "slackr"),
        upgrade = FALSE, standAlone = TRUE)

# configure project ---------------------------------------------------------------------------

## TODO: Alex to create config and update this section

# project paths -------------------------------------------------------------------------------

paths <- list(
  cachePath = "cache",
  inputPath = "inputs",
  modulePath = "modules",
  outputPath = "outputs",
  scratchPath = file.path(dirname(tempdir()), "scratch", "LandR_CBM")
) ## TODO: use config

# project options -----------------------------------------------------------------------------

## TODO: use config
# opts <- SpaDES.config::setProjectOptions(config)

quickPlot::dev.useRSGD(useRSGD = quickPlot::isRstudioServer())

# SpaDES.config::authGoogle(tryToken = "western-boreal-initiative", tryEmail = config$args[["cloud"]][["googleUser"]])

# begin simulations ---------------------------------------------------------------------------

do.call(SpaDES.core::setPaths, paths)

## Study area RTM

RIArtm <- Cache(prepInputs,
                url = "https://drive.google.com/file/d/1h7gK44g64dwcoqhij24F2K54hs5e35Ci",
                destinationPath = paths[["inputPath"]])
##TODO
### I think there needs to be this as a parameter for this module?
#idCols <- c(“pixelGroup”, “cohort_id”)
# this would need to trickly through the module

# this is not working for me
# options(spades.moduleCodeChecks = FALSE,
#         spades.recoveryMode = FALSE)
# if (any(Sys.info()[["user"]] %in% c("cboisven", "cboisvenue"))) {
#   Require("googledrive")
#   options(
#     gargle_oauth_cache = ".secrets",
#     gargle_oauth_email = "cboisvenue@gmail.com"
#   )
# }

objects <- list(rasterToMatch = RIArtm)
times <- list(start = 0, end = 350)

parameters <- list(
  LandRCBM_split3pools = list(.useCache = ".inputObjects")
)

modules <- list("LandRCBM_split3pools")

# All the action is here
split3poolsInit <- simInit(
  times = times,
  params = parameters,
  modules = modules,
  objects = objects
)


# # Extras not used, for plotting some things
# if (FALSE) {
#   cd1 <- cds[pixelGroup %in% sample(cds$pixelGroup, size = 49)]
#   cd1 <- rbindlist(list(cd1, cd1[, list(speciesCode = "Total", B = sum(B)), by = c("age", "pixelGroup")]), use.names = TRUE)
#   ggplot(cd1, aes(age, B, colour = speciesCode)) + facet_wrap(~pixelGroup) + geom_line() + theme_bw()
#
#   domAt100 <- cds[age == 100, speciesCode[which.max(B)], by = "pixelGroup"]
#   domAt200 <- cds[age == 200, speciesCode[which.max(B)], by = "pixelGroup"]
#   domAt300 <- cds[age == 300, speciesCode[which.max(B)], by = "pixelGroup"]
#
#   ageWhoIsDom <- cds[, B[which.max(B)]/sum(B), by = c("age", "pixelGroup")]
#   sam <- sample(seq(NROW(ageWhoIsDom)), size = NROW(ageWhoIsDom)/100)
#   ageWhoIsDom2 <- ageWhoIsDom[sam]
#   ggplot(ageWhoIsDom2, aes(age, V1)) + geom_line() + theme_bw() + geom_smooth()
#
#   ageWhoIsDom2 <- ageWhoIsDom[sam, mean(V1), by = "age"]
#   ggplot(ageWhoIsDom2, aes(age, V1)) + geom_line() + theme_bw() + geom_smooth()
#
#   giForCBM <- data.table::fread("growth_increments.csv")
#
# }
#
