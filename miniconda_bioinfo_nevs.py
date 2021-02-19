# Script for creating bioinformatics environments in miniconda isntalation
# some packages were isntalled with package manager
# packages general inkscape htop nmon emacs
# sudo aptitude install ncbi-blast+ muscle phylip phyml clustalo mrbayes t-coffee hmmer emboss


from subprocess import run, PIPE

env_info = run('conda info --env', shell=True, stdout=PIPE)
env_info = env_info.stdout.decode()


if 'snakePipes' not in env_info:
    print('[INSTALLING] snakePipes environmet.')
    run('conda create -n snakePipes -c mpi-ie -c bioconda -c conda-forge snakePipes -y', shell=True)
else:
    print('[NOT INSTALLING] snakePipes already isntalled')


# ### Installing mani packages does not work!!! -> many conflicts    
# print()
# print('Installing bioinformatics general package')

# cmd = 'conda create -n bioinformatics -c mpi-ie -c bioconda {} -y'
# bio_pkgs = ['emboss',
#             'blast',
#             'hmmer',
#             'phylip',
#             'phyml',
#             # 'raxml',
#             'mrbayes',
#             # 'clustalo',
#             'muscle',
#             't_coffee',
#             # 'probcons',
#             # 'meme'
#             ]
# cmd = cmd.format(' '.join(bio_pkgs))

# if 'bioinformatics' not in env_info:
#     print('Installing bioinformatics environmet.')
#     run(cmd, shell=True)
# else:
#     print('bioinformatics already installed')
    

#### isntall all the environmentes

# conda create -n samtools-env -c bioconda -c conda-forge samtools -y ;

gen_pkg = [
           # general use
           'repeatmasker',
           'fastqc',
           'htseq-env',
           'macs2',
           'hisat2',
           'salmon',
           'star',
           'cooler',
           'bowtie2',
           'bwa',
           'stringtie',
           'trim-galore',
           'trimmomatic',
           'velvet',
           'igv',
           'samtools',
           'bedtools',
           'meme',
           'homer',
           'multiqc',
           'hicup',
           'hic2cool',
           'tadtool',
           'deeptools',
           'picard',
           'kallisto',
           'bcftools',        # SNP calling
           # genome assembly
           'abyss',
           'spades',
           'quast',
           'prokka',
           # RNAseq specific
           'tetoolkit',
           'cufflinks',
           # Bioconduxctor envs
           'bioconductor-fourcseq',
           'bioconductor-deseq2',
           # Highrhoughput sequencing
           'htseq',
           # HiC
           'hicexplorer',
           'hicexplorer=3.2',
           'hint',
           # viz
           'pygenometracks',
           # ncbi
           'sra-tools'
           
          ]


### --- agregar? crear una version modular
# rdock (en bioconda) > molecular docking small molecules against proteins and nuc ac
# ambertools (conda forge) >  conda-forge



base_cmd = 'conda create -n {} -c bioconda -c conda-forge {} -y'

for pkg in gen_pkg:
    if '=' in pkg:
        pk, version = pkg.split('=')
        version = version.replace('.', '')
        envname = pk + version + '-env'
    else:
        envname = pkg + '-env'
    if envname not in env_info:
        print('[INSTALLING]', envname)
        # conditional for independent packages, lets try to avoid this
        if 'hicexplorer' in envname:
            pkgs = pkg + ' hic2cool'
            cmd = base_cmd.format(envname, pkgs)
        else:
            cmd = base_cmd.format(envname, pkg)
        run(cmd, shell=True)
    else:
        print('[NOT INSTALLING]', envname, 'already installed!')



print("[END] All environments created")
