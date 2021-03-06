#!/usr/bin/env Rscript
# Calculate the correlation between study scores and SIFT results
source('src/config.R')
source('src/study_standardising.R')

sift_dir <- 'data/sift/'
study_dirs <- dir('data/studies', full.names = TRUE)

dms <- lapply(study_dirs, import_study, fields = c('gene')) %>%
  bind_rows()

sift <- sapply(unique(dms$gene), import_sift, simplify = FALSE) %>%
  bind_rows(.id = 'gene') 

dms <- left_join(dms, sift, by = c('gene', 'position', 'wt', 'mut'))

sift_correlations <- bind_rows(group_by(dms, study) %>% 
                                 do(tidy(cor.test(.$score, .$log10_sift, method = 'kendall'))),
                               group_by(dms, study) %>% 
                                 do(tidy(cor.test(.$score, .$log10_sift, method = 'pearson')))) %>%
  mutate(study_pretty = sapply(study, format_study, USE.NAMES = FALSE),
         p_cat = pretty_p_values(p.value, breaks = c(1e-48, 1e-12, 1e-06, 1e-3, 0.01, 0.05)))

filtered <- sapply(unique(sift_correlations$study), function(x){
  y <- read_yaml(str_c('data/studies/', x, '/', x, '.yaml'))
  return(ifelse(y$qc$filter, 'red', 'black'))
})
names(filtered) <- sapply(names(filtered), format_study, USE.NAMES = FALSE)
  
p_sift_cor <- ungroup(sift_correlations) %>%
  mutate(study_pretty = add_markdown(study_pretty, colour = filtered)) %>%
  ggplot(aes(x = study_pretty, y = estimate, fill = p_cat)) +
  facet_wrap(~method, ncol = 1) +
  geom_col(position = position_dodge()) +
  geom_errorbar(aes(ymin=conf.low, ymax=conf.high), width=0.5, position = position_dodge(0.9)) +
  geom_hline(yintercept = 0) +
  ggtitle('Correlation between Normalised Score and log10(SIFT)') +
  xlab('') +
  ylab('Correlation') +
  scale_fill_viridis_d(guide=guide_legend(title='p-value'), drop=FALSE) +
  theme(axis.text.x = element_markdown(angle = 90, hjust = 1, vjust = 0.5))
ggsave('figures/0_data/sift_score_correlation.pdf', p_sift_cor, width = 20, height = 20, units = 'cm')

p_sift_density <- ggplot(dms, aes(x = score, y = jitter(log10_sift, 0.1), colour = class)) +
  facet_wrap(~study, labeller = as_labeller(sapply(unique(dms$study), format_study)), ncol = 6, scales = 'free_x') +
  geom_density2d(data = filter(dms, class == 'Missense')) +
  geom_point(data = filter(dms, !class == 'Missense')) +
  scale_colour_manual(values = MUT_CLASS_COLOURS) +
  labs(x = 'Score', y = 'log10(SIFT)')
ggsave('figures/0_data/sift_score_density.pdf', p_sift_density, width = 35, height = 35, units = 'cm')
