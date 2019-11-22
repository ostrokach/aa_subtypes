"""
Rules for generating other statistics from PDB files (i.e. othat than FoldX)

Requires the foldx_repair rule from foldx.smk to generate the *_Repair.pdb files
"""
rule calculate_backbone_angles:
    input:
        pdb="data/foldx/{gene}/{gene}_Repair.pdb",
        yaml="meta/structures.yaml"

    output:
        "data/backbone_angles/{gene}.tsv"

    log:
        "logs/calculate_backbone_angles/{gene}.log"

    shell:
        "python bin/data_processing/get_backbone_angles.py --yaml {input.yaml} {input.pdb} > {output} 2> {log}"

rule filter_pdb:
    input:
        'data/foldx/{gene}/{gene}_Repair.pdb'

    output:
        'data/surface_accessibility/{gene}.pdb'

    log:
        'logs/filter_pdb/{gene}.log'

    shell:
        'python bin/data_processing/filter_pdb.py --yaml meta/structures.yaml {input} > {output} 2> {log}'

rule naccess:
    input:
        'data/surface_accessibility/{gene}.pdb'

    output:
        asa='data/surface_accessibility/{gene}.asa',
        rsa='data/surface_accessibility/{gene}.rsa'

    log:
        'logs/naccess/{gene}.log'

    shell:
        """
        naccess {input} &> {log}
        cat {wildcards.gene}.log >> {log}
        rm {wildcards.gene}.log
        mv {wildcards.gene}.asa {output.asa}
        mv {wildcards.gene}.rsa {output.rsa}
        """

rule k_nearest_profile:
    input:
        pdb='data/foldx/{gene}/{gene}_Repair.pdb',
        yaml='meta/structures.yaml'

    output:
        'data/chemical_environment/{gene}_{k}_nearest.tsv'

    log:
        'logs/k_nearest_profile/{gene}_{k}.log'

    shell:
        'python bin/data_processing/get_chem_env_profiles.py --k_nearest {wildcards.k} --yaml {input.yaml} {input.pdb} > {output} 2> {log}'

rule within_a_profile:
    input:
        pdb='data/foldx/{gene}/{gene}_Repair.pdb',
        yaml='meta/structures.yaml'

    output:
        'data/chemical_environment/{gene}_within_{a}.tsv'

    log:
        'logs/within_a_profile/{gene}_{a}.log'

    shell:
        'python bin/data_processing/get_chem_env_profiles.py --angstroms {wildcards.a} --yaml {input.yaml} {input.pdb} > {output} 2> {log}'