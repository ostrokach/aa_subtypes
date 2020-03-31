"""
Rules for generating figures
"""

rule figure1:
    """
    Figure 1
    """
    input:
        "data/combined_mutational_scans.tsv",
        expand('data/studies/{study}/{study}.{ext}',
               study=UNFILTERED_STUDIES, ext=('yaml', 'tsv')),
        "data/studies/firnberg_2014_tem1/firnberg_2014_tem1.tsv",
        "data/studies/firnberg_2014_tem1/firnberg_2014_tem1.yaml",
        "data/studies/steinberg_2016_tem1/steinberg_2016_tem1.tsv",
        "data/studies/steinberg_2016_tem1/steinberg_2016_tem1.yaml",
        "data/studies/roscoe_2013_ubi/roscoe_2013_ubi.tsv",
        "data/studies/roscoe_2013_ubi/roscoe_2013_ubi.yaml",
        "data/studies/roscoe_2014_ubi/roscoe_2014_ubi.tsv",
        "data/studies/roscoe_2014_ubi/roscoe_2014_ubi.yaml"

    output:
        "figures/4_figures/figure1.pdf",
        "figures/4_figures/figure1.png",
        "figures/4_figures/parts/figure1_A_raw.pdf",
        "figures/4_figures/parts/figure1_A_trans.pdf",
        "figures/4_figures/parts/figure1_A_norm.pdf"

    log:
        "logs/figure1.log"

    shell:
        "Rscript bin/4_figures/figure1.R &> {log}"

rule figure2:
    """
    Figure 2
    """
    input:
        "data/combined_mutational_scans.tsv"
        "meta/uniprot_domains.gff"

    output:
        "figures/4_figures/figure2.pdf",
        "figures/4_figures/figure2.png"

    log:
        "logs/figure2.log"

    shell:
        "Rscript bin/4_figures/figure2.R &> {log}"