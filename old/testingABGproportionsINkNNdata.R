# we need to be able to split the AGB from LandR into CBM pools.
# The kNN data has a ABG, AGB_BR, AGB_FO, AGB_SB, AGB_SW, which are the pool
# split needed for using the LandR ABG in CBM.
# Here, we seeing if the biomass proportions in the kNN data can be rebuilt, and
# therefore used to split the AGB estimates from LandR into the pools needed for
# CBM simulations.
# CBoisvenue and Alex Chubaty
# November 5th 2021

# downloaded the file AChubaty built with the forCeline.R script in this folder,
# from here:
# https://drive.google.com/drive/u/1/folders/16bevmh7ksnWNtYAMX2P1qJMKgSfzM-3c
library(googledrive)
library(data.table)
library(raster)
library(SpaDES.core)

here1 <- file.path(getwd(),"biomassPools/data")
saveTo <- file.path(here1, "forCeline_dt.qs")
# only need to do this once
#googledrive::drive_download(as_id("14QfkO5_opAAYTXQcQjy_DvtLioPjSnJs"), saveTo)
volBiomassCover <- qs::qload(saveTo)

# figure out leading species
allSpsDT <- as.data.table(cbind(
  pixelID,
  Abie_Las,
  Betu_Pap,
  Pice_Eng,
  Pice_Gla,
  Pice_Mar,
  Pinu_Con,
  Popu_Tre
))
allSpsDT$max <- pmax(
       Abie_Las,
       Betu_Pap,
       Pice_Eng,
       Pice_Gla,
       Pice_Mar,
       Pinu_Con,
       Popu_Tre
   )
# get ride of the 0s
spsDT2 <- allSpsDT[max>0,]
# found this:
# iris[,maximum_column :=  names(.SD)[max.col(.SD)], .SDcols = 1:4]
spsDT2[, ldSps := names(.SD)[max.col(.SD)], .SDcols = 2:8]
# need full pixelID and ldSps columns
ldSpsDT <- merge(allSpsDT[,.(pixelID)], spsDT2[,.(pixelID,ldSps)], by = "pixelID", all = TRUE)


AGBvaluesDT <- as.data.table(cbind(
  pixelID,
  BiomassTotalLiveAboveGround,
  BiomassBranch,
  BiomassFoliage,
  BiomassStemBark,
  BiomassStemWood,
  VolumeMerch,
  Ecozone
))

AGBvaluesDT <- AGBvaluesDT[ldSpsDT, on = "pixelID"]
# setkey() for both pixelID then ldSpsDT[AGBvaluesDT] is the same as X[Y] or
# merge(X, Y, all.y=TRUE)

AGBvaluesDT[, sumPools := (BiomassBranch +
                          BiomassFoliage +
                          BiomassStemBark +
                          BiomassStemWood )]

## does the sum of Biomass*Pools* equal BiomassTotalLiveAboveGround?
AGBvaluesDT[, diffAGBtots := (BiomassTotalLiveAboveGround - sumPools)]
summary(AGBvaluesDT$diffAGBtots)
### YES:
# Min.    1st Qu.     Median       Mean    3rd Qu.       Max.
# -0.0166693 -0.0033312  0.0000000 -0.0001262  0.0033293  0.0133419

## calculate the proportions Biomass*Pools* over BiomassTotalLiveAboveGround
newCols <- c("p_stemwood", "p_bark", "p_branches", "p_foliage")
AGBvaluesDT[, (newCols) := list(
                   (BiomassStemWood/BiomassTotalLiveAboveGround),
                   (BiomassStemBark/BiomassTotalLiveAboveGround),
                   (BiomassBranch/BiomassTotalLiveAboveGround),
                   (BiomassFoliage/BiomassTotalLiveAboveGround))]

## Can we calculate those proportions with the VolumeMerch variable and the
## ldSps+Ecozone parameters?
#########################################################################

# select 10 pixels with ldSps (no NAs)

test10pix <- AGBvaluesDT[pixelID %in% sample(AGBvaluesDT[!is.na(ldSps)]$pixelID,10),]

# need Table 6 and Table 7 from Boudewyn et al
table6 <- fread("https://nfi.nfis.org/resources/biomass_models/appendix2_table6.csv",
                      fill = TRUE)
t6hasToHave <- c("juris_id", "ecozone", "canfi_species", "a1", "a2", "a3", "b1", "b2", "b3",
                   "c1", "c2", "c3" )
if(!length(which(colnames(table6) %in% t6hasToHave)) == length(t6hasToHave)){
    message(
      "The parameter table (appendix2_table6) does not have the expected number of columns. ",
      "This means parameters are missing. The default (older) parameter file will be used instead."
    )
    # sim$table6 <- fread(file.path("modules","AGBspiltToPools","data","appendix2_table6.csv"))
    # ## TODO: use url to googleDrive (G:\userDataDefaultsCBM_SK)
}

table7 <- fread("https://nfi.nfis.org/resources/biomass_models/appendix2_table7.csv")
  t7hasToHave <- c("juris_id", "ecozone", "canfi_species", "vol_min", "vol_max", "p_sw_low",
                   "p_sb_low", "p_br_low", "p_fl_low", "p_sw_high", "p_sb_high", "p_br_high",
                   "p_fl_high")
  if(!length(which(colnames(table7) %in% t7hasToHave)) == length(t7hasToHave)){
    message(
      "The parameter table (appendix2_table7) does not have the expected number of columns. ",
      "This means parameters are missing. The default (older) parameter file will be used instead."
    )
    # sim$table7 <- fread(file.path("modules","AGBspiltToPools","data","appendix2_table7.csv"))
    # ## TODO: use url to googleDrive (G:\userDataDefaultsCBM_SK)
  }

# get the correct parameters depending on the ldSps and the Ecozone
# match the species
canfi_species <- fread(file.path(here1, "canfi_species.csv"))
## TODO : use the species table from LandR/Boreal_dataPrep to natch tree species

# looking for the canfi_species number here to match directly to table6 and table7$canfi_species
genus <- substr(test10pix$ldSps, 1, 4)
#[1] "Pinu" "Abie" "Popu" "Abie" "Pice" "Pice" "Abie" "Pinu" "Pinu" "Abie"
spp <- substr(test10pix$ldSps, 6, 8)
#[1] "Con" "Las" "Tre" "Las" "Gla" "Mar" "Las" "Con" "Con" "Las"
# lopping through because I only have 10 sps

for(i in 1:length(test10pix$ldSps)){
  indices1 <- grep(genus[i], canfi_species$genus, ignore.case = TRUE)
  indices <- grep(spp[i], canfi_species[indices1,]$species, ignore.case = TRUE)
  if(length(indices)> 1){indices <- indices[1]}
  test10pix$canfi_species[i] <-  canfi_species[indices1][indices,]$canfi_species
}

vol10pix <- test10pix[,.(VolumeMerch, Ecozone, canfi_species)]
setnames(vol10pix, names(vol10pix)[1:2], new = c("vol", "ecozone"))

# match parameters in table
setkeyv(test10pix, cols = c("Ecozone", "canfi_species"))
setkeyv(vol10pix, cols = c("ecozone", "canfi_species"))
setkeyv(table6, cols = c("ecozone", "canfi_species"))
setkeyv(table7, cols = c("ecozone", "canfi_species"))
# need to have no repeats
table6[,variety := NULL]
table7[,variety := NULL]
table6s <- unique(table6[juris_id == "BC",][vol10pix])
table7s <- unique(table7[juris_id == "BC",][vol10pix])
#check if these tables are the right length
if(!(dim(vol10pix)[1] == dim(table6s)[1]) | (!dim(vol10pix)[1] == dim(table7s)[1])){
  message("There is a mismatch between selected pixels and the parameters
          joined on ecozone and species.")
}

# calculate proportions
library(CBMutils)
calcProp <- CBMutils::biomProp(table6 = table6s, table7 = table7s, vol = table6s$vol)
calcProp <- as.data.table(calcProp)
p_compare <- as.data.table(cbind(test10pix[, .(pixelID, canfi_species,
                           p_stemwood, p_bark, p_branches, p_foliage)],
                           calcProp))
compCols <- c("stemwoodPdiff", "barkPdiff", "branchesPdiff", "foliagePdiff")
p_compare[, (compCols) := list(p_stemwood - pstem,
                               p_bark - pbark,
                               p_branches - pbranches,
                               p_foliage - pfol)]
# trying with AGB to see if the differences are comparable
calcPropAGB <- CBMutils::biomProp(table6 = table6s, table7 = table7s,
                                  vol = test10pix$BiomassTotalLiveAboveGround)
calcPropAGB <- as.data.table(calcPropAGB)
p_compareAGB <- as.data.table(cbind(test10pix[, .(pixelID, canfi_species,
                                               p_stemwood, p_bark, p_branches, p_foliage)],
                                 calcPropAGB))
compCols <- c("stemwoodPdiff", "barkPdiff", "branchesPdiff", "foliagePdiff")
p_compareAGB[, (compCols) := list(p_stemwood - pstem,
                               p_bark - pbark,
                               p_branches - pbranches,
                               p_foliage - pfol)]

p_compareAGB[, .(pixelID, canfi_species,stemwoodPdiff, barkPdiff, branchesPdiff, foliagePdiff)] -
p_compare[, .(pixelID, canfi_species,stemwoodPdiff, barkPdiff, branchesPdiff, foliagePdiff)]

stemABGvolP <- p_compare$stemwoodPdiff < p_compareAGB$stemwoodPdiff
barkABGvolP <- p_compare$barkPdiff < p_compareAGB$barkPdiff
branchABGvolP <- p_compare$branchesPdiff < p_compareAGB$branchesPdiff
folABGvolP <- p_compare$foliagePdiff < p_compareAGB$foliagePdiff
volOrABG <- cbind(stemABGvolP, barkABGvolP, branchABGvolP, folABGvolP)

p_compare[, kNNprop := (p_stemwood + p_bark + p_branches + p_foliage)]
p_compare[, volCalcProp := (pstem + pbark + pbranches + pfol)]

## check with VolumeTotal
volTotDT <- as.data.table(cbind(pixelID, VolumeTotal))
# need to make sure they are in the same order
test10pix[, rd := 1:length(test10pix$pixelID)]
thisOrder <- test10pix[, .(pixelID, rd)]
totVol10 <- volTotDT[pixelID %in% test10pix$pixelID,][thisOrder, on = "pixelID"]
setkeyv(totVol10, "rd")

calcPropTotVol <- CBMutils::biomProp(table6 = table6s, table7 = table7s,
                               vol = totVol10$VolumeTotal)

calcPropTotVol <- as.data.table(calcPropTotVol)
rowSums(calcPropTotVol)

p_compareTotVol <- as.data.table(cbind(test10pix[, .(pixelID, canfi_species,
                                               p_stemwood, p_bark, p_branches, p_foliage)],
                                 calcPropTotVol))
compCols <- c("stemwoodPdiff", "barkPdiff", "branchesPdiff", "foliagePdiff")
p_compareTotVol[, (compCols) := list(p_stemwood - pstem,
                               p_bark - pbark,
                               p_branches - pbranches,
                               p_foliage - pfol)]

stemToTmerchVolP <- p_compare$stemwoodPdiff < p_compareTotVol$stemwoodPdiff
barkToTmerchVolP <- p_compare$barkPdiff < p_compareTotVol$barkPdiff
branchToTmerchVolP <- p_compare$branchesPdiff < p_compareTotVol$branchesPdiff
folToTmerchVolP <- p_compare$foliagePdiff < p_compareTotVol$foliagePdiff
merchOrTot <- cbind(stemToTmerchVolP, barkToTmerchVolP, branchToTmerchVolP, folToTmerchVolP)



