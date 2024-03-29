.starttime <- Sys.time()

if (file.exists(".Renviron")) readRenviron(".Renviron")

Require::Require("config")

cacheDir <- config::get("paths")[["cachedir"]]
cacheFormat <- config::get("cacheformat")
climateGCM <- config::get("climategcm")
climateSSP <- as.numeric(config::get("climatessp"))
cloudCacheFolderID <- config::get("cloud")[["cachedir"]]
codeChecks <- config::get("codechecks")
delayStart <- config::get("delaystart")
messagingNumCharsModule <- config::get("messagingNumCharsModule")
newGoogleIDs <- FALSE ## gets rechecked/updated for each script (06, 07x, 08x) based on script 05
nReps <- config::get("nreps")
reproducibleAlgorithm <- config::get("reproduciblealgorithm")
reupload <- config::get("reupload")
run <- config::get("run")
scratchDir <- config::get("paths")[["scratchdir"]]
studyAreaName <- config::get("studyarea")
if (studyAreaName == "NU") studyAreaName <- "NT" ## NU and NT are joined
useCloudCache <- config::get("cloud")[["usecloud"]]
useLandR.CS <- config::get("uselandrcs")
useMemoise <- config::get("usememoise")
usePlot <- config::get("plot")
userInputPaths <- config::get("inputpaths")
usePrerun <- config::get("useprerun")
useRequire <- config::get("userequire")
.plotInitialTime <- if (isTRUE(usePlot)) 2011 else NA

if (!exists("runName")) {
  runName <- sprintf("%s_%s_SSP%03d_run%02d", studyAreaName, climateGCM, climateSSP, run)
} else {
  chunks <- strsplit(runName, "_")[[1]]
  climateSSP <- substr(chunks[length(chunks) - 1], 4, 6)
  climateGCM <- if (grepl("ensemble", runName)) paste0(chunks[2], "_", chunks[3]) else chunks[2]
  studyAreaName <- chunks[1]
  run <- as.numeric(substr(chunks[length(chunks)], 4, 5))
}

firstRunMDCplots <- if (run == 1) TRUE else FALSE
firstRunIgnitionFit <- if (run == 1) TRUE else FALSE
