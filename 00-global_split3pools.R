# project basic setup -------------------------------------------------------------------------

if (file.exists("~/.Renviron")) readRenviron("~/.Renviron") ## GITHUB_PAT
if (file.exists("LandR_CBM.Renviron")) readRenviron("LandR_CBM.Renviron") ## database credentials

.ncores <- min(parallel::detectCores() / 2, 32L) ## default number of CPU cores to use, e.g. for pkg install
.nodename <- Sys.info()[["nodename"]] ## current computer name; used to configure machine-specific settings
.user <- Sys.info()[["user"]] ## current computer username; used to configure user-specific settings

## define project directory - this code expects it is being run from this location
## **do not change the paths defined here**
## if you need to add a machine- or user-specific path, please do so _conditionally_
prjDir <- if (.user == "cboisven") {
  "C:/Celine/github/LandR_CBM"
} else {
  "~/GitHub/LandR_CBM"
}

## ensure script being run from the project directory
stopifnot(identical(normalizePath(prjDir), normalizePath(getwd())))

options(
  Ncpus = .ncores,
  repos = c(CRAN = "https://cran.rstudio.com"),
  Require.RPackageCache = "default" ## will use default package cache directory: `RequirePkgCacheDir()`
)

## This is not needed anymore
# ## work-around for working from PFC...R cannot connect to certain urls
# ## TODO: improve conditional by only using wininet if *at* PFC, not just on a PFC machine
# if ((.Platform$OS.type == "windows") && grepl("[L|W]-VIC", .nodename)) {
#   options("download.file.method" = "wininet")
# }

# install and load packages -------------------------------------------------------------------

## use project-specific location for packages to avoid conflicts with other projects
pkgDir <- file.path(tools::R_user_dir(basename(prjDir), "data"), "packages",
                    version$platform, getRversion()[, 1:2])
dir.create(pkgDir, recursive = TRUE, showWarnings = FALSE)
.libPaths(pkgDir, include.site = FALSE)
message("Using libPaths:\n", paste(.libPaths(), collapse = "\n"))

## package installation only; do not load module packages until after install
if (!"remotes" %in% rownames(installed.packages(lib.loc = .libPaths()[1]))) {
  install.packages("remotes")
}

Require.version <- "PredictiveEcology/Require@development"
if (!"Require" %in% rownames(installed.packages(lib.loc = .libPaths()[1])) ||
    packageVersion("Require", lib.loc = .libPaths()[1]) < "0.2.5") {
  remotes::install_github(Require.version)
}

library(Require)

## temporarily until new Rcpp release on CRAN in early 2023 ----------------------------------------
## this version fixes spurious error triggered in raster/terra
## 'Error in x$.self$finalize() : attempt to apply non-function'
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

setLinuxBinaryRepo() ## setup binary package installation for linux users

Require(c(
  "PredictiveEcology/reproducible@development (>= 1.2.14)",
  "PredictiveEcology/SpaDES.project@transition (>= 0.0.7.9003)", ## TODO: use development once merged
  # "PredictiveEcology/SpaDES.config@development (>= 0.0.2.9040)", ## TODO: use config
  "PredictiveEcology/SpaDES.core@development (>= 1.1.0.9015)"
), upgrade = FALSE, standAlone = TRUE)

modulePkgs <- unname(unlist(packagesInModules(modulePath = file.path(prjDir, "modules"))))
otherPkgs <- c("archive", "details", "DBI", "s-u/fastshp", "logging", "RPostgres", "slackr")

Require(unique(c(modulePkgs, otherPkgs)), require = FALSE, standAlone = TRUE, upgrade = FALSE)

## NOTE: always load packages LAST, after installation above;
##       ensure plyr loaded before dplyr or there will be problems
Require(c("data.table", "plyr", "pryr", "reproducible", "SpaDES.core",
          "googledrive", "httr", "magrittr", "sessioninfo", "slackr", "ggforce"),
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

do.call(SpaDES.core::setPaths, paths) ## set project paths for simulation

# project options -----------------------------------------------------------------------------

## TODO: use config
# opts <- SpaDES.config::setProjectOptions(config)

quickPlot::dev.useRSGD(useRSGD = quickPlot::isRstudioServer())

# SpaDES.config::authGoogle(tryToken = "western-boreal-initiative", tryEmail = config$args[["cloud"]][["googleUser"]])

# begin simulations ---------------------------------------------------------------------------

## Study area RTM

RIArtm <- Cache(prepInputs,
                url = "https://drive.google.com/file/d/1h7gK44g64dwcoqhij24F2K54hs5e35Ci",
                destinationPath = paths[["inputPath"]])

## TODO: I think there needs to be this as a parameter for this module?
#idCols <- c(“pixelGroup”, “cohort_id”)
# this would need to trickle through the module

# this is not working for me
# options(spades.moduleCodeChecks = FALSE, ## don't turn this off during development; use TRUE
#         spades.recoveryMode = FALSE)
# if (any(Sys.info()[["user"]] %in% c("cboisven", "cboisvenue"))) {
#   Require("googledrive")
#   options(
#     gargle_oauth_cache = ".secrets",
#     gargle_oauth_email = "cboisvenue@gmail.com"
#   ) ## you shouldn't need this unless you have a custom gargle/googledrive setup - config can deal with this
# }

objects <- list(rasterToMatch = RIArtm)
times <- list(start = 0, end = 350)

parameters <- list(
  LandRCBM_split3pools = list(.useCache = ".inputObjects")
)

modules <- list("LandRCBM_split3pools")

# All the action is here
split3poolsOut <- simInitAndSpades(
  times = times,
  params = parameters,
  modules = modules,
  objects = objects,
  debug = TRUE#,
  #paths = paths
)

