do.call(setPaths, ignitionFitPaths)

gid_ignitionOut <- gdriveSims[studyArea == studyAreaName & simObject == "ignitionOut", gid]
upload_ignitionOut <- reupload | length(gid_ignitionOut) == 0

## ub and lb have to be provided for now

biggestObj <- as.numeric(object.size(fSsimDataPrep[["fireSense_ignitionCovariates"]]))/1e6 * 1.2

if (studyAreaName == "AB") {
  form <- paste0("ignitions ~ youngAge:MDC",
                 " + nonForest_highFlam:MDC",
                 " + nonForest_lowFlam:MDC",
                 " + class2:MDC",
                 " + class3:MDC",
                 " + youngAge:pw(MDC, k_YA)",
                 " + nonForest_lowFlam:pw(MDC, k_NFLF)",
                 " + nonForest_highFlam:pw(MDC, k_NFHF)",
                 " + class2:pw(MDC, k_class2)",
                 " + class3:pw(MDC, k_class3)",
                 " - 1")
  # form <- paste0("ignitions ~ "
  #                , "youngAge "
  #                , "+ nonForest_highFlam "
  #                #"+ nonForest_lowFlam ",
  #                , "+ class2:MDC "
  #                , "+ class3:MDC "
  #                #"youngAge:pw(MDC, k_YA) + ",
  #                #"nonForest_lowFlam:pw(MDC, k_YA) + ",
  #                #"nonForest_highFlam:pw(MDC, k_YA) + ",
  #                , "+ class2:pw(MDC, k_class2) "
  #                # , "+ class3:pw(MDC, k_class3) "
  #                , "- 1"
  #                )
  # form <- paste0("ignitions ~ "
  #                , "MDC + "
  #                #, "youngAge +"
  #                , "+ nonForest_highFlam "
  #                #"+ nonForest_lowFlam ",
  #                , "+ class2:MDC "
  #                , "+ class3:MDC "
  #                #"youngAge:pw(MDC, k_YA) + ",
  #                #"nonForest_lowFlam:pw(MDC, k_YA) + ",
  #                #"nonForest_highFlam:pw(MDC, k_YA) + ",
  #                , "+ class2:pw(MDC, k_class2) "
  #                # , "+ class3:pw(MDC, k_class3) "
  #                , "- 1"
  # )
  #form <- "ignitions ~ youngAge:MDC + MDC:nonForest_highFlam + MDC:class2 + MDC:class3 + class2:pw(MDC, k_class2) -1"
} else {
  form <- fSsimDataPrep[["fireSense_ignitionFormula"]]
}

nCores <- pmin(14, pemisc::optimalClusterNum(biggestObj)/2 - 6)
ignitionFitParams <- list(
  fireSense_IgnitionFit = list(
    # .plotInitialTime = 1,
    .plots = "png",
    cores = nCores,
    fireSense_ignitionFormula = form,
    ## if using binomial need to pass theta to lb and ub
    lb = list(coef = 0,
              knots = list(MDC = round(quantile(fSsimDataPrep$fireSense_ignitionCovariates$MDC,
                                                probs = 0.05), digits = 0))),
    ub = list(coef = 20,
              knots = list(MDC = round(quantile(fSsimDataPrep$fireSense_ignitionCovariates$MDC,
                                                probs = 0.8), digits = 0))),
    family = quote(MASS::negative.binomial(theta = 1, link = "identity")),
    iterDEoptim = 300
  )
)

ignitionFitObjects <- list(
  fireSense_ignitionCovariates = fSsimDataPrep[["fireSense_ignitionCovariates"]],
  ignitionFitRTM = fSsimDataPrep[["ignitionFitRTM"]]
)

fignitionOut <- file.path(Paths$outputPath, paste0("ignitionOut_", studyAreaName, ".qs"))
if (isTRUE(usePrerun) & isFALSE(upload_ignitionOut)) {
  if (!file.exists(fignitionOut)) {
    googledrive::drive_download(file = as_id(gid_ignitionOut), path = fignitionOut)
  }
  ignitionOut <- loadSimList(fignitionOut)
} else {
  ignitionOut <- Cache(
    simInitAndSpades,
    times = list(start = 0, end = 1),
    # ignitionSim <- simInit(times = list(start = 0, end = 1),
    params = ignitionFitParams,
    modules = "fireSense_IgnitionFit",
    paths = ignitionFitPaths,
    objects = ignitionFitObjects,
    userTags = c("ignitionFit")
  )
  saveSimList(sim = ignitionOut, filename = fignitionOut, fileBackend = 2)

  if (isTRUE(upload_ignitionOut)) {
    fdf <- googledrive::drive_put(media = fignitionOut, path = gdriveURL, name = basename(fignitionOut))
    gid_ignitionOut <- as.character(fdf$id)
    rm(fdf)
    gdriveSims <- update_googleids(
      data.table(studyArea = studyAreaName, simObject = "ignitionOut", runID = NA,
                 gcm = NA, ssp = NA, gid = gid_ignitionOut),
      gdriveSims
    )
  }

  if (isTRUE(firstRunIgnitionFit)) {
    source("R/upload_ignitionFit.R")
  }

  if (requireNamespace("slackr") & file.exists("~/.slackr")) {
    slackr::slackr_setup()
    slackr::slackr_msg(
      paste0("`fireSense_IgnitionFit` for ", studyAreaName, " completed on host `", Sys.info()[["nodename"]], "`."),
      channel = config::get("slackchannel"), preformatted = FALSE
    )
  }
}

