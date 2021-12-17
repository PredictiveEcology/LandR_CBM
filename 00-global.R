if (!exists("pkgDir")) {
  pkgDir <- file.path("packages", version$platform, paste0(version$major, ".",
                                                           strsplit(version$minor, "[.]")[[1]][1]))

  if (!dir.exists(pkgDir)) {
    dir.create(pkgDir, recursive = TRUE)
  }
  .libPaths(pkgDir)
}

if (!suppressWarnings(require("Require"))) {
  install.packages("Require")
  library(Require)
}

switch(Sys.info()[["user"]],
       "achubaty" = Sys.setenv(R_CONFIG_ACTIVE = "alex"),
       "ieddy" = Sys.setenv(R_CONFIG_ACTIVE = "ian"),
       "emcintir" = Sys.setenv(R_CONFIG_ACTIVE = "eliot"),
       Sys.setenv(R_CONFIG_ACTIVE = "test")
)
#Sys.getenv("R_CONFIG_ACTIVE") ## verify

source("01-init.R")
source("02-paths.R")
source("03-packages.R")
source("04-options.R")
source("05-google-ids.R")

if (delayStart > 0) {
  message(crayon::green("\nStaggered job start: delaying", runName, "by", delayStart, "minutes."))
  Sys.sleep(delayStart*60)
}

source("06-studyArea.R")

source("07a-dataPrep_2001.R")
source("07b-dataPrep_2011.R")
source("07c-dataPrep_fS.R")

message(crayon::red("Data prep", runName, "complete"))

source("08a-ignitionFit.R")
source("08b-escapeFit.R")

for (i in 1:nReps) {
  run <- i
  runName <- gsub("run[0-9][0-9]", sprintf("run%02d", run), runName)

  if (isFALSE(usePrerun) & isTRUE(reupload)) {
    ## prerun all spreadfits, for use with main sim runs on another machine

    if (file.exists("Rplots.pdf")) {
      unlink("Rplots.pdf")
    }
    source("08c-spreadFit.R")
    if (file.exists("Rplots.pdf")) {
      file.rename("Rplots.pdf", file.path(Paths$outputPath, "figures", sprintf("spreadFit_plots_%s.pdf", runName)))
    }
  } else {
    for (j in c("CanESM5", "CNRM-ESM2-1")) {
      for (k in c(370L, 585L)) {
        runName <- sprintf("%s_%s_SSP%03d_run%02d", studyAreaName, j, k, i)
        dynamicPaths$outputPath <- file.path("outputs", runName)

        source("08c-spreadFit.R")
        source("09-main-sim.R")

        message(crayon::red("Simulation", runName, "complete"))
      }
    }
  }
}
