Sys.setenv(LANG = "en")
#install.packages("devtools")
#library(devtools)
#install_github("iobis/robis")
#install.packages("devtools")
#devtools::install_github("iobis/obistools")
##install.packages("maps")

#Load packages
library(robis)
library(obistools)
library(magrittr) # for %T>% pipe
library(readxl)
library(openxlsx)
library(tidyverse)
library(sf)
library(vegan)
library(pvclust)
library(maps)
library(ggplot2)
library(viridis)
library(nortest) # for Anderson-Darling test
library(stringi) # for encoding UTF-8
library(purrr)          # For functional programming
library(diptest)  # For Hartigan's Dip Test
library(patchwork)

citation("robis")

# Get data from OBIS
Solenidaeobis <- occurrence("Solenidae")
write.csv(Solenidaeobis, file = "Solenidaeobis.csv", row.names = FALSE)

#get citation for OBIS data before loading rgbif, as both contain a function called dataset()
datasetids <- unique(Solenidaeobis$dataset_id)

citations <- data.frame(id = datasetids, citation = NA)

for (i in 1:nrow(citations)) {
  message(citations$id[i])
  d <- dataset(datasetid = citations$id[i])
  citations$citation[i] <- d$citation
}

# To save the citations as a CSV file
write.csv(citations, file = "citations_OBIS.csv", row.names = FALSE)

# Save citations as HTML
htmltools::save_html(
  htmltools::tags$table(
    htmltools::tags$thead(
      htmltools::tags$tr(
        htmltools::tags$th("Dataset ID"),
        htmltools::tags$th("Citation")
      )
    ),
    htmltools::tags$tbody(
      lapply(seq_len(nrow(citations)), function(i) {
        htmltools::tags$tr(
          htmltools::tags$td(citations$id[i]),
          htmltools::tags$td(citations$citation[i])
        )
      })
    )
  ),
  file = "citations_OBIS.html"
)

#Do some trimming (quality control)
data_OBIS_Trim <- subset(Solenidaeobis, absence!="TRUE")
data_OBIS_Trim <- subset(data_OBIS_Trim, decimalLatitude!="NA", decimalLongitude!="NA")
data_OBIS_Trim <- subset(data_OBIS_Trim, basisOfRecord!="FOSSIL_SPECIMEN")
data_OBIS_Trim <- subset(data_OBIS_Trim, coordinateUncertaintyInMeters<= 100000 
                         | is.na(coordinateUncertaintyInMeters)) # remove rows with "Coordinate Uncertainty" exceeding 100 km

# Get data from GBIF
# https://docs.ropensci.org/rgbif/articles/getting_occurrence_data.html
# Retrieve occurrence data from GBIF
library(rgbif) # for occ_download
library(taxize) # for get_gbifid

# fill in your gbif.org credentials 
user <- "haniehsaeedi" 
pwd <- "Anitaamirali_2607!" 
email <- "hanieh.saeedi@gmail.com"

name_backbone("Solenidae") # get the taxon id information

occ_download(
  pred_gte("depth", 0),
  pred("hasGeospatialIssue", FALSE),
  pred("hasCoordinate", TRUE),
  pred("occurrenceStatus","PRESENT"), 
  pred_not(pred_in("basisOfRecord",c("FOSSIL_SPECIMEN"))),
  pred("taxonKey", 3449),
  pred_lt("coordinateUncertaintyInMeters",100000),
  format = "SIMPLE_CSV",
  user=user,pwd=pwd,email=email
)

# Check status using the download key
occ_download_wait('0000668-260916113435855')

# After it finishes, use
Solenidaegbif <- occ_download_get('0000668-260916113435855') %>%
  occ_download_import()
write.csv(Solenidaegbif, file = "Solenidaegbif.csv", row.names = FALSE)

# Merge the OBIS and GBIF data
# Filter OBIS data
Solenidaeobis_fil <- data_OBIS_Trim %>%
  dplyr::select(scientificName, dataset_id, decimalLatitude, decimalLongitude, depth, occurrenceID, basisOfRecord, kingdom, order, species, countryCode, occurrenceStatus, coordinatePrecision, day, institutionCode, recordNumber, license, typeStatus, phylum, family, locality, individualCount, month, collectionCode, identifiedBy, rightsHolder, class, genus, taxonRank, stateProvince, coordinateUncertaintyInMeters, eventDate, year,catalogNumber, dateIdentified, recordedBy) %>%
  mutate(
    decimalLongitude = round(decimalLongitude, 3),
    decimalLatitude = round(decimalLatitude, 3)
  )

# Filter GBIF data
Solenidaegbif_fil <- Solenidaegbif %>%
  dplyr::select(scientificName, datasetKey, decimalLatitude, decimalLongitude, depth, occurrenceID, basisOfRecord, kingdom, order, species, countryCode, occurrenceStatus, coordinatePrecision, day, institutionCode, recordNumber, license, typeStatus, phylum, family, locality, individualCount, month, collectionCode, identifiedBy, rightsHolder, class, genus, taxonRank, stateProvince, coordinateUncertaintyInMeters, eventDate, year,catalogNumber, dateIdentified, recordedBy) %>%
  mutate(
    decimalLongitude = round(decimalLongitude, 3),
    decimalLatitude = round(decimalLatitude, 3)
  )

# Keep the GBIF name with authorship
Solenidaegbif_fil <- Solenidaegbif_fil %>%
  dplyr::mutate(
    scientificNameWithAuthorship = scientificName,
    scientificName = species
  )

# rename columns dataset_id to merge the data 
colnames(Solenidaegbif_fil)[2] <- "dataset_id" 

# make the integer columns to character to merge the data 
Solenidaegbif_fil <- Solenidaegbif_fil %>%
  mutate(across(
    c(individualCount, year, coordinatePrecision, day, month, dateIdentified),
    as.character
  ))


# Merge Solenidaedata with Solenidae global data
# read global Solenidae dataset from https://bdj.pensoft.net/article/31375/instance/3541751/
globalSolenidae <- read.csv('GlobalSolenidae.csv', sep = ";")

# check the different columns between two dataset
setdiff(names(Solenidaeobis_fil), names(globalSolenidae))

# Merge OBIS, GBIF, and integrated datasets and remove the duplicates by duplicated occurrenceID, if the same occurrenceID occurs in GlobalSolenidae and OBIS/GBIF, the GlobalSolenidae version is retained 
Solenidaedata <- bind_rows(
  globalSolenidae,
  Solenidaeobis_fil,
  Solenidaegbif_fil
) %>%
  filter(
    is.na(occurrenceID) |
      !duplicated(occurrenceID)
  )

write.csv(Solenidaedata, 'Solenidaedata.csv')

# data cleaning using obistools

#Plot points on a map
plot_map(Solenidaedata, zoom = TRUE)

#Check points on land
check_onland(Solenidaedata)
data_on_land <- check_onland(Solenidaedata, report = TRUE, buffer = 100) # plot records on land with 100 meter buffer
plot_map_leaflet(Solenidaedata[data_on_land$row,], popup = "id")
Solenidaedata_clean <- Solenidaedata[-1 * data_on_land$row,] #Remove the points on land

#Check depth using obistools
plot_map(check_depth(Solenidaedata_clean, depthmargin = 10), zoom = TRUE)
report <- check_depth(Solenidaedata_clean, report=T, depthmargin = 50)
head(report)# as only min and max depth are missing we do not need to do anything

# Inspect the problematic rows
Solenidaedata_clean[c(351, 399, 517), ]

#The OBISTools depth check identified three records with reported minimum/maximum 
#depths that were deeper than the bathymetric depths predicted at their coordinates. 
#These records were retained because the reported depths originate from specimen 
#records and the discrepancy may reflect generalized coordinates or local bathymetric variation. 
#No automatic correction was applied.

# Remove records deeper than 200 m
Solenidaedata_clean <- Solenidaedata_clean %>%
  filter(
    is.na(depth) | depth <= 200
  )

# Check how many records remain
nrow(Solenidaedata_clean)

# Check that no records deeper than 200 m remain
sum(Solenidaedata_clean$depth > 200, na.rm = TRUE)

#taxonmatch with WoRMS
names <- (Solenidaedata_clean$scientificName)
match_taxa(names)# all taxa matched with worms, click the info to get the unmatched list and save it as Taxmatch, then match this with WoRMS and delete the unaccepted species
Solenidaedata_clean_taxmatch <- subset(Solenidaedata_clean, !(scientificName %in% c("Solen lamarckii", "Solen truncatus"))) # remove the unaccepted species
write.csv(Solenidaedata_clean_taxmatch,'Solenidaedata_clean_taxmatch.csv')

#Summary
summary(Solenidaedata_clean_taxmatch)
Global_Solenidae_data_table <- summary(Solenidaedata_clean_taxmatch)
write.csv(Global_Solenidae_data_table, 'Global_Solenidae_data_table.csv')

# Get the number of distinct scientific names
distinct_species_count <- dplyr::n_distinct(
  Solenidaedata_clean_taxmatch$scientificName,
  na.rm = TRUE
)

print(distinct_species_count) # number of unique species

print(unique(Solenidaedata_clean_taxmatch$scientificName)) # lit the unique sepcies

# clean the white spots in scientificNames 
Solenidaedata_clean_taxmatch <- Solenidaedata_clean_taxmatch %>%
  dplyr::mutate(
    scientificName = trimws(scientificName)
  )

print(unique(Solenidaedata_clean_taxmatch$scientificName))

# Remove records that are not species names
Solenidaedata_clean_taxmatch <- Solenidaedata_clean_taxmatch %>%
  dplyr::filter(
    !is.na(scientificName),
    !scientificName %in% c("Solen", "Solenidae", "")
  )

# merge the synonyms 
Solenidaedata_clean_taxmatch <- Solenidaedata_clean_taxmatch %>%
  dplyr::mutate(
    scientificName = dplyr::case_when(
      scientificName == "Solen gemmelli" ~ "Solen gemmellae",
      scientificName == "Solen krusensterni" ~ "Solen krusensternii",
      TRUE ~ scientificName
    )
  )

print(unique(Solenidaedata_clean_taxmatch$scientificName))

distinct_species_count <- dplyr::n_distinct(
  Solenidaedata_clean_taxmatch$scientificName,
  na.rm = TRUE
)

print(distinct_species_count) # finally we have 57 distinct species

write.csv(Solenidaedata_clean_taxmatch,'Solenidaedata_clean_taxmatch.csv')

# read the data
Solenidaedata_clean_taxmatch <- read.csv("Solenidaedata_clean_taxmatch.csv")

# Map the occurrence records

world <- map_data("world")
sf_land <- st_read("ne_110m_land.shp")

Solenidae_Distribution <- ggplot() +
  geom_sf(
    data = sf_land,
    fill = "lightgrey",
    colour = NA
  ) +
  geom_sf(
    data = sf_land,
    fill = NA,
    colour = "#4D4D4D",
    linewidth = 0.5
  ) +
  geom_point(
    data = Solenidaedata_clean_taxmatch,
    aes(
      x = decimalLongitude,
      y = decimalLatitude,
      colour = scientificName
    ),
    size = 2,
    show.legend = FALSE
  ) +
  
  scale_colour_viridis_d(
    option = "H",
    direction = 1
  ) +
  
  scale_x_continuous(
    name = "Longitude (degree)",
    breaks = seq(-180, 180, by = 20)
  ) +
  
  scale_y_continuous(
    name = "Latitude (degree)",
    breaks = seq(-90, 90, by = 20)
  ) +
  
  coord_sf(
    xlim = c(-180, 180),
    ylim = c(-90, 90),
    expand = FALSE,
    label_graticule = "SW"
  ) +
  
  theme_classic() +
  
  theme(
    axis.title = element_text(size = 12),
    axis.text = element_text(size = 14),
    axis.ticks = element_line(linewidth = 0.4),
    
    panel.grid.major = element_line(
      linewidth = 0.2,
      colour = "grey85"
    ),
    panel.grid.minor = element_blank(),
    
    panel.border = element_rect(
      colour = "black",
      fill = NA,
      linewidth = 0.8
    )
  )
    
ggsave(
  filename = "Solenidae_Distribution.tiff",
  plot = last_plot(),
  width = 12,
  height = 7,
  units = "in",
  dpi = 600
)

# Plot (records) latitude against depth
data_plot <- Solenidaedata_clean_taxmatch %>%
  filter(
    !is.na(decimalLatitude),
    !is.na(depth),
    depth >= 0,
    depth <= 80
  )

depth_summary <- data_plot %>%
  mutate(
    depth_bin = floor(depth / 10) * 10,
    depth_mid = depth_bin + 5
  ) %>%
  group_by(depth_bin, depth_mid) %>%
  summarise(
    species_richness = n_distinct(scientificName, na.rm = TRUE),
    records = n(),
    .groups = "drop"
  )

p1 <- ggplot(
  data_plot,
  aes(
    x = decimalLatitude,
    y = depth,
    colour = scientificName
  )
) +
  geom_jitter(
    width = 0.4,
    height = 0,
    size = 2.5,
    alpha = 0.6,
    show.legend = FALSE
  ) +
  scale_colour_viridis_d(
    option = "H",
    direction = 1
  ) +
  scale_x_continuous(
    name = "Latitude (degree)",
    breaks = seq(-90, 90, by = 10)
  ) +
  scale_y_reverse(
    name = "Depth (m)",
    breaks = seq(0, 80, by = 20),
    limits = c(80, 0)
  ) +
  theme_classic() +
  theme(
    axis.text = element_text(size = 18),
    axis.title = element_text(size = 20)
  )

p2 <- ggplot(
  depth_summary,
  aes(
    x = species_richness,
    y = depth_mid
  )
) +
  geom_col(
    width = 9,
    fill = "grey50",
    alpha = 0.65
  ) +
  geom_text(
    aes(
      x = species_richness + 2,
      label = species_richness
    ),
    hjust = 0,
    size = 3
  ) +
  scale_y_reverse(
    breaks = seq(0, 80, by = 20),
    limits = c(80, 0),
    expand = c(0, 0)
  ) +
  scale_x_continuous(
    name = "Number of species",
    expand = expansion(mult = c(0, 0.15))
  ) +
  labs(y = NULL) +
  theme_classic() +
  theme(
    axis.text = element_text(size = 18),
    axis.title = element_text(size = 20)
  )

p3 <- ggplot(
  depth_summary,
  aes(
    x = records,
    y = depth_mid
  )
) +
  geom_col(
    width = 9,
    fill = "grey70",
    alpha = 0.7
  ) +
  scale_y_reverse(
    breaks = seq(0, 80, by = 20),
    limits = c(80, 0),
    expand = c(0, 0)
  ) +
  scale_x_continuous(
    name = "Number of records",
    expand = expansion(mult = c(0, 0.05))
  ) +
  labs(y = NULL) +
  theme_classic() +
  theme(
    axis.text = element_text(size = 18),
    axis.title = element_text(size = 20)
  )

depth_figure <- (p1 | p2 | p3) +
  plot_layout(
    widths = c(3, 1.3, 1.3)
  ) +
  plot_annotation(tag_levels = "a")

depth_figure <- depth_figure &
  theme(
    plot.tag = element_text(size = 30)
  )


ggsave(
  filename = "Solenidae_Latitude_Depth_Richness_Effort.tiff",
  plot = depth_figure,
  width = 14,
  height = 7,
  units = "in",
  dpi = 600,
  compression = "lzw"
)
 
#........................
#Biodiversity analyses
#........................

#Add lat_5 and depth_interval columns
Solenidaedata_clean_taxmatch$phylum <- as.factor(Solenidaedata_clean_taxmatch$phylum)
Solenidaedata_clean_taxmatch <- mutate(Solenidaedata_clean_taxmatch, lat_5 = ceiling(decimalLatitude/5) * 5)
Solenidaedata_clean_taxmatch <- mutate(Solenidaedata_clean_taxmatch, dep_rnd = floor(depth/10) * 10)

#Count the total number of scientific names per latitude bin
total_counts_per_lat <- Solenidaedata_clean_taxmatch %>%
  group_by(lat_5) %>%
  summarise(total_scientific_names = n())

#Calculate max, min, and mean of the total number of scientific names
summary_stats <- total_counts_per_lat %>%
  summarise(
    max_count = max(total_scientific_names),
    min_count = min(total_scientific_names),
    mean_count = mean(total_scientific_names)
  )
print(summary_stats) #   max_count min_count mean_count
                     #     623         9       193

# Count the number of unique scientific names per latitude bin
unique_counts_per_lat <- Solenidaedata_clean_taxmatch %>%
  group_by(lat_5) %>%
  summarise(unique_scientific_names = n_distinct(scientificName))

# Calculate max, min, and mean of the unique scientific name counts
summary_stats <- unique_counts_per_lat %>%
  summarise(
    max_count = max(unique_scientific_names),
    min_count = min(unique_scientific_names),
    mean_count = mean(unique_scientific_names)
  )
print(summary_stats) #   max_count min_count mean_count
                     #     25         2       9.81

# Count the total number of scientific names per depth bin
total_counts_per_dep <- Solenidaedata_clean_taxmatch %>%
  group_by(dep_rnd) %>%
  summarise(total_scientific_names = n())

# Calculate max, min, and mean of the total number of scientific names
summary_stats <- total_counts_per_dep %>%
  summarise(
    max_count = max(total_scientific_names),
    min_count = min(total_scientific_names),
    mean_count = mean(total_scientific_names)
  )
print(summary_stats) #   max_count min_count mean_count
                     #   3704         2       450

# Count the number of unique scientific names per depth bin
unique_counts_per_dep <- Solenidaedata_clean_taxmatch %>%
  group_by(dep_rnd) %>%
  summarise(unique_scientific_names = n_distinct(scientificName))

# Calculate max, min, and mean of the unique scientific name counts
summary_stats <- unique_counts_per_dep %>%
  summarise(
    max_count = max(unique_scientific_names),
    min_count = min(unique_scientific_names),
    mean_count = mean(unique_scientific_names)
  )
print(summary_stats) #   max_count min_count mean_count
                     #     57         1       12.9
..............................................
# Plot records per latitude (with Kernel Estimation)
# Step 1: Calculate the histogram
hist_data_lat <- hist(Solenidaedata_clean_taxmatch$lat_5, breaks=seq(-90, 90, by=5), plot=FALSE)

# Step 2: Find the maximum count
print(c(max_count_lat = max(hist_data_lat$counts),
        min_count_lat = min(hist_data_lat$counts),
        mean_count_lat = mean(hist_data_lat$counts)))

# Perform the Anderson-Darling test
ad_test <- ad.test(hist_data_lat$counts)
print(ad_test) # A = 3.3213, p-value = 1.715e-08

# Perform the Dip Test for unimodality
dip_test <- dip.test(hist_data_lat$counts)
print(dip_test) # D = 0.03855, p-value = 0.9754

# Define axis limits for consistency
x_limits <- c(-90, 90) # Latitude range
y_limits <- c(0, 650) # Fixed y-axis limits

# Calculate relative annotation positions
x_annotate <- x_limits[1] + 0.26 * diff(x_limits)  # 30% from the left
y_annotate_ad <- y_limits[1] + 0.92 * diff(y_limits)  # 95% up from the bottom
y_annotate_dip <- y_limits[1] + 0.82 * diff(y_limits)  # 85% up from the bottom

# Create the plot
# Create the plot
Lat_Num_Rec_Kernel_col <- ggplot(
  Solenidaedata_clean_taxmatch,
  aes(x = lat_5)) + geom_histogram(binwidth = 5, fill = "lightgrey",  color = "black", position = "identity"
  ) + geom_density(aes(y = after_stat(density * nrow(Solenidaedata_clean_taxmatch) * 5)
    ), bw = 10, alpha = 0.5, fill = NA, color = "#1a80bb", linewidth = 1.5) +
  scale_y_continuous(
    limits = c(0, 650),
    breaks = seq(0, 650, by = 100),
    expand = c(0, 0),
    labels = scales::label_comma()
  ) +
  scale_x_continuous(
    limits = c(-90, 90),
    breaks = seq(-90, 90, by = 20),
    expand = c(0, 0)
  ) +
  xlab("Latitude (degree)") +
  ylab("Number of Records") +
  theme_bw() +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major = element_blank(),
    axis.title = element_text(size = 24, color = "black"),
    axis.text = element_text(size = 20, color = "black"),
    axis.line = element_line(color = "black"),
    axis.ticks = element_line(color = "black"),
    plot.margin = unit(c(1, 1, 1, 1), "cm")
  ) +
  annotate("text", x = x_annotate,  y = y_annotate_ad,
    label = paste("AD-p:", formatC(ad_test$p.value, format = "e", digits = 2)
    ),
    size = 8,
    color = "black"
  ) + annotate(
    "text",
    x = x_annotate,
    y = y_annotate_dip,
    label = paste(
      "Dip-p:",
      formatC(dip_test$p.value, format = "e", digits = 2) ), size = 8,
    color = "black" )

ggsave("Lat_Num_Rec_Kernel_col.tiff", plot = Lat_Num_Rec_Kernel_col, width = 7, height = 5, dpi = 600)

# Plot species numbers per latitude (with Kernel Estimation)
# Filter distinct values
distinct_data <- distinct(Solenidaedata_clean_taxmatch, scientificName, lat_5, .keep_all = TRUE)

# Remove any non-finite values
distinct_data <- distinct_data %>% filter(is.finite(lat_5))

# Count distinct scientific names in each 5-degree latitude bin
name_counts <- distinct_data %>%
  group_by(lat_5) %>%
  summarise(distinct_names = n_distinct(scientificName)) %>%
  ungroup()

# Perform the Anderson-Darling test
ad_test_1 <- ad.test(name_counts$distinct_names) 
print(ad_test_1) # A = 0.34989, p-value = 0.4389

# Perform the Dip Test for unimodality
dip_test_1 <- dip.test(name_counts$distinct_names)
print(dip_test_1) # D = 0.063492, p-value = 0.7274

# Define axis limits for consistency
x_limits <- c(-90, 90) # Latitude range
y_limits <- c(0, 30) # Fixed y-axis limits

# Calculate relative annotation positions
x_annotate <- x_limits[1] + 0.26 * diff(x_limits)  # 30% from the left
y_annotate_ad <- y_limits[1] + 0.92 * diff(y_limits)  # 95% up from the bottom
y_annotate_dip <- y_limits[1] + 0.82 * diff(y_limits)  # 85% up from the bottom

# Create the plot
Lat_Num_Spe_Kernel_col <-
  ggplot(distinct_data, aes(x = lat_5)) +
  geom_histogram(binwidth = 5, fill = "lightgrey", color = "black", position = "identity") +
    geom_density(
      data = distinct_data,
      aes(
        x = decimalLatitude,
        y = after_stat(density * nrow(distinct_data) * 5)
      ), bw = 10, alpha = 0.5, fill = NA, color = "#1a80bb",  linewidth = 1.5) +
  scale_y_continuous(limits=c(0, 30), breaks=seq(0, 30, by=5), expand = c(0, 0), labels = scales::label_comma()) +
  scale_x_continuous(limits=c(-90, 90), breaks=seq(-90, 90, by=20), expand = c(0, 0)) +
  xlab("Latitude (degree)") + ylab("Number of Species") +
  theme_bw() +   
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major = element_blank(),
    axis.title = element_text(size = 24, color = "black"),     
    axis.text = element_text(size = 20, color = "black"),
    axis.line = element_line(color = "black"),  # Change axis lines to black
    axis.ticks = element_line(color = "black"),  # Change axis ticks to black
    plot.margin = unit(c(1, 1, 1, 1), "cm")  # Adjust the plot margins to add space around the plot
  ) +
  annotate("text", x = x_annotate, y = y_annotate_ad, 
           label = paste("AD-p:", formatC(ad_test_1$p.value, format = "e", digits = 2)), 
           size = 8, color = "black") +
  annotate("text", x = x_annotate, y = y_annotate_dip, 
           label = paste("Dip-p:", formatC(dip_test_1$p.value, format = "e", digits = 2)), 
           size = 8, color = "black")

ggsave("Lat_Num_Spe_Kernel_col.tiff", plot = Lat_Num_Spe_Kernel_col, width = 7, height = 5, dpi = 600)

# Plot records per depth (with Kernel Estimation)
# Count occurrence records with depth
sum(!is.na(Solenidaedata_clean_taxmatch$depth)) # 343

# In percent
n_depth <- sum(!is.na(Solenidaedata_clean_taxmatch$depth))
n_total <- nrow(Solenidaedata_clean_taxmatch)

n_depth
n_total
100 * n_depth / n_total # 8.475414%

sum(Solenidaedata_clean_taxmatch$dep_rnd >= 0 &
      Solenidaedata_clean_taxmatch$dep_rnd <= 10, na.rm = TRUE) # 231

# Step 1: Calculate the histogram
hist_data_dep <- hist(Solenidaedata_clean_taxmatch$dep_rnd, breaks=seq(0, 100, by=10), plot=FALSE)

# Step 2: Find the maximum count
print(c(max_count_dep = max(hist_data_dep$counts),
        min_count_dep = min(hist_data_dep$counts),
        mean_count_dep = mean(hist_data_dep$counts)))

# Perform the Anderson-Darling test
ad_test_2 <- ad.test(hist_data_dep$counts)
print(ad_test_2) # A = 1.9918, p-value = 1.516e-05

# Perform the Dip Test for unimodality
dip_test_2 <- dip.test(hist_data_dep$counts)
print(dip_test_2) # D = 0.072414, p-value = 0.9453

# Define axis limits for consistency
x_limits <- c(0, 100) # Depth range
y_limits <- c(0, 260) # Fixed y-axis limits

# Calculate relative annotation positions
x_annotate <- x_limits[1] + 0.26 * diff(x_limits)  # 30% from the left
y_annotate_ad <- y_limits[1] + 0.92 * diff(y_limits)  # 95% up from the bottom
y_annotate_dip <- y_limits[1] + 0.82 * diff(y_limits)  # 85% up from the bottom

# Create the plotting dataset:
data_dep <- Solenidaedata_clean_taxmatch %>%
  filter(!is.na(dep_rnd), dep_rnd >= 0, dep_rnd <= 100)

# Create the plot 
Dep_Num_Rec_Kernel_col <- ggplot(Solenidaedata_clean_taxmatch, aes(x = dep_rnd)) +
  geom_histogram(binwidth = 10, boundary = 0, fill = "lightgrey", color = "black", position = "identity") +
  geom_density(aes(y = after_stat(density * nrow(data_dep) * 10)), bw = 10, alpha = 0.5, fill = NA,
    color = "#1a80bb",linewidth = 1.5) +
  scale_y_continuous(limits=c(0, 260), breaks=seq(0, 260, by=40), expand = c(0, 0), labels = scales::label_comma()) +
  scale_x_continuous(limits=c(0, 100), breaks=seq(0, 100, by=20), expand = c(0, 0), labels = scales::label_comma()) +
  xlab("Depth (m)") + ylab("Number of Records") +
  theme_bw() +   
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major = element_blank(),
    axis.title = element_text(size = 24, color = "black"),     
    axis.text = element_text(size = 20, color = "black"),
    axis.line = element_line(color = "black"),  # Change axis lines to black
    axis.ticks = element_line(color = "black"),  # Change axis ticks to black
    plot.margin = unit(c(1, 1, 1, 1), "cm")  # Adjust the plot margins to add space around the plot
  ) +
  annotate("text", x = x_annotate, y = y_annotate_ad, 
           label = paste("AD-p:", formatC(ad_test_2$p.value, format = "e", digits = 2)), 
           size = 8, color = "black") +
  annotate("text", x = x_annotate, y = y_annotate_dip, 
           label = paste("Dip-p:", formatC(dip_test_2$p.value, format = "e", digits = 2)), 
           size = 8, color = "black")

ggsave("Dep_Num_Rec_Kernel_col.tiff", plot = Dep_Num_Rec_Kernel_col, width = 7, height = 5, dpi = 600)

# Plot species per depth (with Kernel Estimation)
# Filter distinct values
distinct_data_2 <- distinct(Solenidaedata_clean_taxmatch, scientificName, dep_rnd, .keep_all = TRUE)

# Remove any non-finite values
distinct_data_2 <- distinct_data_2 %>% filter(is.finite(dep_rnd))

# Count distinct scientific names in each 100 m depth bin
name_counts_2 <- distinct_data_2 %>%
  group_by(dep_rnd) %>%
  summarise(distinct_names_2 = n_distinct(scientificName)) %>%
  ungroup()

# Step 2: Find the maximum count
print(c(max_count_dep = max(name_counts_2$distinct_names_2),
        min_count_dep = min(name_counts_2$distinct_names_2),
        mean_count_dep = mean(name_counts_2$distinct_names_2)))

# Perform the Anderson-Darling test
ad_test_3 <- ad.test(name_counts_2$distinct_names_2)
print(ad_test_3) # A = 0.33593, p-value = 0.4051

# Perform the Dip Test for unimodality
dip_test_3 <- dip.test(name_counts_2$distinct_names_2)
print(dip_test_3) # D = 0.13194, p-value = 0.1608

# Define axis limits for consistency
x_limits <- c(0, 100) # Depth range
y_limits <- c(0, 18) # Fixed y-axis limits

# Calculate relative annotation positions
x_annotate <- x_limits[1] + 0.25 * diff(x_limits)  # 30% from the left
y_annotate_ad <- y_limits[1] + 0.92 * diff(y_limits)  # 95% up from the bottom
y_annotate_dip <- y_limits[1] + 0.82 * diff(y_limits)  # 85% up from the bottom

#Create the plot
Dep_Num_Spe_Kernel_col <- ggplot(distinct_data_2, aes(x = dep_rnd)) +
  geom_histogram(binwidth = 10, fill = "lightgrey", color = "black", position = "identity") +
  geom_density(aes(y = after_stat(density * nrow(distinct_data_2) * 5)), bw = 10,
               alpha = 0.5, fill = "NA", color = "#1a80bb", size = 1.5) +
  scale_y_continuous(limits = c(0, 18), breaks = seq(0, 18, by = 3), expand = c(0, 0), labels = scales::label_comma()) +
  scale_x_continuous(limits = c(0, 100), breaks = seq(0, 100, by=20), expand = c(0, 0), labels = scales::label_comma()) +
  xlab("Depth (m)") + ylab("Number of Species") +
  theme_bw() +   
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major = element_blank(),
    axis.title = element_text(size = 24, color = "black"),     
    axis.text = element_text(size = 20, color = "black"),
    axis.line = element_line(color = "black"),  # Change axis lines to black
    axis.ticks = element_line(color = "black"),  # Change axis ticks to black
    plot.margin = unit(c(1, 1, 1, 1), "cm")  # Adjust the plot margins to add space around the plot
  ) +
  annotate("text", x = x_annotate, y = y_annotate_ad, 
           label = paste("AD-p:", formatC(ad_test_3$p.value, format = "e", digits = 2)), 
           size = 8, color = "black") +
  annotate("text", x = x_annotate, y = y_annotate_dip, 
           label = paste("Dip-p:", formatC(dip_test_3$p.value, format = "e", digits = 2)), 
           size = 8, color = "black")

ggsave("Dep_Num_Spe_Kernel_col.tiff", plot = Dep_Num_Spe_Kernel_col, width = 7, height = 5, dpi = 600)

.........................................
# Matrix Function
data <- Solenidaedata_clean_taxmatch 

data <- data %>%
  filter(!is.na(decimalLongitude) & !is.na(decimalLatitude)) # remove NAs

data$scientificName <- stri_encode(data$scientificName, "", "UTF-8") # re-mark encodings


# Define the function
presence_absence_matrix <- function(data, sites.col, sp.col, keep.n = TRUE) {
  stopifnot(
    length(sites.col) == 1,
    length(sp.col) == 1,
    sites.col != sp.col,
    (sites.col %in% 1:ncol(data) || sites.col %in% names(data)),
    (sp.col %in% 1:ncol(data) || sp.col %in% names(data)),
    is.logical(keep.n)
  )
  
  if (is.character(sites.col)) sites.col <- match(sites.col, names(data))
  if (is.character(sp.col)) sp.col <- match(sp.col, names(data))
  
  presabs <- table(data[, c(sites.col, sp.col)])
  presabs <- as.data.frame.matrix(unclass(presabs))
  
  if (!keep.n) presabs[presabs > 1] <- 1
  
  presabs <- data.frame(row.names(presabs), presabs)
  names(presabs)[1] <- names(data)[sites.col]
  rownames(presabs) <- NULL
  
  return(presabs)
}


# Matrix
lat <- presence_absence_matrix(
  subset(data), 
  "lat_5", 
  "scientificName"
) %>%  
  column_to_rownames(var = "lat_5")

dep <- presence_absence_matrix(
  subset(data), 
  "dep_rnd", 
  "scientificName"
) %>%  
  column_to_rownames(var = "dep_rnd")


# Abundance 
abu_lat <- apply(lat, MARGIN = 1, sum)

# Gamma richness: per 5-degree latitudinal bands
sp_rich_lat <- specnumber(lat)


# Keep only latitude bands with at least 50 records
lat_50 <- lat[rowSums(lat) >= 50, ]


# Rarefaction curves
tiff("Rarefaction_Solenidae.tiff", width = 6, height = 6, units = "in", res = 600)

rarecurve(
  lat_50,
  step = 20,
  sample = 50,
  col = "black",
  cex = 0.6,
  label = TRUE,
  ylab = "Expected number of species"
)

dev.off()

# ES50 for latitude bands with at least 50 records
ES50_lat <- lat_50 %>%
  rarefy(sample = 50, MARGIN = 1)

# ES50
tiff(
  "ES50_Latitude.tiff",
  width = 6,
  height = 6,
  units = "in",
  res = 600,
  compression = "lzw"
)

ES50_lat %>%
  as.data.frame() %>%
  rownames_to_column("Latitude") %>%
  mutate(Latitude = as.numeric(Latitude)) %>%
  
  ggplot(aes(x = Latitude, y = .)) +
  
  geom_col(
    fill = "lightgrey",
    color = "black"
  ) +
  
  scale_y_continuous(
    limits = c(0, 20),
    breaks = seq(0, 20, by = 5),
    expand = c(0, 0)
  ) +
  
  scale_x_continuous(
    limits = c(-90, 90),
    breaks = seq(-90, 90, by = 20),
    expand = c(0, 0)
  ) +
  
  xlab("Latitude (degree)") +
  ylab("ES 50") +
  
  theme_bw() +
  
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major = element_blank(),
    axis.title = element_text(size = 22, color = "black"),
    axis.text = element_text(size = 18, color = "black"),
    axis.line = element_line(color = "black"),
    axis.ticks = element_line(color = "black"),
    plot.margin = unit(c(1, 1, 1, 1), "cm")
  )

dev.off()

# Add Kernel Density
# Rarefaction process Latitude
lat_rarefied <- lat_50 %>%
  rarefy(sample = 50, MARGIN = 1) %>%
  as.data.frame() %>%
  rownames_to_column("Latitude") %>%
  mutate(Latitude = as.numeric(Latitude))

# Perform the Anderson-Darling test
ad_test_4 <- ad.test(lat_rarefied$.)
print(ad_test_4) # A = 0.31829, p-value = 0.506

# Perform the Dip Test for unimodality
dip_test_4 <- dip.test(lat_rarefied$.)
print(dip_test_4) # D = 0.092789, p-value = 0.2653

# Define axis limits for consistency
x_limits <- c(-90, 90) # Latitude range
y_limits <- c(0, 20) # Fixed y-axis limits

# Calculate relative annotation positions
x_annotate <- x_limits[1] + 0.24 * diff(x_limits)  # 30% from the left
y_annotate_ad <- y_limits[1] + 0.92 * diff(y_limits)  # 95% up from the bottom
y_annotate_dip <- y_limits[1] + 0.82 * diff(y_limits)  # 85% up from the bottom

# Create the plot
Lat_ES50_Kernel_col <- ggplot(lat_rarefied, aes(x = Latitude, y = .)) +
  geom_col(fill = "lightgrey", color = "black", width = 5) +
  geom_density(aes(y = after_stat(density * nrow(lat_rarefied) * 20)),
    bw = 10, alpha = 0.5, fill = NA, color = "#1a80bb",
    linewidth = 1.5) + scale_y_continuous(limits = c(0, 20), breaks = seq(0, 20, by = 3),
    expand = c(0, 0)) +
  scale_x_continuous(limits = c(-90, 90), breaks = seq(-90, 90, by = 20), expand = c(0, 0)) +
  xlab("Latitude (degree)") + ylab("ES 50") +
  theme_bw() +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major = element_blank(),
    axis.title = element_text(size = 24, color = "black"),     
    axis.text = element_text(size = 20, color = "black"),
    axis.line = element_line(color = "black"),  # Change axis lines to black
    axis.ticks = element_line(color = "black"),  # Change axis ticks to black
    plot.margin = unit(c(1, 1, 1, 1), "cm")  # Adjust the plot margins to add space around the plot
  ) +
  annotate("text", x = x_annotate, y = y_annotate_ad, 
           label = paste("AD-p:", formatC(ad_test_4$p.value, format = "e", digits = 2)), 
           size = 8, color = "black") +
  annotate("text", x = x_annotate, y = y_annotate_dip, 
           label = paste("Dip-p:", formatC(dip_test_4$p.value, format = "e", digits = 2)), 
           size = 8, color = "black")

ggsave("Lat_ES50_Kernel_col.tiff", plot = Lat_ES50_Kernel_col, width = 7, height = 5, dpi = 600)

# Rarefaction process Depth
# Calculate row totals
#row_totals <- rowSums(dep)

# Print row totals for verification
#print(row_totals)

# Filter out rows with fewer than 50 samples
#dep_filtered <- dep[row_totals >= 15, ]

# Check if any rows remain after filtering
#if (nrow(dep_filtered) == 0) {
  #stop("No rows with at least 15 samples available for rarefaction.")
#}

# Perform rarefaction
#dep_rarefied <- dep_filtered %>%
  #rarefy(sample = 15, MARGIN = 1) %>%
  #as.data.frame() %>%
  #rownames_to_column("Depth") %>%
  #mutate(Depth = as.numeric(Depth))


# Perform the Anderson-Darling test
#ad_test_5 <- ad.test(dep_rarefied$.) # Error in ad.test(dep_rarefied$.) : sample size must be greater than 7
#print(ad_test_5) # A = 3.804, p-value = 1.413e-09

# Perform the Dip Test for unimodality
#dip_test_5 <- dip.test(dep_rarefied$.)
#print(dip_test_5) # D = 0.041463, p-value = 0.4656


# Define a 5-color gradient
custom_colors <- c("#D9F1F4", "#66CCCC", "#B89DD6", "#E8893D", "#d73027")

# Define a function to create a presence-absence matrix
presence_absence_matrix <- function(data, sites.col, sp.col, keep.n = TRUE) {
  stopifnot(
    length(sites.col) == 1,
    length(sp.col) == 1,
    sites.col != sp.col,
    (sites.col %in% 1:ncol(data) || sites.col %in% names(data)),
    (sp.col %in% 1:ncol(data) || sp.col %in% names(data)),
    is.logical(keep.n)
  )
  
  if (is.character(sites.col)) sites.col <- match(sites.col, names(data))
  if (is.character(sp.col)) sp.col <- match(sp.col, names(data))
  
  presabs <- table(data[, c(sites.col, sp.col)])
  presabs <- as.data.frame.matrix(unclass(presabs))
  
  if (!keep.n) presabs[presabs > 1] <- 1
  
  presabs <- data.frame(row.names(presabs), presabs)
  names(presabs)[1] <- names(data)[sites.col]
  rownames(presabs) <- NULL
  
  return(presabs)
}

# read the shapefiles
sf_cat <- st_read("hexgrid4_rev.shp")
sf_data <- data[, c("scientificName", "decimalLatitude", "decimalLongitude")]
sf_data <- sf_data %>% st_as_sf(coords = c('decimalLongitude','decimalLatitude'))
st_crs(sf_data) = 4326
st_crs(sf_cat) <- 4326

# Define the spatial function with adjusted rarefaction calculation
spatial_fun <- function(sf_land, sf_cat, sf_data)

# Step 2: Perform spatial joins and summarizations
spatial_data <- st_join(sf_cat, sf_data, join = st_contains) %>% 
  group_by(ID) %>% 
  dplyr::summarize(
    Num_Records = length(scientificName[!is.na(scientificName)]), 
    Num_Species = n_distinct(scientificName[!is.na(scientificName)])
  )
spatial_data <- spatial_data %>% as.data.frame()
spatial_data <- spatial_data[rowSums(spatial_data[, c("Num_Records", "Num_Species")]) != 0, ]

# Step 3: Create presence-absence matrix
spatial_data2 <- st_join(sf_data, sf_cat, join = st_intersects) %>% 
  as.data.frame() %>% 
  presence_absence_matrix("ID", "scientificName")

# Step 4: Filter out rows with less than 50 samples
spatial_data2 <- spatial_data2[rowSums(spatial_data2[,-1]) >= 50, ]

# Step 5: Adjust rarefaction sample size to a reasonable threshold
min_sample_size <- min(rowSums(spatial_data2[,-1]))

# Step 6: Perform rarefaction with adjusted sample size
spatial_data_r <- rarefy(spatial_data2[,-1], sample = min_sample_size, MARGIN = 1) %>% 
  as.data.frame()
colnames(spatial_data_r) <- "ES50"
spatial_data_r$ID <- spatial_data2$ID

# Step 7: Merge data
spatial_data <- spatial_data %>% 
  merge(spatial_data_r, by = "ID", all.x = TRUE) %>% 
  st_as_sf()

# Calculate other Indices
calculate_indices <- function(spatial_data2) {
  chao1 <- estimateR(spatial_data2[,-1])["S.chao1", ]
  ace <- estimateR(spatial_data2[,-1])["S.ACE", ]
  weight_adjustment <- diversity(spatial_data2[,-1], index = "invsimpson")
  data.frame(ID = spatial_data2$ID, Chao1 = chao1, ACE = ace, Weighted = weight_adjustment)
}

add_indices_to_data <- function(spatial_data, estimate_results) {
  merge(spatial_data, estimate_results, by = "ID", all.x = TRUE)
}

# Add the Indices to the data
estimate_results <- calculate_indices(spatial_data2)
spatial_data <- add_indices_to_data(spatial_data, estimate_results)

summary(spatial_data)


# Step 8: Create bins for each variable with labels showing the ranges
breaks_Num_Records <- c(1, 50, 100, 200, 300, 369)
labels_Num_Records <- c("1-50", "50-100", "100-200", "200-300", "300-369")
spatial_data$Num_Records_Binned <- cut(spatial_data$Num_Records, 
                                       breaks = breaks_Num_Records, 
                                       labels = labels_Num_Records, 
                                       include.lowest = TRUE)

breaks_Num_Species <- c(1, 2, 3, 4, 5, 7)
labels_Num_Species <- c("1-2", "2-3", "3-4", "4-5", "5-7")
spatial_data$Num_Species_Binned <- cut(spatial_data$Num_Species, 
                                       breaks = breaks_Num_Species, 
                                       labels = labels_Num_Species, 
                                       include.lowest = TRUE)

breaks_ES50 <- c(1, 5, 10, 15, 20, 25)
labels_ES50 <- c("1-5", "5-10", "10-15", "15-20", "20-25")
spatial_data$ES50_Binned <- cut(spatial_data$ES50, 
                                breaks = breaks_ES50, 
                                labels = labels_ES50, 
                                include.lowest = TRUE)

breaks_Chao1 <- c(1, 2, 3, 4, 5, 9)
labels_Chao1 <- c("1-2", "2-3", "3-4", "4-5", "5-9")
spatial_data$Chao1_Binned <- cut(spatial_data$Chao1, 
                                 breaks = breaks_Chao1, 
                                 labels = labels_Chao1, 
                                 include.lowest = TRUE)

breaks_ACE <- c(1, 2, 4, 6, 8, 10.4)
labels_ACE <- c("1-2", "2-4", "4-6", "6-8", "8-10.4")
spatial_data$ACE_Binned <- cut(spatial_data$ACE, 
                               breaks = breaks_ACE, 
                               labels = labels_ACE, 
                               include.lowest = TRUE)

breaks_Weighted  <- c(1, 1.5, 2, 2.5, 3, 3.32)
labels_Weighted  <- c("1-1.5", "1.5-2", "2-2.5", "2.5-3", "3-3.32")
spatial_data$Weighted_Binned <- cut(spatial_data$Weighted, 
                                    breaks = breaks_Weighted, 
                                    labels = labels_Weighted, 
                                    include.lowest = TRUE)


# Step 9: Generate plots
plot1 <- ggplot() +
  geom_sf(data = sf_land, fill = "lightgrey") +
  geom_sf(data = spatial_data, aes(fill = Num_Records_Binned)) +
  scale_fill_manual(
    values = custom_colors,
    drop = FALSE,
    name = "Number of Records"
  ) +
  scale_x_continuous(
    breaks = seq(-180, 180, by = 20)
  ) +
  scale_y_continuous(
    breaks = seq(-90, 90, by = 20)
  ) +
  coord_sf(
    xlim = c(-180, 180),
    ylim = c(-90, 90),
    expand = FALSE
  ) +
  theme_bw() +
  theme(panel.border = element_rect(
    colour = "black",
    fill = NA,
    linewidth = 0.8
  ),
    legend.position = "bottom",
    legend.key.width = unit(0.5, "cm"),
    legend.key.height = unit(0.1, "cm"),
    legend.box.spacing = unit(0.02, "cm"),
    legend.text = element_text(size = 12),
    legend.title = element_text(size = 14)
  ) +
  guides(
    fill = guide_legend(
      keywidth = 0.5,
      keyheight = 0.5,
      title.position = "top",
      label.position = "bottom"
    )
  )

plot2 <- ggplot() +
  geom_sf(data = sf_land, fill = "lightgrey") +
  geom_sf(data = spatial_data, aes(fill = Num_Species_Binned)) +
  scale_fill_manual(values = custom_colors, name = "Number of Species") +
  scale_x_continuous(
    breaks = seq(-180, 180, by = 20)
  ) +
  scale_y_continuous(
    breaks = seq(-90, 90, by = 20)
  ) +
  coord_sf(
    xlim = c(-180, 180),
    ylim = c(-90, 90),
    expand = FALSE
  ) +
  theme_bw() +
  theme(
    panel.border = element_rect(
      colour = "black",
      fill = NA,
      linewidth = 0.8
    ),
    legend.position = "bottom",
    legend.key.width = unit(0.5, "cm"),
    legend.key.height = unit(0.1, "cm"),
    legend.box.spacing = unit(0.02, "cm"),
    legend.text = element_text(size = 12),
    legend.title = element_text(size = 14)
  ) +
  guides(
    fill = guide_legend(
      keywidth = 0.5,
      keyheight = 0.5,
      title.position = "top",
      label.position = "bottom"
    )
  )

# Filter out NA values in the data
spatial_data_filtered <- spatial_data %>% 
  dplyr::filter(!is.na(ES50_Binned))

plot3 <- ggplot() +
  geom_sf(data = sf_land, fill = "lightgrey") +
  geom_sf(data = spatial_data_filtered, aes(fill = ES50_Binned)) +
  scale_fill_manual(
    values = custom_colors,
    name = "ES50",
    na.value = "white"
  ) +
  scale_x_continuous(
    breaks = seq(-180, 180, by = 20)
  ) +
  scale_y_continuous(
    breaks = seq(-90, 90, by = 20)
  ) +
  coord_sf(
    xlim = c(-180, 180),
    ylim = c(-90, 90),
    expand = FALSE
  ) +
  theme_bw() +
  theme(
    panel.border = element_rect(
      colour = "black",
      fill = NA,
      linewidth = 0.8
    ),
    legend.position = "bottom",
    legend.key.width = unit(0.5, "cm"),
    legend.key.height = unit(0.1, "cm"),
    legend.box.spacing = unit(0.02, "cm"),
    legend.text = element_text(size = 12),
    legend.title = element_text(size = 14)
  ) +
  guides(
    fill = guide_legend(
      keywidth = 0.5,
      keyheight = 0.5,
      title.position = "top",
      label.position = "bottom"
    )
  )

spatial_data_filtered_2 <- spatial_data %>% 
  dplyr::filter(!is.na(Chao1_Binned))

plot4 <- ggplot() +
  geom_sf(data = sf_land, fill = "lightgrey") +
  geom_sf(data = spatial_data_filtered_2, aes(fill = Chao1_Binned)) +
  scale_fill_manual(
    values = custom_colors,
    name = "Chao1",
    na.value = "white",
    drop = FALSE
  ) +
  scale_x_continuous(
    breaks = seq(-180, 180, by = 20)
  ) +
  scale_y_continuous(
    breaks = seq(-90, 90, by = 20)
  ) +
  coord_sf(
    xlim = c(-180, 180),
    ylim = c(-90, 90),
    expand = FALSE
  ) +
  theme_bw() +
  theme(
    panel.border = element_rect(
      colour = "black",
      fill = NA,
      linewidth = 0.8
    ),
    legend.position = "bottom",
    legend.key.width = unit(0.5, "cm"),
    legend.key.height = unit(0.1, "cm"),
    legend.box.spacing = unit(0.02, "cm"),
    legend.text = element_text(size = 12),
    legend.title = element_text(size = 14)
  ) +
  guides(
    fill = guide_legend(
      keywidth = 0.5,
      keyheight = 0.5,
      title.position = "top",
      label.position = "bottom"
    )
  )

spatial_data_filtered_3 <- spatial_data %>% 
  dplyr::filter(!is.na(ACE_Binned))

plot5 <- ggplot() +
  geom_sf(data = sf_land, fill = "lightgrey") +
  geom_sf(data = spatial_data_filtered_3, aes(fill = ACE_Binned)) +
  scale_fill_manual(
    values = custom_colors,
    name = "ACE",
    na.value = "white",
    drop = FALSE
  ) +
  scale_x_continuous(
    breaks = seq(-180, 180, by = 20)
  ) +
  scale_y_continuous(
    breaks = seq(-90, 90, by = 20)
  ) +
  coord_sf(
    xlim = c(-180, 180),
    ylim = c(-90, 90),
    expand = FALSE
  ) +
  theme_bw() +
  theme(
    panel.border = element_rect(
      colour = "black",
      fill = NA,
      linewidth = 0.8
    ),
    legend.position = "bottom",
    legend.key.width = unit(0.5, "cm"),
    legend.key.height = unit(0.1, "cm"),
    legend.box.spacing = unit(0.02, "cm"),
    legend.text = element_text(size = 12),
    legend.title = element_text(size = 14)
  ) +
  guides(
    fill = guide_legend(
      keywidth = 0.5,
      keyheight = 0.5,
      title.position = "top",
      label.position = "bottom"
    )
  )

spatial_data_filtered_4 <- spatial_data %>% 
  dplyr::filter(!is.na(Weighted_Binned))

plot6 <- ggplot() +
  geom_sf(data = sf_land, fill = "lightgrey") +
  geom_sf(data = spatial_data_filtered_4, aes(fill = Weighted_Binned)) +
  scale_fill_manual(
    values = custom_colors,
    name = "Inverse Simpson",
    na.value = "white",
    drop = FALSE
  ) +
  scale_x_continuous(
    breaks = seq(-180, 180, by = 20)
  ) +
  scale_y_continuous(
    breaks = seq(-90, 90, by = 20)
  ) +
  coord_sf(
    xlim = c(-180, 180),
    ylim = c(-90, 90),
    expand = FALSE
  ) +
  theme_bw() +
  theme(
    panel.border = element_rect(
      colour = "black",
      fill = NA,
      linewidth = 0.8
    ),
    legend.position = "bottom",
    legend.key.width = unit(0.5, "cm"),
    legend.key.height = unit(0.1, "cm"),
    legend.box.spacing = unit(0.02, "cm"),
    legend.text = element_text(size = 12),
    legend.title = element_text(size = 14)
  ) +
  guides(
    fill = guide_legend(
      keywidth = 0.5,
      keyheight = 0.5,
      title.position = "top",
      label.position = "bottom"
    )
  )
# Display the plots
plot1 # Plot number of occurrences
ggsave("Num_Rec_Deep_1.tiff", plot = plot1, width = 6, height = 4, dpi = 600)
plot2 # Plot number of species
ggsave("Num_Spe_Deep_1.tiff", plot = plot2, width = 6, height = 4, dpi = 600)
plot3 # Plot ES50
ggsave("ES50_Deep_1.tiff", plot = plot3, width = 6, height = 4, dpi = 600)
plot4 # Plot Chao1
ggsave("Chao1_Deep_1.tiff", plot = plot4, width = 6, height = 4, dpi = 600)
plot5 # Plot ACE
ggsave("ACE_Deep_1.tiff", plot = plot5, width = 6, height = 4, dpi = 600)
plot6 # Plot Weighted
ggsave("Weighted_Deep_1.tiff", plot = plot6, width = 6, height = 4, dpi = 600)


# ============================================================
# SOLENIDAE DISTRIBUTION + SIX BIODIVERSITY MAPS
# ============================================================

library(ggplot2)
library(sf)
library(dplyr)
library(grid)
library(viridis)
library(patchwork)


# ============================================================
# 1. LOAD LAND SHAPEFILE
# ============================================================

sf_land <- st_read("ne_110m_land.shp")


# ============================================================
# 2. COMMON MAP SETTINGS
# ============================================================

# ============================================================
# 2. COMMON MAP SETTINGS
# ============================================================

map_x <- scale_x_continuous(
  name = "Longitude (degree)",
  breaks = seq(-180, 180, by = 20),
  labels = scales::label_number()
)

map_y <- scale_y_continuous(
  name = "Latitude (degree)",
  breaks = seq(-90, 90, by = 20),
  labels = scales::label_number()
)

map_coord <- coord_sf(
  xlim = c(-180, 180),
  ylim = c(-90, 90),
  expand = FALSE,
  label_axes = list(
    bottom = "E",
    left = "N"
  ),
  label_graticule = ""
)

# ============================================================
# 3. SOLENIDAE SPECIES DISTRIBUTION
# ============================================================

Solenidae_Distribution <- ggplot() +
  
  geom_sf(
    data = sf_land,
    fill = "lightgrey",
    colour = NA
  ) +
  
  geom_sf(
    data = sf_land,
    fill = NA,
    colour = "#4D4D4D",
    linewidth = 0.5
  ) +
  
  geom_point(
    data = Solenidaedata_clean_taxmatch,
    aes(
      x = decimalLongitude,
      y = decimalLatitude,
      colour = scientificName
    ),
    size = 2,
    show.legend = FALSE
  ) +
  
  scale_colour_viridis_d(
    option = "H",
    direction = 1
  ) +
  
  map_x +
  map_y +
  map_coord +
  map_theme


# ============================================================
# 4. CUSTOM COLOUR PALETTE
# ============================================================

custom_colors <- c(
  "#D9F1F4",
  "#66CCCC",
  "#B89DD6",
  "#E8893D",
  "#d73027"
)


# ============================================================
# 5. NUMBER OF RECORDS
# ============================================================

plot1 <- ggplot() +
  
  geom_sf(
    data = sf_land,
    fill = "lightgrey",
    colour = NA
  ) +
  
  geom_sf(
    data = sf_land,
    fill = NA,
    colour = "#4D4D4D",
    linewidth = 0.5
  ) +
  
  geom_sf(
    data = spatial_data,
    aes(fill = Num_Records_Binned)
  ) +
  
  scale_fill_manual(
    values = custom_colors,
    name = "Number of Records",
    drop = FALSE
  ) +
  
  map_x +
  map_y +
  map_coord +
  map_theme


# ============================================================
# 6. NUMBER OF SPECIES
# ============================================================

plot2 <- ggplot() +
  
  geom_sf(
    data = sf_land,
    fill = "lightgrey",
    colour = NA
  ) +
  
  geom_sf(
    data = sf_land,
    fill = NA,
    colour = "#4D4D4D",
    linewidth = 0.5
  ) +
  
  geom_sf(
    data = spatial_data,
    aes(fill = Num_Species_Binned)
  ) +
  
  scale_fill_manual(
    values = custom_colors,
    name = "Number of Species",
    drop = FALSE
  ) +
  
  map_x +
  map_y +
  map_coord +
  map_theme


# ============================================================
# 7. ES50
# ============================================================

plot3 <- ggplot() +
  
  geom_sf(
    data = sf_land,
    fill = "lightgrey",
    colour = NA
  ) +
  
  geom_sf(
    data = sf_land,
    fill = NA,
    colour = "#4D4D4D",
    linewidth = 0.5
  ) +
  
  geom_sf(
    data = spatial_data %>%
      filter(!is.na(ES50_Binned)),
    aes(fill = ES50_Binned)
  ) +
  
  scale_fill_manual(
    values = custom_colors,
    name = "ES50",
    drop = FALSE,
    na.value = "white"
  ) +
  
  map_x +
  map_y +
  map_coord +
  map_theme


# ============================================================
# 8. CHAO1
# ============================================================

plot4 <- ggplot() +
  
  geom_sf(
    data = sf_land,
    fill = "lightgrey",
    colour = NA
  ) +
  
  geom_sf(
    data = sf_land,
    fill = NA,
    colour = "#4D4D4D",
    linewidth = 0.5
  ) +
  
  geom_sf(
    data = spatial_data %>%
      filter(!is.na(Chao1_Binned)),
    aes(fill = Chao1_Binned)
  ) +
  
  scale_fill_manual(
    values = custom_colors,
    name = "Chao1",
    drop = FALSE,
    na.value = "white"
  ) +
  
  map_x +
  map_y +
  map_coord +
  map_theme


# ============================================================
# 9. ACE
# ============================================================

plot5 <- ggplot() +
  
  geom_sf(
    data = sf_land,
    fill = "lightgrey",
    colour = NA
  ) +
  
  geom_sf(
    data = sf_land,
    fill = NA,
    colour = "#4D4D4D",
    linewidth = 0.5
  ) +
  
  geom_sf(
    data = spatial_data %>%
      filter(!is.na(ACE_Binned)),
    aes(fill = ACE_Binned)
  ) +
  
  scale_fill_manual(
    values = custom_colors,
    name = "ACE",
    drop = FALSE,
    na.value = "white"
  ) +
  
  map_x +
  map_y +
  map_coord +
  map_theme


# ============================================================
# 10. INVERSE SIMPSON
# ============================================================

plot6 <- ggplot() +
  
  geom_sf(
    data = sf_land,
    fill = "lightgrey",
    colour = NA
  ) +
  
  geom_sf(
    data = sf_land,
    fill = NA,
    colour = "#4D4D4D",
    linewidth = 0.5
  ) +
  
  geom_sf(
    data = spatial_data %>%
      filter(!is.na(Weighted_Binned)),
    aes(fill = Weighted_Binned)
  ) +
  
  scale_fill_manual(
    values = custom_colors,
    name = "Inverse Simpson",
    drop = FALSE,
    na.value = "white"
  ) +
  
  map_x +
  map_y +
  map_coord +
  map_theme


# ============================================================
# 11. DISPLAY INDIVIDUAL MAPS
# ============================================================

Solenidae_Distribution

plot1
plot2
plot3
plot4
plot5
plot6


# ============================================================
# 12. PATCHWORK: DISTRIBUTION + RECORDS + SPECIES
# ============================================================
distribution_figure <- (
  Solenidae_Distribution /
    plot1 /
    plot2
) +
  plot_layout(
    ncol = 1
  ) +
  plot_annotation(
    tag_levels = "a"
  )

# Larger panel letters
distribution_figure <- distribution_figure &
  theme(
    plot.tag = element_text(
      size = 24,
      face = "plain"
    )
  )

# Display
distribution_figure


# ============================================================
# SAVE THREE-PANEL VERTICAL FIGURE
# ============================================================

ggsave(
  filename = "Solenidae_Distribution_Records_Species_Vertical.tiff",
  plot = distribution_figure,
  width = 7,
  height = 15,
  units = "in",
  dpi = 600,
  compression = "lzw"
)
