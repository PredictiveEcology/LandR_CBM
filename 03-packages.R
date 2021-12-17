.spatialPkgs <- c("lwgeom", "rgdal", "rgeos", "sf", "sp", "raster", "terra")

if (!all(.spatialPkgs %in% rownames(installed.packages()))) {
  install.packages(.spatialPkgs, repos = "https://cran.rstudio.com")
  #install.packages(c("raster", "terra"), repos = "https://rspatial.r-universe.dev")
  sf::sf_extSoftVersion() ## want GEOS 3.9.0, GDAL 3.2.1, PROJ 7.2.1
}

Require(c("data.table", "plyr", "pryr")) ## ensure plyr loaded before dplyr or there will be problems
Require("RCurl", require = FALSE)

Require("PredictiveEcology/SpaDES.install (>= 0.0.4)")
Require("PredictiveEcology/SpaDES.core@development (>= 1.0.9.9002)",
        which = c("Suggests", "Imports", "Depends"), upgrade = FALSE) # need Suggests in SpaDES.core
Require("PredictiveEcology/SpaDES.project@development", require = FALSE)

Require(c("archive", "slackr"), upgrade = FALSE)
Require("PredictiveEcology/fireSenseUtils@development (>= 0.0.5.9005)", require = FALSE) ## force pemisc and others to be installed correctly

Require("achubaty/amc (>= 0.2.0)", require = FALSE, which = c("Suggests", "Imports", "Depends"))

out <- makeSureAllPackagesInstalled(modulePath = "modules")
