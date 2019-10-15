# pylint: disable-all
"""
Pipeline for the Mutational Landscapes/Amino Acids Subtypes Project
"""

from ruamel.yaml import YAML

yaml = YAML(typ='safe')

UNIREF90_DB_PATH = '/hps/research1/beltrao/ally/databases/uniref90/uniref90_2019_1.fasta'

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

# Test multiple mutation averaging
rule validate_multi_muts:
    input:
        "data/studies/starita_2013_ube4b/raw/starita_2013_ube4b_ubox.xlsx",
        "data/studies/araya_2012_yap1/raw/araya_2012_hYAP65_ww.tsv"

    output:
        "figures/0_data_properties/averaging_multi_mutants.pdf"

    script:
        "bin/analysis/0_data_properties/validate_multi_muts.R"

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