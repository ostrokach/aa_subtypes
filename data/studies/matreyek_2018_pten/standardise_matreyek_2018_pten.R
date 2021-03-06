#!/usr/bin/env Rscript
# Standardise data from Matreyek et al. 2018 (PTEN)
source('src/config.R')
source('src/study_standardising.R')

# Import and process data
meta <- read_yaml('data/studies/matreyek_2018_pten/matreyek_2018_pten.yaml')
dm_data <- read_csv('data/studies/matreyek_2018_pten/raw/PTEN.csv',
                    col_types = cols(.default = col_character(), position = col_integer(), score = col_double())) %>%
  select(-X1) %>%
  rename(wt = start, mut = end, raw_score = score) %>%
  mutate(mut = if_else(mut == 'X', '*', mut),
         class = str_to_title(class),
         transformed_score = transform_vamp_seq(raw_score),
         score = normalise_score(transformed_score)) %>%
  drop_na(score) # Not all measured

# Save output
standardise_study(dm_data, meta$study, meta$transform)

