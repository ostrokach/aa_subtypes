#!/usr/bin/env Rscript
# Functions for importing studies in a standardised manner
source('src/config.R')

AA_THREE_2_ONE <- structure(names(Biostrings::AMINO_ACID_CODE), names = Biostrings::AMINO_ACID_CODE)
AA_THREE_2_ONE['Ter'] <- '*'


# Make summary table about studies
study_summary_tbl <- function(){
  structure_config <- read_yaml('meta/structures.yaml')
  import_fx_gene <- function(x){
    x <- gene_to_filename(x)
    suppressMessages(import_foldx(str_c('data/foldx/', x, '/', 'average_', x, '.fxout'),
                     structure_config[[x]]$sections))
  }
  foldx <- names(structure_config) %>%
    extract(!. %in% c('braf', 'gfp')) %>%
    sapply(import_fx_gene, simplify = FALSE) %>%
    bind_rows(.id = 'gene')
  
  study_summary <- function(study){
    yaml <- read_yaml(str_c('data/studies/', study, '/', study, '.yaml'))
    tbl <- suppressMessages(import_study(str_c('data/studies/', study))) %>%
      group_by(study, position, wt) %>%
      filter(sum(!mut == wt) >= 15) %>% # Only keep positions with a maximum of 4 missing scores
      ungroup() 
    
    prop_fx <- filter(foldx, gene == gene_to_filename(yaml$gene)) %>%
      select(position, wt, mut, total_energy) %>%
      left_join(tbl, ., by = c('position', 'wt', 'mut')) %>%
      group_by(position) %>%
      summarise(f=any(!is.na(total_energy))) %>%
      pull(f)
    prop_fx <- sum(prop_fx)/length(prop_fx)*100
      
    tibble(
      study = str_c(yaml$authour, ' ', yaml$year),
      species = yaml$species,
      gene = yaml$gene,
      uniprot_id = yaml$uniprot_id,
      npos = n_distinct(tbl$position),
      nvar = sum(!tbl$mut == '*'),
      prop_struct = prop_fx,
      experiment = yaml$experiment,
      multi_condition = NA,
      multi_variant = NA,
      transform = yaml$transform,
      filter = ifelse(yaml$qc$filter, yaml$qc$notes, '')
    )
  }
  
  map(dir('data/studies/'), study_summary) %>%
    bind_rows()
}

# Transform standardised data table to wide format
make_dms_wide <- function(dms){
  foldx_averages <- select(dms, study, position, wt, total_energy:entropy_complex) %>%
    select(-sloop_entropy, -mloop_entropy, -entropy_complex, -water_bridge) %>% # Drop terms that are unused in our structures
    drop_na(total_energy) %>%
    group_by(study, position, wt) %>%
    summarise_all(mean, na.rm=TRUE)
  
  position_constants <- select(dms, study, position, wt, phi:hydrophobicity) %>%
    distinct()
  
  dms_wide <- filter(dms, mut %in% Biostrings::AA_STANDARD) %>%
    select(study, gene, position, wt, mut, imputed_score, log10_sift) %>%
    pivot_wider(names_from = mut, values_from = c(imputed_score, log10_sift)) %>%
    rename_at(vars(starts_with('imputed_score_')), ~str_sub(., start=-1))
  
  mutate(dms_wide,
         mean_score = rowMeans(select(dms_wide, A:Y)),
         mean_sift = rowMeans(select(dms_wide, log10_sift_A:log10_sift_Y))) %>%
    left_join(foldx_averages, by = c('study', 'position', 'wt')) %>%
    left_join(position_constants, by = c('study', 'position', 'wt'))
  
}

#### Importing Standardised Data ####
# Import a study from its directory, based on the standard layout
import_study <- function(d, fields = NULL, filter=FALSE){
  study <- str_split(d, '/')[[1]]
  study <- study[length(study)]
  yaml = read_yaml(str_c(d, '/', study, '.yaml'))
  if (filter & yaml$qc$filter){
    return(NULL)
  }
  
  tbl <- read_tsv(str_c(d, '/', study, '.tsv'))
  for (f in c('study', fields)){
    tbl <- mutate(tbl, !!f := yaml[[f]])
  }
  
  return(tbl)
}

# Import sift results from all variant SIFT output
# Expects sift results to be in sift_dir and fasta files in fasta_dir
import_sift <- function(gene, sift_dir='data/sift', fasta_dir='data/fasta'){
  gene <- gene_to_filename(gene)
  fa <- as.character(readAAStringSet(str_c(fasta_dir, '/', gene, '.fa'), format = 'fasta')[[1]])
  sift <- read_table(str_c(sift_dir, '/', gene, '.SIFTprediction'), skip = 5, comment = '//',
                     col_names = c('A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I',
                                   'K', 'L', 'M', 'N', 'P', 'Q', 'R', 'S', 'T',
                                   'V', 'W', 'X', 'Y', 'Z', '*', '-'),
                     col_types = cols(.default = col_double())) %>%
    pivot_longer(everything(), names_to = 'mut', values_to = 'sift') %>%
    mutate(position = rep(1:nchar(fa), each = 25),
           wt = str_split(fa, '')[[1]][position],
           log10_sift = clamp(log10(sift + 0.00005), upper = 0)) # SIFT goes to 4dp so 0.00005 is smaller than everything else
  return(sift)
}

# Import FoldX results
# Expects foldx results to be in {foldx_dir}/{gene} folders, each with the processed FoldX results (see foldx_combine.py)
# sections should be a list of lists defining regions of the PDB that have been mutated, with a chain, an offset relative to 
# Uniprot sequence and optionally the region of the chain it applies to (see meta/structures.yaml for the expected structure)
import_foldx <- function(path, sections=NULL){
  fx <- read_tsv(path)
  
  # Adjust offset of each PDB section based on config
  if (!is.null(sections)){
    fx <- mutate(fx, offset_position = -1)
    for (section in sections){
      if (is.null(section$region)){
        region <- c(0, Inf)
      } else {
        region <- section$region
      }
      
      fx <- mutate(fx, offset_position = if_else(chain == section$chain & position >= region[1] & position <= region[2],
                                                 position + section$offset,
                                                 offset_position))
      
    }
    fx <- filter(fx, offset_position > 0) %>% # drop positions not in the identified sections (shouldn't drop anything other than when FoldX was run before sections finalised)
      mutate(position = offset_position) %>%
      select(-offset_position)
  }
  return(fx)
}

# Import naccess results
import_naccess <- function(filepath, sections=NULL){
  fi <- read_lines(filepath)
  fi <- grep('^REM', fi, invert = TRUE, value = TRUE)
  
  # Select table lines and read
  tbl_str <- str_replace(grep('^RES', fi, value = TRUE),'RES ', '')
  str_sub(tbl_str, 6, 5) <- ' ' # hack inserting space between chain and position in 4digit positions, which naccess doesn't do 
  acc <- read_table2(tbl_str, col_names = c('wt', 'chain', 'position', 'all_atom_abs', 'all_atom_rel',
                                            'side_chain_abs', 'side_chain_rel', 'backbone_abs', 'backbone_rel',
                                            'non_polar_abs', 'non_polar_rel', 'polar_abs', 'polar_rel')) %>%
    mutate(wt = structure(names(Biostrings::AMINO_ACID_CODE), names = Biostrings::AMINO_ACID_CODE)[str_to_title(wt)])
  
  # Adjust offset of each PDB section based on config
  if (!is.null(sections)){
    acc <- mutate(acc, offset_position = -1)
    for (section in sections){
      if (is.null(section$region)){
        region <- c(0, Inf)
      } else {
        region <- section$region
      }
      
      acc <- mutate(acc, offset_position = if_else(chain == section$chain & position >= region[1] & position <= region[2],
                                                   position + section$offset,
                                                   offset_position))
      
    }
    acc <- filter(acc, offset_position > 0) %>%
      mutate(position = offset_position) %>%
      select(-offset_position)
  }
  
  return(acc)
}

# Import chemical environment profiles
import_chem_env <- function(filepath, sections=NULL){
  profs <- read_tsv(filepath)
  
  # Adjust offset of each PDB section based on config
  if (!is.null(sections)){
    profs <- mutate(profs, offset_position = -1)
    for (section in sections){
      if (is.null(section$region)){
        region <- c(0, Inf)
      } else {
        region <- section$region
      }
      
      profs <- mutate(profs, offset_position = if_else(chain == section$chain & position >= region[1] & position <= region[2],
                                                       position + section$offset,
                                                       offset_position))
      
    }
    profs <- filter(profs, offset_position > 0) %>%
      mutate(position = offset_position) %>%
      select(-offset_position)
  }
  
  return(profs)
}

# Import Porter5 results
import_porter5 <- function(filepath){
  read_tsv(filepath) %>%
    rename(position = `#`, wt = AA) %>%
    rename_all(~str_to_lower(.)) %>%
    rename_at(vars(-position, -wt, -ss), ~str_c('ss_', .))
}
########

#### General Standardisation ####
## general study data saving function
# dm_data = tibble with columns position, wt, mut, score, transformed_score, raw_score, class
# study_id = authour_year_gene style standard study id
# transform = string describing the transform applied
# fill = column to colour distribution plots by. If NULL no colouring is applied
standardise_study <- function(dm_data, study_id, transform = 'No Transform'){
  study_name = format_study(study_id)
  
  p_orig <- ggplot(dm_data, aes(x = raw_score, fill = class)) +
    guides(fill = guide_legend(title = 'Variant Class')) +
    scale_fill_manual(values = MUT_CLASS_COLOURS) +
    geom_histogram(bins = 30) +
    labs(title = str_c('Original score distribution for ', study_name), x = 'Raw Score', y = 'Count')

  p_trans <- ggplot(dm_data, aes(x = transformed_score, fill = class)) +
    guides(fill = guide_legend(title = 'Variant Class')) +
    scale_fill_manual(values = MUT_CLASS_COLOURS) +
    geom_histogram(bins = 30) +
    labs(title = str_c('Transformed score distribution for ', study_name), x = 'Transformed Score', y = 'Count')
  
  p_norm <- ggplot(dm_data, aes(x = score, fill = class)) +
    guides(fill = guide_legend(title = 'Variant Class')) +
    scale_fill_manual(values = MUT_CLASS_COLOURS) +
    geom_histogram(bins = 30) +
    labs(title = str_c('Normalised score distribution for ', study_name), x = 'Normalised Score', y = 'Count')
  
  # Write output
  if (!dir.exists(str_c('figures/0_data/per_study/', study_id))){
    dir.create(str_c('figures/0_data/per_study/', study_id))
  }
  ggsave(str_c('figures/0_data/per_study/', study_id, '/original_distribution.pdf'), p_orig, units = 'cm', height = 12, width = 20)
  ggsave(str_c('figures/0_data/per_study/', study_id, '/transformed_distribution.pdf'), p_trans, units = 'cm', height = 12, width = 20)
  ggsave(str_c('figures/0_data/per_study/', study_id, '/normalised_distribution.pdf'), p_norm, units = 'cm', height = 12, width = 20)
  
  if (any(is.na(dm_data$position))){
    warning('NA value in position')
  }
  
  if (any(is.na(dm_data$wt))){
    warning('NA value in wt')
  }
  
  if (any(is.na(dm_data$mut))){
    warning('NA value in mut')
  }
  
  if (any(is.na(dm_data$class))){
    warning('NA value in class')
  }
  
  if (any(is.na(dm_data$score))){
    warning('NA value in score')
  }
  
  select(dm_data, position, wt, mut, score, transformed_score, raw_score, class) %>%
    drop_na(position, wt, mut, score, class) %>%
    filter(!wt == '*') %>%
    write_tsv(str_c('data/studies/', study_id, '/', study_id, '.tsv'))
}

## Function to determine variant class
get_variant_class <- function(wt, mut){
  if (!length(wt) == length(mut)){
    stop('wt and mut vectors must be the same length')
  }
  
  out <- rep('Missense', length(wt))
  out[wt == mut] <- 'Synonymous'
  out[mut == '*'] <- 'Nonsense'
  
  return(out)
}

## Normalise Score
normalise_score <- function(x){
  q <- quantile(x, 0.1, na.rm=TRUE)
  return(x / -median(x[x <= q], na.rm = TRUE))
}

## Scale VAMP-seq style
# data ranges from ~0 (NULL) -> 1 (wt) -) >1 beneficial
transform_vamp_seq <- function(x){
  # Transform
  y <- 1 + (x - 1) / -min(x - 1, na.rm = TRUE)
  return(log2(y + min(y[y > 0], na.rm = TRUE)))
}

# Calculate E-score equivalent to Enrich1 
# Currently no pseudocount etc. (simple implementation without error checking)
e_score <- function(sel, bkg){
  bkg[bkg == 0] <- NA
  
  freq_sel <- sel/sum(sel, na.rm = TRUE)
  freq_bkg <- bkg/sum(bkg, na.rm = TRUE)
  
  return(freq_sel/freq_bkg)
}

## Import MAVEDB study
read_mavedb <- function(path, score_col=NULL, score_transform=identity, position_offset = 0){
  score_col <- enquo(score_col)
  if (rlang::quo_is_null(score_col)){
    score_col <- quo(score)
  }
  
  read_csv(path, skip = 4) %>%
    tidyr::extract(hgvs_pro, into = c('wt', 'position', 'mut'), "p.([A-Za-z]{3})([0-9]+)([A-Za-z]{3})", convert = TRUE) %>%
    mutate(wt = AA_THREE_2_ONE[wt], mut = AA_THREE_2_ONE[mut], position = position + position_offset) %>%
    rename(raw_score = !!score_col) %>%
    mutate(transformed_score = score_transform(raw_score),
           score = normalise_score(transformed_score),
           class = get_variant_class(wt, mut)) %>%
    select(position, wt, mut, score, transformed_score, raw_score, class) %>%
    arrange(position, mut) %>%
    return()
}

# Untangle seqIDs of the form 1,2-A,D
process_split_seqid <- function(x){
  x <- str_split(x, '[-,]')[[1]]
  return(str_c(x[1:(length(x)/2)], x[(length(x)/2 + 1):length(x)], collapse = ','))
}

# Get muts from seq, expects each as a character vector
muts_from_seq <- function(mut_seq, wt_seq){
  if (all(mut_seq == wt_seq)){
    return(NA)
  }
  
  pos <- which(!mut_seq == wt_seq)
  return(str_c(wt_seq[pos], pos, mut_seq[pos], collapse = ','))
}
########

#### Functions for Melnikov et al. 2014 (APH(3')-II) ####
# Read aa count tables from melnikov et al. 2014
read_melnikov_table <- function(fi){
  tbl <- read_tsv(str_c('data/studies/melnikov_2014_aph3ii/raw/', fi), skip = 1, col_names = FALSE, col_types = cols(.default = col_character())) %>%
    t() %>%
    as_tibble(rownames = NULL, .name_repair='minimal') %>%
    set_colnames(.[1,]) %>%
    filter(!Position == 'Position') %>%
    rename(position = Position,
           wt = `Wild-type`) %>%
    mutate_at(vars(-wt), as.numeric)
  return(tbl)
}

# Wrapper to pass correct background and selection counts to fitness function, based on format of Melnikov 2014 data
# Expects sel to be a data.frame with cols for position, wt and all mut's in one selection/drug/library category
# these are given as exp_name in the SX_DRUG_LX format of melnikov
melnikov_fitness <- function(sel, exp_name, bkg){
  # Extract meta info on experiment
  meta <- as.list(strsplit(exp_name, '_')[[1]])
  names(meta) <- c('selection_round', 'drug', 'library')
  
  # Select correct background reads for library
  bkg <- bkg[[str_c('Bkg', str_sub(meta$library, -1))]]
  
  # Format bkg and sel as matrices
  ref_aas <- bkg$wt
  gene_length <- length(ref_aas)
  sel <- as.matrix(select(sel, -position, -wt))
  bkg <- as.matrix(select(bkg, -position, -wt))
  
  # Apply simple pseudocount of minimum non zero
  pseudo <- min(sel[sel>0], na.rm = TRUE)
  sel <- sel + pseudo
  bkg <- bkg + pseudo
  
  # Calculate e-score per position row - this allows calculation of ER for each variant taking account of other positions
  # as that information is contained in the positional wt count
  e_scores <- t(sapply(1:nrow(sel), function(x){e_score(sel[x,], bkg[x,])}))
  
  # Not properly possible to tell how fully WT sequence fairs as the WT AA measures include lots of mutants too
  # So cannot normalise to WT, however the per position method does leave most WT residues at ~1 already so scale stands
  fitness <- log2(e_scores + min(e_scores[e_scores > 0], na.rm = TRUE)) %>%
    as_tibble(.name_repair = 'unique') %>%
    mutate(position = 1:gene_length,
           wt = ref_aas) %>%
    gather(key = 'mut', value = 'score', -wt, -position)
  return(fitness)
}
########

#### Functions for Kitzman et al. 2015 (GAL4) ####
read_kitzman_sheet <- function(path, sheet){
  tbl <- read_xlsx(path, skip = 1, na = 'ND', sheet = sheet) %>%
    rename(position = `Residue #`) %>%
    mutate(wt = apply(., 1, function(x, nam){nam[x == 'wt' & !is.na(x)]}, nam = names(.)),
           label = sheet) %>%
    gather(key = 'mut', value = 'log2_enrichment', -position, -wt, -label) %>%
    mutate(log2_enrichment = if_else(log2_enrichment == 'wt', '0', log2_enrichment)) %>% # set wt to 0 log2 enrichment ratio
    mutate(log2_enrichment = as.numeric(log2_enrichment))
  return(tbl)
}
########

#### Functions for Mishra et al. 2016 (HSP90) ####
read_mishra_sheet <- function(path, sheet){
  tbl <- read_xlsx(path, sheet = sheet, col_names = str_c('col', 1:13))
  
  # Check sheet type
  if (tbl[1,1] == 'Stop counts'){
    ## Process sheets with a single replicate
    nom <- tbl[7,] %>% unlist(., use.names = FALSE)
    tbl <- tbl[8:nrow(tbl),] %>%
      set_names(nom) %>%
      rename_at(vars(-position, -aa), list( ~ paste0('rep1_', .))) %>%
      mutate_at(vars(-aa), as.numeric) %>%
      mutate(avg = rep1_norm_ratiochange)
    
  } else {
    ## Process sheets with replicates
    # Get first row of sub-tables
    top_row <- which(tbl$col1 == 'position') + 1
    
    # Get bottom row of sub-tables
    bot_row <- c(which(apply(tbl, 1, function(x){all(is.na(x))})) - 1, dim(tbl)[1])
    bot_row <- sapply(top_row, function(x){bot_row[which(bot_row > x)[1]]})
    
    # Extract sub-table names
    rep_nom <- tbl[top_row[1] - 1,] %>% unlist(., use.names = FALSE)
    ave_nom <- tbl[top_row[length(top_row)] - 1,] %>% unlist(., use.names = FALSE)
    ave_nom <- ave_nom[!is.na(ave_nom)]
    
    # Extract Subtables and add names
    rep1 <- tbl[top_row[1]:bot_row[1],] %>% 
      set_names(rep_nom) %>%
      rename_at(vars(-position, -aa), list( ~ paste0('rep1_', .)))
    
    rep2 <- tbl[top_row[2]:bot_row[2],] %>%
      set_names(rep_nom) %>%
      rename_at(vars(-position, -aa), list( ~ paste0('rep2_', .)))
    
    ave <- tbl[top_row[3]:bot_row[3],] %>%
      select_if(colSums(!is.na(.)) > 0) %>%
      set_names(ave_nom) %>%
      select(-s1, -s2) %>% # also found in rep tbls
      rename(aa = `amino acid`)
    
    tbl <- full_join(ave, rep1,, by=c('position', 'aa')) %>%
      full_join(., rep2, by=c('position', 'aa')) %>%
      mutate_at(vars(-aa), as.numeric)
  }
  return(tbl)
}
########