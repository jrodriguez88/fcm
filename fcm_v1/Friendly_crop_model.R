# Prototype for Friendly Crop Model
# github.com/jrodriguez88/
# 2021



### 1. LOAD DEPENDENCIES - Same as AgroClimR v1

## UTILS
source("https://raw.githubusercontent.com/jrodriguez88/agroclimR/r_package/R_package/utils/utils_crop_model.R", encoding = "UTF-8")
source("https://raw.githubusercontent.com/jrodriguez88/agroclimR/r_package/R_package/utils/soil_PTF.R", encoding = "UTF-8")
source("https://raw.githubusercontent.com/jrodriguez88/aquacrop-R/master/agroclim_forecaster.R", encoding = "UTF-8")
load_agroclimr_requeriments(); ubicar_directorios("/fcm_v1/")
inpack(c("tidyverse", "data.table", "lubridate", "sirad", "naniar", "jsonlite" ,"soiltexture", "Hmisc", "parallel"))


## DOWNLOAD DATA
source("https://raw.githubusercontent.com/jrodriguez88/agroclimR/r_package/R_package/get_data/get_data_nasapower.R", encoding = "UTF-8")
source("https://raw.githubusercontent.com/jrodriguez88/agroclimR/r_package/R_package/get_data/get_data_soilgrids.R", encoding = "UTF-8")

## WRITE FILES
source("https://raw.githubusercontent.com/jrodriguez88/agroclimR/r_package/R_package/write_files/write_wth_aquacrop.R", encoding = "UTF-8")
source("https://raw.githubusercontent.com/jrodriguez88/agroclimR/r_package/R_package/write_files/write_soil_aquacrop.R", encoding = "UTF-8")

## SETUPS SIMULATION
source("fcm_v1/setups_projects.R")

## SIMULATION ANALYSIS
source("https://raw.githubusercontent.com/jrodriguez88/aquacrop-R/master/read_outputs_aquacrop.R", encoding = "UTF-8")
source("https://raw.githubusercontent.com/jrodriguez88/aquacrop-R/master/plot_applications.R", encoding = "UTF-8")



### 2. INPUT ARGUMENTS
id_name <- "testFCM"
ini_date <- ymd("2020-01-01")       #Initial Date (Year-Month-Day)
end_date <- ymd("2020-12-31")       #End Date (Year-Month-Day)
lat <- 6.8                          #Latitude (Decimal degrees)
lon <- -58.1                        #Longitude (Decimal degrees)
elev <- get_elevation(lat, lon)     #Elevation ()



### 3. DOWNLOAD ( Or INPUT) CLIMATE AND SOIL DATA 
## Download climate and soil data from NASAPOWER and soilgrids (ex1)
#wth_data <- read_csv("data/wth_data.csv") %>% mutate(date = mdy(date)) %>% filter(date>=ini_date, date<=end_date)
wth_data <- get_data_nasapower(lat, lon, ini_date, end_date)
soil_data <- get_data_soilgrids(lat, lon)



### 3. CREATE CROP MODEL FILES

# climate data ready to aquacrop:
# review consistency data
# calculate Reference evapotranspiration (ETo)
# write aquacrop_file`(*.CLI - - )`
wth_data %>% 
  mutate(ETo = ETo_cal(., lat, elev)) %>%
  write_wth_aquacrop("fcm_v1/aquacrop_files/", "testFCM", ., lat, lon, elev)


# soil data ready to aquacrop:
# Review data download
# Hidrological propierties calculate from PTF
# write aquacrop soil file (*.SOL)
soilgrids_to_aquacrop(soil_data) %>%
write_soil_aquacrop(path = "fcm_v1/", 
                    id_name = "testFCM", 
                    soil_data = .$data, CN = .$CN, REW = .$REW)


### SIMULATION SETUPS

cultivar <- list.files(aquacrop_files, pattern = ".CRO") %>% str_remove(".CRO")
soil <- list.files(aquacrop_files, pattern = ".SOL") %>% str_remove(".SOL")
planting_dates <- make_hist_dates(imonth = 4, fmonth =  4, datos_nasa)

planting_dates %>%
map2(.x = ., .y = paste0(id_name, seq_along(planting_dates)),
     ~make_project_by_date(.y, id_name, .x, cultivar[[1]], soil[[1]], wth_data, 140, aquacrop_files, plugin_path))


### RUN SIMULATIONS
system("fcm_v1/plugin/ACsaV60.exe")



### READ OUPUTS
path_op <- paste0(plugin_path, "/OUTP/")
season_files <- list.files(path_op, pattern = "season") #%>% str_subset("Frijol")

file_str <- c("id",  "clima", "cultivar", "soil", "crop_sys")
season_data <- map(.x = season_files, ~read_aquacrop_season(.x, path_op)) %>%
  bind_rows()

plot_outputs(season_data, id_name, file_str = file_str, yield_units = "kg/ha")


#Borra contenido de carpetas
file.remove(list.files(aquacrop_files, full.names = T, pattern = ".PLU|.ETo|CLI|Tnx"))
unlink(paste0(plugin_path, "/OUTP/*"))
unlink(paste0(plugin_path, "/LIST/*"))


