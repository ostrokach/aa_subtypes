#!/usr/bin/env Rscript
# Standardise data from Olson et al. 2014 (Protein G)
source('src/config.R')
source('src/study_standardising.R')

# Import and process data
meta <- read_yaml('data/studies/olson_2014_proteing/olson_2014_proteing.yaml')
wt <- read_xlsx('data/studies/olson_2014_proteing/raw/olson_2014_protein_g_counts.xlsx', range = "U3:V4") %>%
  rename(input_count = `Input Count`,
         selection_count = `Selection Count`)
E_wt <- wt$selection_count/wt$input_count

dm_data <- read_xlsx('data/studies/olson_2014_proteing/raw/olson_2014_protein_g_counts.xlsx', range = cell_limits(ul = c(3, 14), lr = c(NA, 18))) %>%
  rename(wt = `WT amino acid`,
         position = `Position`,
         mut = `Mutation`,
         input_count = `Input Count`,
         selection_count = `Selection Count`) %>%
  mutate(raw_score = log2(((selection_count + min(selection_count[selection_count > 0], na.rm = TRUE))/input_count)/E_wt),
         score = raw_score / -min(raw_score, na.rm = TRUE),
         class = get_variant_class(wt, mut))

# Save output
standardise_study(dm_data, meta$study, meta$transform)