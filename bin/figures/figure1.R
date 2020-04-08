#!/usr/bin/env Rscript
# Produce figure 1 (Dataset summary)
source('src/config.R')
source('src/study_standardising.R')
data("BLOSUM62")

blosum62 <- as_tibble(BLOSUM62, rownames = 'wt') %>%
  pivot_longer(-wt, names_to = 'mut', values_to = 'blosum62')

raw <- sapply(dir('data/studies/', full.names = TRUE), import_study, fields = c('gene'), simplify = FALSE, filter=TRUE) %>%
  bind_rows() %>%
  group_by(study, gene, position, wt) %>%
  filter(sum(!mut == wt) >= 15) %>% # Only keep positions with a maximum of 4 missing scores
  ungroup()

dms <- read_tsv('data/combined_mutational_scans.tsv')
dms_long <- read_tsv('data/long_combined_mutational_scans.tsv')
  
### Panel 1 - Gene Summary ###
gene_summary <- group_by(dms, gene) %>%
  summarise(n = n_distinct(position),
            n_struct = n_distinct(position[!is.na(total_energy)])) %>%
  mutate(percent_struct = n_struct / n * 100,
         x = str_c(n, " (", signif(percent_struct, 3), "%)"),
         img = str_c("<img src='figures/4_figures/proteins/", gene_to_filename(gene), ".png", "' width='30' />"))

p_genes <- ggplot(gene_summary, aes(x = x, y = n, label = img)) +
  geom_richtext(fill = NA, label.color = NA, label.padding = grid::unit(rep(0, 4), "pt")) +
  facet_wrap(~gene, nrow = 3, scales = 'free') +
  theme(panel.grid.major.y = element_blank(),
        axis.text.y = element_blank(),
        axis.ticks = element_blank(),
        axis.title = element_blank())

### Panel 2 - Normalisation Procedure ###
p_norm_raw <- filter(raw, study %in% c('steinberg_2016_tem1', 'heredia_2018_ccr5', 'matreyek_2018_tpmt')) %>%
  ggplot(aes(x = raw_score, colour = study)) +
  geom_density(size = 1.5) +
  labs(y = '', x = 'Raw Score') + 
  guides(colour = FALSE) +
  theme(text = element_text(size = 12))
ggsave('figures/4_figures/parts/figure1_norm_schematic_raw.pdf', p_norm_raw, width = 8, height = 6, units = 'cm')
p_norm_trans <- filter(raw, study %in% c('steinberg_2016_tem1', 'heredia_2018_ccr5', 'matreyek_2018_tpmt')) %>%
  ggplot(aes(x = transformed_score, colour = study)) +
  geom_density(size = 1.5) +
  labs(y = '', x = 'Transformed Score') + 
  guides(colour = FALSE) +
  theme(text = element_text(size = 12))
ggsave('figures/4_figures/parts/figure1_norm_schematic_trans.pdf', p_norm_trans, width = 8, height = 6, units = 'cm')
p_norm_final <- filter(raw, study %in% c('steinberg_2016_tem1', 'heredia_2018_ccr5', 'matreyek_2018_tpmt')) %>%
  ggplot(aes(x = score, colour = study)) +
  geom_density(size = 1.5) +
  labs(y = '', x = 'Normalised Score') + 
  guides(colour = FALSE) +
  xlim(-2, 1) +
  theme(text = element_text(size = 16))
ggsave('figures/4_figures/parts/figure1_norm_schematic_norm.pdf', p_norm_final, width = 8, height = 6, units = 'cm')

p_norm <- ggplot() +
  geom_blank() +
  annotation_custom(readPNG('figures/4_figures/parts/figure1_norm_schematic.png') %>% rasterGrob(interpolate = TRUE),
                    xmin=-Inf, xmax=Inf, ymin=-Inf, ymax=Inf)

### Panel 3 - Replicate Studies ###
tem1_studys <- sapply(c('data/studies/firnberg_2014_tem1', 'data/studies/steinberg_2016_tem1'),
                      import_study, fields = 'gene', simplify = FALSE) %>%
  bind_rows() %>%
  select(-transformed_score, -raw_score, -gene) %>%
  pivot_wider(names_from = study, values_from = score)

p_rep_tem1 <- ggplot(tem1_studys, aes(x=firnberg_2014_tem1, y=steinberg_2016_tem1, colour=class)) +
  geom_point() +
  geom_smooth(method = 'lm', colour = 'black') +
  geom_abline(slope = 1, colour = 'black', linetype = 'dotted') +
  scale_colour_manual(values = MUT_CLASS_COLOURS) +
  coord_equal() +
  labs(x = 'Firnberg et al. 2014', y = 'Steinberg & Ostermeier 2016', title = 'TEM1') +
  guides(colour = guide_legend(title = 'Variant Type'))

ubi_studys <- sapply(c('data/studies/roscoe_2013_ubi', 'data/studies/roscoe_2014_ubi'),
                     import_study, fields = 'gene', simplify = FALSE) %>%
  bind_rows() %>%
  select(-transformed_score, -raw_score, -gene) %>%
  pivot_wider(names_from = study, values_from = score)

p_rep_ubi <- ggplot(ubi_studys, aes(x=roscoe_2013_ubi, y=roscoe_2014_ubi, colour=class)) +
  geom_point() +
  geom_smooth(method = 'lm', colour = 'black') +
  geom_abline(slope = 1, colour = 'black', linetype = 'dotted') +
  scale_colour_manual(values = MUT_CLASS_COLOURS) +
  coord_equal() +
  labs(x = 'Roscoe et al. 2013', y = 'Roscoe & Bolon 2014', title = 'UBI') +
  guides(colour = guide_legend(title = 'Variant Type'))

### Panel 4 - Blosum Correlation ###
blosum_cor <- group_by(raw, wt, mut) %>%
  summarise(score = mean(score)) %>%
  left_join(., blosum62, by = c('wt', 'mut'))

p_blosum <- ggplot(blosum_cor, aes(x = blosum62, y = score)) +
  geom_jitter(width = 0.2) +
  labs(x = 'BLOSUM62', y = 'Mean Normalised ER')

### Panel 5 Sift correlation ###
format_gene <- function(gene, study){
  year <- str_split_fixed(study, fixed('_'), n = 3)[,2]
  ifelse(gene %in% c('UBI', 'HSP90'), str_c(gene, ' (', year, ')'), gene)
}

sift_correlations <- select(dms_long, study, gene, position, wt, mut, score, log10_sift) %>%
  drop_na(score, log10_sift) %>%
  group_by(study, gene) %>% 
  group_modify(~tidy(cor.test(.$score, .$log10_sift, method = 'pearson'))) %>%
  ungroup() %>%
  mutate(study_pretty = sapply(study, format_study, USE.NAMES = FALSE),
         p_cat = pretty_p_values(p.value, breaks = c(1e-48, 1e-12, 1e-06, 1e-3, 0.01, 0.05)),
         gene_pretty = format_gene(gene, study))
  

p_sift <- ggplot(sift_correlations, aes(x = gene_pretty, y = estimate, fill = p_cat)) +
  geom_col(position = position_dodge()) +
  geom_errorbar(aes(ymin=conf.low, ymax=conf.high), width=0.5, position = position_dodge(0.9)) +
  geom_hline(yintercept = 0) +
  xlab('') +
  ylab(expression("Pearson's"~rho)) +
  scale_fill_viridis_d(guide=guide_legend(title='p-value'), drop=FALSE) +
  theme(axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5))

### Figure Assembly ###
size <- theme(text = element_text(size = 8))
p1 <- p_genes + labs(tag = 'A') + size
p2 <- p_norm + labs(tag = 'B') + size
p3 <- p_rep_ubi + labs(tag = 'C') + size
#p3_legend <- as_ggplot(get_legend(p3_ubi))
#p3_ubi <- p3_ubi + guides(colour = FALSE)
#p3_tem1 <- p_rep_tem1 + size + guides(colour = FALSE)
p4 <- p_blosum + labs(tag = 'D') + size
p5 <- p_sift + labs(tag = 'E') + size

figure1 <- multi_panel_figure(width = 200, height = 200, columns = 9, rows = 3,
                              panel_label_type = 'none', row_spacing = 0.1) %>%
  fill_panel(p1, row = 1, column = 1:9) %>%
  fill_panel(p2, row = 2:3, column = 1:3) %>%
  fill_panel(p3, row = 2, column = 4:6) %>%
  fill_panel(p4, row = 2, column = 7:9) %>%
  fill_panel(p5, row = 3, column = 4:9)
ggsave('figures/4_figures/figure1.pdf', figure1, width = figure_width(figure1), height = figure_height(figure1), units = 'mm')
ggsave('figures/4_figures/figure1.png', figure1, width = figure_width(figure1), height = figure_height(figure1), units = 'mm')