## NOTE: 07a-dataPrep_2001.R and 07b-dataPrep_2011.R need to be run before this script

gid_fSsimDataPrep <- gdriveSims[studyArea == studyAreaName & simObject == "fSsimDataPrep", gid]
upload_fSsimDataPrep <- reupload | length(gid_fSsimDataPrep) == 0

fSdataPrepParams <- list(
  fireSense_dataPrepFit = list(
    ".studyAreaName" = studyAreaName,
    ".useCache" = ".inputObjects",
    "climateGCM" = climateGCM,
    "climateSSP" = climateSSP,
    "fireYears" = 2001:2020, # this will be fixed to post kNN only
    "sppEquivCol" = simOutPreamble$sppEquivCol,
    "useCentroids" = TRUE,
    "whichModulesToPrepare" = c("fireSense_IgnitionFit", "fireSense_EscapeFit", "fireSense_SpreadFit")
  )
)

simOutPreamble$rasterToMatch <- raster::mask(simOutPreamble$rasterToMatch, simOutPreamble$studyArea)
fSdataPrepObjects <- list(
  .runName = runName,
  cohortData2001 = biomassMaps2001[["cohortData"]],
  cohortData2011 = biomassMaps2011[["cohortData"]],
  historicalClimateRasters = simOutPreamble[["historicalClimateRasters"]],
  pixelGroupMap2001 = biomassMaps2001[["pixelGroupMap"]],
  pixelGroupMap2011 = biomassMaps2011[["pixelGroupMap"]],
  rasterToMatch = simOutPreamble[["rasterToMatch"]], ## this needs to be masked
  rstLCC = biomassMaps2011[["rstLCC"]],
  sppEquiv = as.data.table(simOutPreamble[["sppEquiv"]]),
  standAgeMap2001 = biomassMaps2001[["standAgeMap"]],
  standAgeMap2011 = biomassMaps2011[["standAgeMap"]],
  studyArea = simOutPreamble[["studyArea"]]
)

invisible(replicate(10, gc()))

ffSsimDataPrep <- file.path(Paths$outputPath, paste0("fSsimDataPrep_", studyAreaName, ".qs"))
if (isTRUE(usePrerun) & isFALSE(upload_fSsimDataPrep)) {
  if (!file.exists(ffSsimDataPrep)) {
    googledrive::drive_download(file = as_id(gid_fSsimDataPrep), path = ffSsimDataPrep)
  }
  fSsimDataPrep <- loadSimList(ffSsimDataPrep)
} else {
  fSsimDataPrep <- Cache(
    simInitAndSpades,
    times =  list(start = 2011, end = 2011),
    params = fSdataPrepParams,
    objects = fSdataPrepObjects,
    paths = dataPrepPaths,
    modules = "fireSense_dataPrepFit",
    .plots = NA,
    #useCloud = useCloudCache,
    #cloudFolderID = cloudCacheFolderID,
    userTags = c("fireSense_dataPrepFit", studyAreaName)
  )
  saveSimList(fSsimDataPrep, ffSsimDataPrep, fileBackend = 2)

  if (isTRUE(upload_fSsimDataPrep)) {
    fdf <- googledrive::drive_put(media = ffSsimDataPrep, path = gdriveURL, name = basename(ffSsimDataPrep))
    gid_fSsimDataPrep <- as.character(fdf$id)
    rm(fdf)
    gdriveSims <- update_googleids(
      data.table(studyArea = studyAreaName, simObject = "fSsimDataPrep",  runID = NA,
                 gcm = NA, ssp = NA, gid = gid_fSsimDataPrep),
      gdriveSims
    )
  }

  source("R/upload_spreadFit_coeffs.R")
}

if (isTRUE(firstRunMDCplots)) {
  stopifnot(packageVersion("fireSenseUtils") >= "0.0.4.9082") ## compareMDC() now in fireSenseUtils
  ggMDC <- fireSenseUtils::compareMDC(
    historicalMDC = simOutPreamble$historicalClimateRasters$MDC,
    projectedMDC = simOutPreamble$projectedClimateRasters$MDC,
    flammableRTM = fSsimDataPrep$flammableRTM
  )
  fggMDC <- file.path(dataPrepPaths$outputPath, "figures", paste0("compareMDC_", studyAreaName, "_",
                                                                  climateGCM, "_", climateSSP, ".png"))
  checkPath(dirname(fggMDC), create = TRUE)

  ggplot2::ggsave(plot = ggMDC, filename = fggMDC)

  googledrive::drive_put(
    media = fggMDC,
    path = unique(as_id(gdriveSims[studyArea == studyAreaName & simObject == "results", gid])),
    name = basename(fggMDC)
  )
}
