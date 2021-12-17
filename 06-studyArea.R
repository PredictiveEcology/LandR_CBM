do.call(setPaths, preamblePaths)

gid_preamble <- gdriveSims[studyArea == studyAreaName & simObject == "simOutPreamble" &
                             gcm == climateGCM & ssp == climateSSP, gid]
upload_preamble <- reupload | length(gid_preamble) == 0

preambleObjects <- list(
  .runName = runName
)

preambleParams <- list(
  WBI_dataPrep_studyArea = list(
    ".useCache" = TRUE,
    "climateGCM" = climateGCM,
    "climateSSP" = climateSSP,
    "historicalFireYears" = 1991:2020,
    "studyAreaName" = studyAreaName
  )
)

fsimOutPreamble <- simFile(paste0("simOutPreamble_", studyAreaName, "_", climateGCM, "_", climateSSP), Paths$outputPath, ext = "qs")
if (isTRUE(usePrerun) & isFALSE(upload_preamble)) {
  if (!file.exists(fsimOutPreamble)) {
    googledrive::drive_download(file = as_id(gid_preamble), path = fsimOutPreamble)
  }
  simOutPreamble <- loadSimList(fsimOutPreamble)
} else {
  simOutPreamble <- Cache(simInitAndSpades,
                          times = list(start = 0, end = 1),
                          params = preambleParams,
                          modules = c("WBI_dataPrep_studyArea"),
                          objects = preambleObjects,
                          paths = preamblePaths,
                          #useCache = "overwrite",
                          #useCloud = useCloudCache,
                          #cloudFolderID = cloudCacheFolderID,
                          userTags = c("WBI_dataPrep_studyArea", studyAreaName)
  )
  saveSimList(sim = simOutPreamble, filename = fsimOutPreamble, fileBackend = 2)

  if (isTRUE(upload_preamble)) {
    fdf <- googledrive::drive_put(media = fsimOutPreamble, path = gdriveURL, name = basename(fsimOutPreamble))
    gid_preamble <- as.character(fdf$id)
    rm(fdf)
    gdriveSims <- update_googleids(
      data.table(studyArea = studyAreaName, simObject = "simOutPreamble", runID = NA,
                 gcm = climateGCM, ssp = climateSSP, gid = gid_preamble),
      gdriveSims
    )
  }
}

nSpecies <- length(unique(simOutPreamble$sppEquiv$LandR))
