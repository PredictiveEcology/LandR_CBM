do.call(setPaths, spreadFitPaths)

gid_spreadOut <- gdriveSims[studyArea == studyAreaName & simObject == "spreadOut" & runID == run, gid]
upload_spreadOut <- reupload | length(gid_spreadOut) == 0

## TODO: remove this workaround
fSsimDataPrep$fireSense_nonAnnualSpreadFitCovariates[[1]] <- as.data.table(fSsimDataPrep$fireSense_nonAnnualSpreadFitCovariates[[1]])

extremeVals <- 4
lowerParamsNonAnnual <- rep(-extremeVals, times = ncol(fSsimDataPrep$fireSense_nonAnnualSpreadFitCovariates[[1]]) - 1)
lowerParamsAnnual <- c(-extremeVals, -extremeVals)
upperParamsNonAnnual <- rep(extremeVals, times = length(lowerParamsNonAnnual))
upperParamsAnnual <- c(0, extremeVals) ## youngAge <= 0
lowerParams <- c(lowerParamsAnnual, lowerParamsNonAnnual)
upperParams <- c(upperParamsAnnual, upperParamsNonAnnual)

## Spread log function bounds

## for logistic3p
# lower <- c(0.22, 0.001, 0.001, lowerParams)
# upper <- c(0.29, 10, 10, upperParams)

lower <- c(0.25, 0.2, 0.1, lowerParams)
upper <- c(0.276, 2, 4, upperParams)
dfT <- cbind(c("lower", "upper"), t(data.frame(lower, upper)))
message("Upper and Lower parameter bounds are:")
Require:::messageDF(dfT)

localHostEndIp <- as.numeric(gsub("spades", "", system("hostname", intern = TRUE)))
if (is.na(localHostEndIp)) {
  localHostEndIp <- switch(peutils::user(),
                           "ieddy" = 97,
                           "emcintir" = 189,
                           "achubaty" = 220)
}

cores <-  if (peutils::user("ieddy")) {
  pemisc::makeIpsForNetworkCluster(ipStart = "10.20.0",
                                   ipEnd = c(97, 189, 220, 106, 217),
                                   availableCores = c(46, 46, 46, 28, 28),
                                   availableRAM = c(500, 500, 500, 250, 250),
                                   localHostEndIp = localHostEndIp,
                                   proc = "cores",
                                   nProcess = length(lower),
                                   internalProcesses = 10,
                                   sizeGbEachProcess = 1)
} else if (peutils::user("achubaty")) {
  if (Sys.info()["nodename"] == "picea.for-cast.ca") {
    c(rep("localhost", 68), rep("pinus.for-cast.ca", 32))
  } else if (grepl("spades", Sys.info()["nodename"])) {
    pemisc::makeIpsForNetworkCluster(ipStart = "10.20.0",
                                     ipEnd = c(106, 217, 213, 220),
                                     availableCores = c(15, 25, 40, 40),
                                     availableRAM = c(250, 250, 500, 500),
                                     localHostEndIp = localHostEndIp,
                                     proc = "cores",
                                     nProcess = length(lower),
                                     internalProcesses = 10,
                                     sizeGbEachProcess = 1)
  }
} else if (peutils::user("emcintir")) {
  pemisc::makeIpsForNetworkCluster(ipStart = "10.20.0",
                                   #ipEnd = c(97, 189, 220, 106, 217),
                                   # ipEnd = c(97, 189, 220, 217),#, 106, 217, 213, 184),
                                   # availableCores = c(46, 46, 46, 28),#, 28, 28, 56, 28),
                                   # availableRAM = c(500, 500, 500, 250),#, 250, 250, 500, 250),
                                   ipEnd = c(106, 217, 213, 220),
                                   availableCores = c(15, 25, 40, 40),
                                   availableRAM = c(250, 250, 500, 500),
                                   # ipEnd = c(213, 189, 97),
                                   # availableCores = c(40, 40, 40),
                                   # availableRAM = c(500, 500, 500),
                                   localHostEndIp = localHostEndIp,
                                   proc = "cores",
                                   nProcess = length(lower),
                                   internalProcesses = 10,
                                   sizeGbEachProcess = 1)
} else {
  rep("localhost", parallel::detectCores() / 2) ## needed even if spreadFit not being run!
}

# NPar <- length(lower)
# NP <- NPar * 10
# initialpop <- matrix(ncol = NPar, nrow = NP)

spreadFitParams <- list(
  fireSense_SpreadFit = list(
    # "cacheId_DE" = paste0("DEOptim_", studyAreaName), # This is NWT DEoptim Cache
    "cloudFolderID_DE" = cloudCacheFolderID,
    "cores" = cores,
    "DEoptimTests" = if (peutils::user("emcintir")) "snll_fs" else c("adTest", "snll_fs"), # Can be one or both of c("adTest", "snll_fs")
    "doObjFunAssertions" = FALSE,
    "iterDEoptim" = if (peutils::user("emcintir")) 300 else 150,
    "iterStep" = if (peutils::user("emcintir")) 300 else 150,
    "iterThresh" = 396L,
    "lower" = lower,
    "maxFireSpread" = max(0.28, upper[1]),
    "mode" = c("fit", "visualize"), ## combo of "debug", "fit", "visualize"
    "NP" = length(cores),
    "objFunCoresInternal" = 1L,
    "objfunFireReps" = 100,
    #"onlyLoadDEOptim" = FALSE,
    "rescaleAll" = TRUE,
    "trace" = 1,
    "SNLL_FS_thresh" = NULL,# NULL means 'autocalibrate' to find suitable threshold value
    "upper" = upper,
    #"urlDEOptimObject" = if (peutils::user("emcintir")) "spreadOut_2021-02-11_Limit4_150_SNLL_FS_thresh_BQS16t" else NULL,
    "useCache_DE" = FALSE,
    "useCloud_DE" = useCloudCache,
    "verbose" = TRUE,
    "visualizeDEoptim" = FALSE,
    ".plot" = FALSE, #TRUE,
    ".plotSize" = list(height = 1600, width = 2000)
  )
)

#spreadOut <- readRDS("spreadOut_2021-03-01_Limit4_300_SNLL_FS_thresh_jF0YfA")
spreadFitObjects <- list(
  fireBufferedListDT = fSsimDataPrep[["fireBufferedListDT"]],
  firePolys = fSsimDataPrep[["firePolys"]],
  fireSense_annualSpreadFitCovariates = fSsimDataPrep[["fireSense_annualSpreadFitCovariates"]],
  fireSense_nonAnnualSpreadFitCovariates = fSsimDataPrep[["fireSense_nonAnnualSpreadFitCovariates"]],
  fireSense_spreadFormula = fSsimDataPrep[["fireSense_spreadFormula"]],
  flammableRTM = fSsimDataPrep[["flammableRTM"]],
  #parsKnown = c(0.272605, 1.722912, 3.389670, -0.829495, 1.228904, -1.604276,
  #              2.696902, 1.371227,   -2.801110,    0.122434),
  # parsKnown = c(0.271751,    1.932499,    0.504548,    1.357870,   -2.614142,
  #               1.376089,    0.877090,   -1.229922,   -1.370468),
  #parsKnown = c(0.254833,    1.699242,    2.247987,    0.335981,    -1.798538,
  #              2.440666,    -0.845427, -2.186069,    1.879606),
  #parsKnown = c(0.28,1.51, -0.27, 1.2, -2.68, 1.72, -0.95, -1.3, 0.12),
  #parsKnown = spreadOut$fireSense_SpreadFitted$meanCoef,
  rasterToMatch = fSsimDataPrep[["rasterToMatch"]],
  spreadFirePoints = fSsimDataPrep[["spreadFirePoints"]],
  studyArea = fSsimDataPrep[["studyArea"]]
)

fspreadOut <- file.path(Paths$outputPath, paste0("spreadOut_", studyAreaName, "_", run, ".qs"))
if (isTRUE(usePrerun) & isFALSE(upload_spreadOut)) {
  if (!file.exists(fspreadOut)) {
    googledrive::drive_download(file = as_id(gid_spreadOut), path = fspreadOut)
  }
  spreadOut <- loadSimList(fspreadOut)
} else {
  spreadOut <- simInitAndSpades(
    times = list(start = 0, end = 1),
    params = spreadFitParams,
    modules = "fireSense_SpreadFit",
    paths = spreadFitPaths,
    objects = spreadFitObjects
  )
  saveSimList(spreadOut, fspreadOut, fileBackend = 2)

  if (isTRUE(upload_spreadOut)) {
    if (!dir.exists(tempdir())) {
      dir.create(tempdir()) ## TODO: why is this dir being removed in the first place?
    }
    fdf <- googledrive::drive_put(media = fspreadOut, path = gdriveURL, name = basename(fspreadOut))
    gid_spreadOut <- as.character(fdf$id)
    rm(fdf)
    gdriveSims <- update_googleids(
      data.table(studyArea = studyAreaName, simObject = "spreadOut", runID = run,
                 gcm = NA, ssp = NA, gid = gid_spreadOut),
      gdriveSims
    )
  }

  source("R/upload_spreadFit.R")

  if (requireNamespace("slackr") & file.exists("~/.slackr")) {
    slackr::slackr_setup()
    slackr::slackr_msg(
      paste0("`fireSense_SpreadFit` for `", runName, "` completed on host `", Sys.info()[["nodename"]], "`."),
      channel = config::get("slackchannel"), preformatted = FALSE
    )
  }
}
