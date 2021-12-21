do.call(setPaths, dataPrepPaths)

gid_cbmDataPrep <- gdriveSims[studyArea == studyAreaName & simObject == "cbmDataPrep", gid]
upload_cbmDataPrep <- reupload | length(gid_cbmDataPrep) == 0

cbmDataPrepParams <- list(
  CBM_dataPrep_RIAfri = list( ## TODO: confirm which dataPrep module to use
    .useCache = TRUE
  )
)

cbmDataPrepObjects <- list(
  .runName = runName
)

fcbmDataPrep <- file.path(Paths$outputPath, paste0("cbmDataPrep_", studyAreaName, ".qs"))
if (isTRUE(usePrerun) & isFALSE(upload_cbmDataPrep)) {
  if (!file.exists(fcbmDataPrep)) {
    googledrive::drive_download(file = as_id(gid_cbmDataPrep), path = fcbmDataPrep)
  }
  cbmDataPrep <- loadSimList(fcbmDataPrep)
} else {
  cbmDataPrep <- Cache(
    simInitAndSpades,
    times = list(start = 2011, end = 2011), ## TODO: confirm initial year
    params = cbmDataPrepParams,
    modules = "CBM_dataPrep_RIAfri", ## TODO: confirm which dataPrep module to use
    objects = dataPrepObjects,
    paths = getPaths(),
    .plots = NA,
    useCloud = useCloudCache,
    cloudFolderID = cloudCacheFolderID,
    userTags = c("dataPrep2001", studyAreaName)
  )
  saveSimList(cbmDataPrep, fcbmDataPrep, fileBackend = 2)

  if (isTRUE(upload_cbmDataPrep)) {
    fdf <- googledrive::drive_put(media = fcbmDataPrep, path = gdriveURL, name = basename(fcbmDataPrep))
    gid_cbmDataPrep <- as.character(fdf$id)
    rm(fdf)
    gdriveSims <- update_googleids(
      data.table(studyArea = studyAreaName, simObject = "cbmDataPrep", runID = NA,
                 gcm = NA, ssp = NA, gid = gid_cbmDataPrep),
      gdriveSims
    )
  }
}
