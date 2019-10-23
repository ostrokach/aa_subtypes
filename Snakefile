# pylint: disable-all
"""
Pipeline for the Mutational Landscapes/Amino Acids Subtypes Project
"""

from ruamel.yaml import YAML

yaml = YAML(typ='safe')

UNIREF90_DB_PATH = '/hps/research1/beltrao/ally/databases/uniref90/uniref90_2019_1.fasta'

#### Validate Data ####
# Test multiple mutation averaging
rule validate_multi_muts:
    input:
        "data/studies/starita_2013_ube4b/raw/starita_2013_ube4b_ubox.xlsx",
        "data/studies/araya_2012_yap1/raw/araya_2012_hYAP65_ww.tsv"

    output:
        "figures/0_data_properties/averaging_multi_mutants.pdf"

    script:
        "bin/analysis/0_data_properties/validate_multi_muts.R"

# Validate Melnikov et al. 2014 (APH(3')-II)
rule validate_melnikov:
    # Requires Melnikov .aacount files to be in data/studies/melnikov_2014_aph3ii/raw
    output:
        "figures/0_data_properties/melnikov_2014_aph3ii/initial_library_correlation.pdf",
        "figures/0_data_properties/melnikov_2014_aph3ii/filtered_library_correlation.pdf",
        "figures/0_data_properties/melnikov_2014_aph3ii/rel_conc_correlation.pdf",
        "figures/0_data_properties/melnikov_2014_aph3ii/drug_correlation.pdf"

    script:
        "bin/analysis/0_data_properties/validate_melnikov_2014_aph3ii.R"

# Validate Kitzman et al. 2015 (GAL4)
rule validate_kitzman:
    input:
        "data/studies/kitzman_2015_gal4/raw/kitzman_2015_gal4_enrichment.xlsx"

    output:
        "figures/0_data_properties/kitzman_2015_gal4/validate_selection_combination.pdf"

    script:
        "bin/analysis/0_data_properties/validate_kitzman_2015_gal4.R"

# Validate Giacomelli et al. 2018 (TP53)
rule validate_giacomelli:
    input:
        "data/studies/giacomelli_2018_tp53/raw/41588_2018_204_MOESM5_ESM.xlsx"

    output:
        "figures/0_data_properties/giacomelli_2018_tp53/initial_experiment_cor.pdf",
        "figures/0_data_properties/giacomelli_2018_tp53/codon_averaged_experiment_cor.pdf",
        "figures/0_data_properties/giacomelli_2018_tp53/conditions.pdf"

    script:
        "bin/analysis/0_data_properties/validate_giacomelli_2018_tp53.R"

# Validate Heredia et al. 2018
rule validate_heredia:
    input:
        "data/studies/heredia_2018_ccr5/raw/GSE100368_enrichment_ratios_CCR5.xlsx"

    output:
        "figures/0_data_properties/heredia_2018_ccr5/replicate_correlation.pdf",
        "figures/0_data_properties/heredia_2018_ccr5/experiment_correlation.pdf",
        "figures/0_data_properties/heredia_2018_cxcr4/replicate_correlation.pdf",
        "figures/0_data_properties/heredia_2018_cxcr4/experiment_correlation.pdf"

    script:
        "bin/analysis/0_data_properties/validate_heredia.R"


#### Standardise Data ####
# Process the raw data from each study
rule standardise_data:
    input:
        "data/studies/{study}/standardise_{study}.R"

    output:
        "data/studies/{study}/{study}.tsv",
        "figures/0_data_properties/{study}/original_distribution.pdf",
        "figures/0_data_properties/{study}/transformed_distribution.pdf"

    script:
        "{input}"

#### Make Tool Predictions ####
# Make all SIFT predictions for study genes
# TODO Change layout so as to only run each gene once
rule make_fasta:
    input:
        "data/studies/{study}/{study}.yaml"

    output:
        "data/studies/{study}/{study}.fa"

    shell:
        "python bin/make_study_fasta.py -l 80 {input} > {output}"

rule sift4g:
    input:
        fa = "data/studies/{study}/{study}.fa",
        db = UNIREF90_DB_PATH

    output:
        "data/studies/{study}/{study}.SIFTprediction"

    shell:
        "sift4g -q {input.fa} -d {input.db} --out data/studies/{study}"

# Make all FoldX for study genes
# TODO

# Plots