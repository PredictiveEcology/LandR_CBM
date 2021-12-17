## script copied from Zulip sent by Alex on Oct 30th, 2021
## these scripts are to help me figure out if the Biomass and Biomass by pool is
## usable as a way to split the AGB cumulative curves in LandR into pools needed
## in CBM
library(raster)
library(SpaDES.core)
library(googledrive)
library(data.table)

## gives you access to a pre-simulation simList, containing cohortData,
## pixelGroupMap, speciesLayers, and ecoregionLayer
#fbiomassMaps2001 <- "~/GitHub/WBI_forecasts/outputs/MB/biomassMaps2001_MB.qs"
fbiomassMaps2001 <- file.path(getwd(),"data","biomassMaps2001_MB.qs")

#if (!file.exists(fbiomassMaps2001)) {
  googledrive::drive_download(file = as_id("1PqeJWDh1ZBVHPokqJ9Hjmr0ZBEUbNHKi"),
                              path = fbiomassMaps2001,
                              overwrite = TRUE)
#}


biomassMaps2001 <- loadSimList(fbiomassMaps2001)
RIAcohortData <- as.data.table(biomassMaps2001$cohortData)
setkeyv(RIAcohortData, "pixelGroup")

cohortDataTotalB <- unique(RIAcohortData[, c("pixelGroup", "totalBiomass")], by = "pixelGroup")

agbMap <- rasterizeReduced(cohortDataTotalB, biomassMaps2001$pixelGroupMap,
                       newRasterCols = "totalBiomass", mapcode = "pixelGroup")
Plot(agbMap, biomassMaps2001$pixelGroupMap)

#other biomassMaps objects (simlists created during borealDataPrep) available here:
# https://drive.google.com/drive/u/1/folders/1pFpAZwFqRIWxAygntEx8rVPV_b2BTqMB

#i'll get you an example of species volume and biomass from kNN shortly
#here's link to vol&biomass layers

## download files manually from here:
## https://drive.google.com/drive/u/1/folders/16bevmh7ksnWNtYAMX2P1qJMKgSfzM-3c

path <- "~/GitHub/WBI_forecasts/inputs"
b <- "rawBiomasMap_RIA2001.tif"
f <- c("NFI_MODIS250m_2011_kNN_Species_Abie_Las_v1_cache_dataPrep_RIA2011.tif",
       "NFI_MODIS250m_2011_kNN_Species_Betu_Pap_v1_cache_dataPrep_RIA2011.tif",
       "NFI_MODIS250m_2011_kNN_Species_Pice_Eng_v1_cache_dataPrep_RIA2011.tif",
       "NFI_MODIS250m_2011_kNN_Species_Pice_Gla_v1_cache_dataPrep_RIA2011.tif",
       "NFI_MODIS250m_2011_kNN_Species_Pice_Mar_v1_cache_dataPrep_RIA2011.tif",
       "NFI_MODIS250m_2011_kNN_Species_Pinu_Con_v1_cache_dataPrep_RIA2011.tif",
       "NFI_MODIS250m_2011_kNN_Species_Popu_Tre_v1_cache_dataPrep_RIA2011.tif")
v <- "NFI_MODIS250m_kNN_Structure_Volume_Total_v0/NFI_MODIS250m_kNN_Structure_Volume_Total_v0.tif"

coverStack <- stack(file.path(path, f))
sppNames <- substr(names(coverStack), 32, 39)
names(coverStack) <- sppNames

biomass <- raster(file.path(path, b))

volume <- raster(file.path(path, v))
volume <- reproducible::postProcess(volume, rasterToMatch = biomass)

dt <- data.table(pixelID = 1:ncell(volume), TotalVolume = volume[], TotalBiomass = biomass[])
dt <- na.omit(dt)

samplePixIDs <- head(dt$pixelID, 10)

coverStack[samplePixIDs]
