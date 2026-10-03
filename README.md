# Reassessing the Global Diversity and Distribution of Razor Clams

R code and supporting data workflows for the global reassessment of **Solenidae (razor clams)**, integrating historical occurrence data with records from the **Ocean Biodiversity Information System (OBIS)** and the **Global Biodiversity Information Facility (GBIF)**.

The workflow combines taxonomic and geographic quality control with spatial biodiversity analyses to examine global occurrence patterns, species richness, sampling effort, latitudinal and bathymetric distributions, and sampling-standardised diversity.

---

## Overview

Razor clams (Bivalvia: Solenidae) are widely distributed marine and brackish-water bivalves, but their documented diversity and geographic distribution remain strongly influenced by uneven sampling, taxonomic changes, and differences in the availability of biodiversity data.

This repository contains the analytical workflow used to reassess the global diversity and distribution of Solenidae approximately a decade after the previous comprehensive assessment.

The workflow integrates:

1. The previously published global Solenidae dataset
2. Current occurrence records from OBIS
3. Current occurrence records from GBIF
4. Taxonomic validation against WoRMS
5. Geographic and bathymetric quality control
6. Spatial biodiversity analyses
7. Sampling-standardised diversity estimates
8. Latitudinal and bathymetric distribution analyses
9. Publication-quality maps and figures

The final quality-controlled dataset contains **4,047 occurrence records representing 57 accepted species**.

---

## Research questions

The analyses address several complementary questions:

* Where are Solenidae occurrence records concentrated globally?
* Where are the major geographic gaps in available occurrence data?
* How does observed species richness vary geographically?
* How does species richness change after accounting for differences in sampling effort?
* What are the latitudinal and bathymetric distributions of Solenidae occurrence records and species?
* Do occurrence and richness distributions show evidence of distinct modes?
* How do contemporary biodiversity data compare with the previous global assessment?

---

## Data sources

### Ocean Biodiversity Information System (OBIS)

Solenidae occurrence records are retrieved using the R package [`robis`](https://github.com/iobis/robis).

The workflow also retrieves dataset-level citation information from OBIS and stores the resulting dataset citations in:

```text
citations_OBIS.csv
citations_OBIS.html
```

### Global Biodiversity Information Facility (GBIF)

GBIF occurrence records are downloaded using [`rgbif`](https://docs.ropensci.org/rgbif/), using filters for:

* Solenidae
* present occurrences
* records with coordinates
* records without geospatial issues
* non-fossil records
* coordinate uncertainty <100 km
* records with non-negative depth information

### Previously published Solenidae dataset

The workflow incorporates the global Solenidae occurrence dataset published by:

> Saeedi, H. & Costello, M.J. (2019). A world dataset on the geographic distributions of Solenidae razor clams (Mollusca: Bivalvia). *Biodiversity Data Journal*, 7, e31375.

The dataset is used as the historical baseline for the reassessment.

---

## Data integration and quality control

The OBIS, GBIF, and previously published datasets are standardised and merged before analysis.

The workflow:

* Selects common occurrence fields
* Standardises coordinate precision
* Harmonises dataset identifiers
* Removes duplicate occurrences based on `occurrenceID`
* Retains the previously published record where duplicate occurrence IDs occur across datasets
* Removes absence records
* Removes fossil records
* Removes records lacking geographic coordinates
* Excludes records with coordinate uncertainty >100 km
* Checks occurrences against land polygons
* Checks depth against bathymetric information
* Excludes records deeper than 200 m
* Performs taxonomic matching against WoRMS
* Removes unaccepted taxa
* Standardises selected synonyms
* Removes records identified only to higher taxonomic levels

The final cleaned dataset is saved as:

```text
Solenidaedata_clean_taxmatch.csv
```

### Depth quality control

The workflow uses `obistools::check_depth()` to identify inconsistencies between reported occurrence depths and bathymetry.

Three records were identified as having reported depths deeper than predicted bathymetry at their coordinates. These records were retained because the reported depths originated from specimen records and the discrepancy could reflect generalized coordinates or local bathymetric variation.

No automatic correction was applied to these records.

---

## Taxonomic standardisation

Taxonomic names are checked using WoRMS through the `obistools` workflow.

The analysis removes unaccepted species and subsequently standardises selected names, including:

```text
Solen gemmelli       → Solen gemmellae
Solen krusensterni   → Solen krusensternii
```

Records identified only as:

```text
Solen
Solenidae
```

are excluded from species-level analyses.

The final dataset contains:

**4,047 occurrence records and 57 distinct accepted species.**

---

# Spatial analyses

## Global occurrence distribution

The cleaned occurrence records are mapped globally using `sf`, `ggplot2`, and Natural Earth land polygons.

The workflow produces:

```text
Solenidae_Distribution.tiff
```

and a combined figure showing:

* Solenidae occurrence distribution
* Number of occurrence records
* Number of species

```text
Solenidae_Distribution_Records_Species_Vertical.tiff
```

---

## Latitudinal analyses

Occurrence records are assigned to **5-degree latitude bands**.

For each latitude band, the workflow calculates:

* Number of occurrence records
* Number of unique species
* Species richness
* Sampling-standardised richness

The workflow also examines the distribution of occurrence records and species richness using **kernel density estimation**.

Outputs include:

```text
Lat_Num_Rec_Kernel_col.tiff
Lat_Num_Spe_Kernel_col.tiff
```

---

## Bathymetric analyses

Depth records are grouped into 10-m intervals for descriptive analyses.

The workflow evaluates:

* Number of records by depth
* Number of species by depth
* Latitudinal distribution of depth records
* Species richness by depth
* Sampling intensity across depth intervals

Because depth information is available for only a subset of the occurrence dataset, depth-related analyses are based on records with reported depth.

Outputs include:

```text
Solenidae_Latitude_Depth_Richness_Effort.tiff
Dep_Num_Rec_Kernel_col.tiff
Dep_Num_Spe_Kernel_col.tiff
```

---

# Biodiversity analyses

## Presence–absence matrices

Occurrence data are converted into presence–absence matrices by:

* 5-degree latitude band
* Depth interval
* Spatial grid cell

These matrices form the basis for richness, rarefaction, and diversity calculations.

A custom function is used to generate species-by-site matrices while retaining occurrence counts where required.

---

## Species richness

Observed species richness is calculated using the number of unique species within each spatial unit.

The spatial workflow calculates:

* Observed number of records
* Observed number of species
* ES50
* Chao2
* Inverse Simpson diversity

These metrics are subsequently mapped globally.

---

## Sampling-standardised diversity: ES50

To account for differences in sampling intensity, the analysis uses individual-based rarefaction.

Latitude bands containing at least **50 occurrence records** are retained for the ES50 analysis.

Expected species richness is estimated at a standard sample size of **50 records (ES50)**.

The workflow produces:

```text
Rarefaction_Solenidae.tiff
ES50_Latitude.tiff
Lat_ES50_Kernel_col.tiff
```

ES50 is also calculated for spatial grid cells where sufficient records are available.

---

## Spatial biodiversity grid

Occurrence records are spatially joined to a predefined hexagonal grid:

```text
hexgrid4_rev.shp
```

For each grid cell, the workflow calculates:

* Number of occurrence records
* Number of observed species
* ES50
* Chao2
* Inverse Simpson diversity

These metrics are converted into spatial classes and mapped globally.

The resulting maps include:

```text
Num_Rec_Deep_1.tiff
Num_Spe_Deep_1.tiff
ES50_Deep_1.tiff
Chao2_Deep_1.tiff
Weighted_Deep_1.tiff
```

The combined spatial biodiversity analyses allow comparison between **sampling intensity**, **observed richness**, and **sampling-standardised or estimated diversity**.

---

# Distributional statistics

The workflow uses statistical tests to investigate the distributional structure of Solenidae occurrence and richness.

### Anderson–Darling test

The Anderson–Darling test is used to evaluate deviations from normality in:

* Latitudinal occurrence distributions
* Latitudinal species-richness distributions
* Bathymetric occurrence distributions
* Bathymetric species-richness distributions
* ES50 distributions

### Hartigan's Dip test

Hartigan's Dip test is used to assess evidence for unimodality in the corresponding distributions.

Together with kernel density estimates, these analyses are used to investigate whether the distributions show evidence of uni-, bi-, or multimodal structure.

---

# Main outputs

The workflow generates three broad groups of outputs.

### 1. Occurrence and sampling

```text
Solenidae_Distribution.tiff
Solenidae_Latitude_Depth_Richness_Effort.tiff
Lat_Num_Rec_Kernel_col.tiff
Dep_Num_Rec_Kernel_col.tiff
```

### 2. Species richness and ES50

```text
Rarefaction_Solenidae.tiff
ES50_Latitude.tiff
Lat_ES50_Kernel_col.tiff
Lat_Num_Spe_Kernel_col.tiff
Dep_Num_Spe_Kernel_col.tiff
```

### 3. Spatial biodiversity metrics

```text
Num_Rec_Deep_1.tiff
Num_Spe_Deep_1.tiff
ES50_Deep_1.tiff
Chao2_Deep_1.tiff
Weighted_Deep_1.tiff
```

---

# R environment

The workflow was developed in **R**.

Major packages used include:

| Package     | Purpose                              |
| ----------- | ------------------------------------ |
| `robis`     | Access to OBIS occurrence data       |
| `obistools` | Biodiversity data quality control    |
| `rgbif`     | GBIF occurrence downloads            |
| `taxize`    | Taxonomic name resolution            |
| `tidyverse` | Data manipulation and workflow       |
| `sf`        | Spatial data processing              |
| `vegan`     | Rarefaction and biodiversity indices |
| `ggplot2`   | Visualisation                        |
| `viridis`   | Colour palettes                      |
| `maps`      | Mapping utilities                    |
| `nortest`   | Anderson–Darling tests               |
| `diptest`   | Hartigan's Dip test                  |
| `patchwork` | Combining figures                    |
| `stringi`   | Character encoding                   |
| `readxl`    | Excel data import                    |
| `openxlsx`  | Excel file handling                  |
| `pvclust`   | Cluster-analysis functionality       |
| `purrr`     | Functional programming               |

---

# Reproducibility

The workflow is designed to document the complete analytical pathway from biodiversity occurrence data to final figures:

```text
OBIS + GBIF + historical dataset
              ↓
      Data integration
              ↓
    Geographic quality control
              ↓
      Bathymetric QC
              ↓
      Taxonomic matching
              ↓
   Synonym standardisation
              ↓
      Clean Solenidae data
              ↓
 ┌────────────┼────────────┐
 ↓            ↓            ↓
Latitude    Depth       Spatial grid
analysis    analysis     analysis
 ↓            ↓            ↓
ES50       KDE/tests   ES50/Chao2/
             ↓         Inverse Simpson
             └────────────┘
                   ↓
              Final figures
```

---

# Files required for spatial analyses

Some analyses require spatial supporting files that are not generated by the R workflow itself.

These include:

```text
ne_110m_land.shp
hexgrid4_rev.shp
```

The corresponding shapefile components (`.shp`, `.shx`, `.dbf`, `.prj`, etc.) should be kept together.

---

# Important note on data access and credentials

The GBIF download requires a GBIF account.

**Do not store GBIF usernames, passwords, email credentials, API keys, or other authentication information directly in the R script or GitHub repository.**

For a public repository, credentials should instead be supplied through environment variables or a local `.Renviron` file that is excluded from version control.

For example:

```r
user <- Sys.getenv("GBIF_USER")
pwd  <- Sys.getenv("GBIF_PASSWORD")
email <- Sys.getenv("GBIF_EMAIL")
```

and `.Renviron` should be included in `.gitignore`.

---

# Associated publications

The workflow builds on the previous global Solenidae assessments:

**Saeedi, H., Dennis, T.E. & Costello, M.J. (2017).**
Bimodal latitudinal species richness and high endemicity of razor clams (Mollusca). *Journal of Biogeography*, 44, 592–604.
https://doi.org/10.1111/jbi.12903

**Saeedi, H., Basher, Z. & Costello, M.J. (2017).**
Modelling present and future global distributions of razor clams (Bivalvia: Solenidae). *Helgoland Marine Research*, 70, 23.
https://doi.org/10.1186/s10152-016-0477-4

**Saeedi, H. & Costello, M.J. (2019).**
A world dataset on the geographic distributions of Solenidae razor clams (Mollusca: Bivalvia). *Biodiversity Data Journal*, 7, e31375.
https://doi.org/10.3897/BDJ.7.e31375

The repository supports the current reassessment:

**Saeedi, H. & Costello, M.J.**
*Reassessing the Global Diversity and Distribution of Razor Clams After a Decade.*

---

# Citation

If you use the code, workflow, or derived datasets from this repository, please cite the associated publication and the original biodiversity data sources.

Dataset-specific citations retrieved from OBIS are provided in:

```text
citations_OBIS.csv
citations_OBIS.html
```

GBIF-derived records should be cited according to the GBIF citation associated with the corresponding download and dataset records.

---

# Author

**Hanieh Saeedi**

Senckenberg Data and Modelling Centre
Department of Marine Zoology
Senckenberg – Leibniz Institution for Biodiversity and Earth System Research (SGN)
Goethe University Frankfurt

ORCID: [0000-0002-4845-0241](https://orcid.org/0000-0002-4845-0241)

---

# Licence and data attribution

Please observe the individual licences and attribution requirements associated with the original OBIS, GBIF, and previously published datasets.

The licence for the code and derived materials should be specified in the repository's `LICENSE` file.
