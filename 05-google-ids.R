## Google Drive locations for pre-run simulation objects

gdriveURL <- "https://drive.google.com/drive/folders/1pFpAZwFqRIWxAygntEx8rVPV_b2BTqMB/"

gdriveSims <- data.table::fread("05-google-ids.csv")

lvls <- c("simOutPreamble", "biomassMaps2001", "biomassMaps2011", "fSsimDataPrep",
          "ignitionOut", "escapeOut", "spreadOut", "results")
data.table::set(gdriveSims, NULL, "simObject", factor(gdriveSims$simObject, levels = lvls))
data.table::setkeyv(gdriveSims, c("studyArea", "simObject", "runID", "gcm", "ssp"))

update_googleids <- function(x, gdriveSims) {
  gdriveSims_updated <- rbind(gdriveSims, x)
  gdriveSims_updated <- unique(gdriveSims_updated)
  setorder(gdriveSims_updated)
  fwrite(x = gdriveSims_updated, file = "05-google-ids.csv")

  return(gdriveSims_updated)
}
