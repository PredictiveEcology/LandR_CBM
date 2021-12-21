do.call(setPaths, dynamicPaths)

gid_results <- gdriveSims[studyArea == studyAreaName & simObject == "results", gid]

times <- list(start = 2011, end = 2100)

dynamicModules <- list("fireSense_dataPrepPredict",
                       "fireSense",
                       "fireSense_IgnitionPredict",
                       "fireSense_EscapePredict",
                       "fireSense_SpreadPredict",
                       "Biomass_core",
                       "Biomass_regeneration",
                       "CBM_defaults",
                       "CBM_vol2biomass_RIA", ## TODO: confirm which vol2biomass module to use
                       "CBM_core")

dynamicObjects <- list(
  ATAstack = simOutPreamble[["ATAstack"]],
  biomassMap = biomassMaps2011$biomassMap,
  climateComponentsTouse = fSsimDataPrep[["climateComponentsToUse"]],
  CMInormal = simOutPreamble[["CMInormal"]],
  CMIstack = simOutPreamble[["CMIStack"]],
  cohortData = fSsimDataPrep[["cohortData2011"]],
  dbPath = file.path(inputDir, "cbm_defaults", "cbm_defaults.db"),
  ecoregion = biomassMaps2011[["ecoregion"]],
  ecoregionMap = biomassMaps2011[["ecoregionMap"]],
  flammableRTM = fSsimDataPrep[["flammableRTM"]],
  fireSense_IgnitionFitted = ignitionOut[["fireSense_IgnitionFitted"]],
  fireSense_EscapeFitted = escapeOut[["fireSense_EscapeFitted"]],
  fireSense_SpreadFitted = spreadOut[["fireSense_SpreadFitted"]],
  covMinMax_spread = spreadOut[["covMinMax_spread"]],
  covMinMax_ignition = ignitionOut[["covMinMax_ignition"]],
  landcoverDT = fSsimDataPrep[["landcoverDT"]],
  nonForest_timeSinceDisturbance = fSsimDataPrep[["nonForest_timeSinceDisturbance2011"]],
  minRelativeB = biomassMaps2011[["minRelativeB"]],
  PCAveg = fSsimDataPrep[["PCAveg"]],
  pixelGroupMap = fSsimDataPrep[["pixelGroupMap2011"]],
  projectedClimateLayers = simOutPreamble[["projectedClimateRasters"]],
  rasterToMatch = biomassMaps2011[["rasterToMatch"]],
  rasterToMatchLarge = biomassMaps2011[["rasterToMatchLarge"]],
  rescaleFactor = 1 / fSsimDataPrep@params$fireSense_dataPrepFit$igAggFactor^2,
  species = biomassMaps2011[["species"]],
  speciesEcoregion = biomassMaps2011[["speciesEcoregion"]],
  speciesLayers = biomassMaps2011[["speciesLayers"]], ## TODO: does Biomass_core actually need this?
  sppColorVect = biomassMaps2011[["sppColorVect"]],
  sppEquiv = fSsimDataPrep[["sppEquiv"]],
  sqlDir = file.path(inputDir, "cbm_defaults"),
  studyArea = biomassMaps2011[["studyArea"]],
  studyAreaLarge = biomassMaps2011[["studyAreaLarge"]],
  studyAreaPSP = simOutPreamble[["studyAreaPSP"]],
  studyAreaReporting = biomassMaps2011[["studyAreaReporting"]],
  sufficientLight = biomassMaps2011[["sufficientLight"]],
  terrainDT = fSsimDataPrep[["terrainDT"]],
  vegComponentsToUse = fSsimDataPrep[["vegComponentsToUse"]]
)

rastersToSaveAnnually <- c(
  "ANPPMap",
  "burnMap",
  "fireSense_EscapePredicted",
  "fireSense_IgnitionPredicted",
  "fireSense_SpreadPredicted",
  "mortalityMap",
  "pixelGroupMap",
  "rstCurrentBurn",
  "simulatedBiomassMap"
)

annualRasters <- data.frame(
  expand.grid(
    objectName = rastersToSaveAnnually,
    saveTime = seq(times$start, times$end, 1),
    fun = "writeRaster",
    package = "raster"
  ),
  stringsAsFactors = FALSE
)
annualRasters$file <- paste0(annualRasters$objectName, "_", annualRasters$saveTime, ".tif")

objectsToSaveAnnually <- c(
  "cohortData" ## data.table
)

annualObjects <- data.frame(
  expand.grid(
    objectName = objectsToSaveAnnually,
    saveTime = seq(times$start, times$end, 1),
    fun = "qsave",
    package = "qs"
  ),
  stringsAsFactors = FALSE
)
annualObjects$file <- paste0(annualObjects$objectName, "_", annualObjects$saveTime, ".qs")

objectNamesToSaveAtEnd <- c("speciesEcoregion",
                            "species",
                            #"gcsModel", ## TODO: from LandR.CS
                            #"mcsModel", ## TODO: from LandR.CS
                            "simulationOutput",
                            "burnSummary")

finalYearOutputs <- data.frame(
  objectName = objectNamesToSaveAtEnd,
  saveTime = times$end,
  fun = "qsave",
  package = "qs",
  file = paste0(objectNamesToSaveAtEnd, ".qs"),
  stringsAsFactors = FALSE
)

dynamicOutputs <- rbind(annualRasters, annualObjects, finalYearOutputs)

dynamicParams <- list(
  Biomass_core = list(
    "sppEquivCol" = fSsimDataPrep@params$fireSense_dataPrepFit$sppEquivCol,
    "vegLeadingProportion" = 0, ## apparently sppColorVect has no mixed color
    ".plotInitialTime" = .plotInitialTime,
    ".plots" = c("object", "png", "raw")
  ),
  Biomass_regeneration = list(
    "fireInitialTime" = times$start + 1 #regeneration is scheduled earlier, so it starts in 2012
  ),
  CBM_core = list(
    .useCache = FALSE,
    .plotInitialTime = times$start,
    poolsToPlot = c("totalCarbon"),
    spinupDebug = FALSE ## TODO: temporary
  ),
  CBM_defaults = list(
    .useCache = TRUE
  ),
  CBM_vol2biomass_RIA = list(
    .useCache = TRUE
  ),
  fireSense_dataPrepPredict = list(
    "fireTimeStep" = 1,
    "sppEquivCol" = simOutPreamble$sppEquivCol,
    "whichModulesToPrepare" = c("fireSense_IgnitionPredict",
                                "fireSense_EscapePredict",
                                "fireSense_SpreadPredict"),
    "missingLCCgroup" = fSsimDataPrep@params$fireSense_dataPrepFit$missingLCCgroup
  ),
  fireSense_ignitionPredict = list(
    # "rescaleFactor" = 1 / fSsimDataPrep@params$fireSense_dataPrepFit$igAggFactor^2 #deprecated
  ),
  fireSense = list(
    .plotInterval = NA,
    .plotInitialTime = .plotInitialTime,
    plotIgnitions = FALSE,
    whichModulesToPrepare = c("fireSense_IgnitionPredict", "fireSense_EscapePredict", "fireSense_SpreadPredict")
  )
)

## TODO: delete unused objects, including previous simLists to free up memory

fsim <- file.path(Paths$outputPath, paste0(runName, ".qs"))
mainSim <- simInitAndSpades(
  times = times,
  modules = dynamicModules,
  objects = dynamicObjects,
  outputs = dynamicOutputs,
  params = dynamicParams,
  paths = dynamicPaths,
  loadOrder = unlist(dynamicModules)
)

saveSimList(sim = mainSim, filename = fsim, fileBackend = 2)

resultsDir <- file.path("outputs", runName)
#archive::archive_write_dir(archive = paste0(resultsDir, ".tar.gz"), dir = resultsDir) ## doesn't work
utils::tar(paste0(resultsDir, ".tar.gz"), resultsDir, compression = "gzip") ## TODO: use archive pkg

retry(quote(drive_put(paste0(resultsDir, ".tar.gz"), unique(as_id(gid_results)))),
      retries = 5, exponentialDecayBase = 2)

SpaDES.project::notify_slack(runName = runName, channel = config::get("slackchannel"))
