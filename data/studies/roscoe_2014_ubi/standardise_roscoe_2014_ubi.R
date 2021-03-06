#!/usr/bin/env Rscript
# Standardise data from Roscoe & Bolon 2014 (Ubiquitin)
source('src/config.R')
source('src/study_standardising.R')

# Import and process data
meta <- read_yaml('data/studies/roscoe_2014_ubi/roscoe_2014_ubi.yaml')
dm_data <- read_xlsx('data/studies/roscoe_2014_ubi/raw/1-s2.0-S0022283614002587-mmc3.xlsx', skip = 3, na = 'NA') %>%
  rename(position = Position,
         mut = `Amino Acid`,
         raw_score = `log2 (E1react/display)`,
         rel_e1_reactivity = `Relative E1-reactivity (avg WT=1, avg STOP=0)`,
         sd_in_symonoymous_codons = `Standard deviation among synonymous codons`,
         notes = Notes) %>%
  mutate(transformed_score = raw_score,
         score = normalise_score(transformed_score), 
         wt = str_split(meta$seq, '')[[1]][position],
         class = get_variant_class(wt, mut)) %>%
  drop_na(score) # Not all measured sucessfully

# Save output
standardise_study(dm_data, meta$study, meta$transform)
