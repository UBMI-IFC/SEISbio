#!/usr/bin/python
# -*- coding: utf-8 -*-
#
# ------------------------------
# Name:     InstallSEISbio.py
# Purpose:  General Instalation of SEISbio
# 
# @uthor:      acph - dragopoot@gmail.com
#
# Created:     jue 18 feb 2021 22:18:52 CST
# Copyright:   (c) acph 2021
# Licence:     GNU GENERAL PUBLIC LICENSE, Version 3, 29 June 2007
# ------------------------------
"""General Instalation of SEISbio """

import os
import subprocess
from subprocess import run, PIPE


def debian_install_bioinfo():
    """Installing bioinfo basic packages from Debian/Ubuntu repositories.
    WARN: Only for debian/ubuntu

    1. Update
    2. Upgrade
    3. Install basic programs (emacs, vim, lm-sensors, htop, aptitude)
    4. Bioinfo software
    """
    cmd_update = ['apt', 'update']
    cmd_upgrade = ['apt', 'upgrade', '-y']
    cmd_basic = ['apt', 'install', '-y',
                 'emacs',
                 'vim',
                 'lm-sensors',
                 'htop',
                 'aptitude',
                 # 'gimp', 'inkscape',   #for desktop
                 ]
    cmd_bioinfo = ['apt', 'install', '-y',
                   'emboss',
                   'ncbi-blast+',
                   'hmmer',
                   't-coffe',
                   'muscle',
                   'probcons',
                   'phylip',
                   'phyml',
                   'raxml',
                   'mrbayes',
                   'seaview',
                   'clustalo',
                   ]

    print('[INFO] Updating and upgrading system (Debian/Ubuntu)']
    run(cmd_update)
    run(cmd_upgrade)

    print('[INFO] Installing helping packages (Debian/Ubuntu)']
    run(cmd_basic)

    print('''[INFO] Installing Bioinformatic programs from repositories 
             (Debian/Ubuntu)''']
    run(cmd_bioinfo)


def demote(user_uid, user_gid):
    """Pass the function 'set_ids' to preexec_fn, rather than just calling
    setuid and setgid. This will change the ids for that subprocess only"""
    def set_ids():
        os.setgid(user_gid)
        os.setuid(user_uid)
    return set_ids


def check_id_as_user():
    """Run the command 'id' in a subprocess as user 1000,
    return the result
    
    https://gist.github.com/sweenzor/1685717"""

    cmd = ['id']
    return subprocess.check_output(cmd, preexec_fn=demote(1015, 1015))


def download_miniconda():
    """Download minicnda"""
    conda_url = 'https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh'
    cmd = ['wget', '-N', conda_url]
    return run(cmd, preexec_fn=demote(1015, 1015))


def install_miniconda():
    """Comands for Download miniconda, install in /home/anaconda/ and
    run conda init (<- only for anaconda user)
    """
#    cmd_p = ['sudo', '-u', 'anaconda', 'chmod', 'u+x',
#            '/home/anaconda/Miniconda3-latest-Linux-x86_64.sh']
#    subprocess.run(cmd_p)
    # cmd = ['sudo', '-u', 'anaconda',
    #        'bash', '/home/anaconda/Miniconda3-latest-Linux-x86_64.sh', '-b',
    #        '-p', '/home/anaconda/miniconda3']
    myenv = os.environ.copy()
    myenv['HOME'] = '/home/anaconda'
    run(['echo', '$HOME'])
    # INSTALL
    ## TODO : define by the user the conda prefix
    cmd = ['bash', '/home/anaconda/Miniconda3-latest-Linux-x86_64.sh', '-b',
           '-p', '/home/anaconda/miniconda3']
    run(cmd, preexec_fn=demote(1015, 1015), env=myenv)
    # init conda
    cmd_init = ['/home/anaconda/miniconda3/bin/conda', 'init']
    run(cmd_init, preexec_fn=demote(1015, 1015), env=myenv)

def update_miniconda():
    """Update miniconda installation
    """
    os.chdir('/home/anaconda/')
    myenv = os.environ.copy()
    myenv['HOME'] = '/home/anaconda'
    # myenv['TMPDIR'] = '/tmp/anaconda'
    # myenv['CONDA_EXE'] = '/home/anaconda/miniconda3/bin/conda'
    # myenv['CONDA_PREFIX'] =  '/home/anaconda/miniconda3'
    # myenv['CONDA_PYTHON_EXE'] = '/home/anaconda/miniconda3/bin/python'
    # myenv['CONDA_DEFAULT_ENV'] = 'base'

    # update and isntall basic packages
    # cmd = ['bash', './miniconda_basic_pkgs.sh']
    # cmd = '/home/anaconda/miniconda3/bin/conda install -p /home/anaconda/miniconda3 -y scipy'.split()

    cmd = ['/home/anaconda/miniconda3/bin/conda',
           'update',
           '-p',
           '/home/anaconda/miniconda3',
           '-y',
           '--all']
    run(cmd, preexec_fn=demote(1015, 1015), env=myenv)

    ### CONDA ENV variables
    # CONDA_EXE /home/anaconda/miniconda3/bin/conda
    # CONDA_PREFIX /home/anaconda/miniconda3
    # CONDA_PROMPT_MODIFIER (base) 
    # _CE_CONDA 
    # CONDA_SHLVL 2
    # CONDA_PYTHON_EXE /home/anaconda/miniconda3/bin/python
    # CONDA_DEFAULT_ENV base
    # CONDA_PREFIX_1 /home/acph/anaconda3
    ###


def install_conda_base():
    "Completing miniconda base environment with scientific packages

    Using default conda repository"
    os.chdir('/home/anaconda/')
    myenv = os.environ.copy()
    myenv['HOME'] = '/home/anaconda'
    cmd = ['/home/anaconda/miniconda3/bin/conda',
           'install',
           '-p',
           '/home/anaconda/miniconda3',
           '-y',
           'numpy',
           'scipy',
           'matplotlib',
           'pandas',
           'statsmodels',
           'seaborn',
           'biopython',
           'scikit-learn',
           'scikit-image',
           'networkx',
           'jupyter',
           'spyder',
           'orange3',
           'keras',
           'jupyterlab',
           ]
    run(cmd, preexec_fn=demote(1015, 1015), env=myenv)


def install_virtual_envs():
    """Installing virtual environments for many bioinformatics programs from:
    - conda-forge
    - bioconda
    - Other repositories
    """
    # basic config
    os.chdir('/home/anaconda/')
    myenv = os.environ.copy()
    myenv['HOME'] = '/home/anaconda'

    env_info = run('/home/anaconda/miniconda3/bin/conda info --env', shell=True, stdout=PIPE)
    env_info = env_info.stdout.decode()
    ### Snakepipes
    if 'snakePipes' not in env_info:
        print('[INSTALLING] snakePipes environmet.')
        run('conda create -n snakePipes -c mpi-ie -c bioconda -c conda-forge snakePipes -y', shell=True)
    else:
        print('[NOT INSTALLING] snakePipes already isntalled')

    
    # ### Installing many packages does not work!!! -> many conflicts    
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
        'multiqc',        
        'macs2',
        'trim-galore',
        'trimmomatic',
        'igv',
        'samtools',
        'bedtools',
        'meme',
        'homer',
        'deeptools',
        'picard',
        'kallisto',
        # # genome assembly alignment
        'abyss',
        'spades',
        'quast',
        'prokka',
        'bowtie2',
        'bwa',
        # 'velvet',        
        # # RNAseq specific
        'hisat2',
        'salmon',
        'star',
        'tetoolkit',
        'cufflinks',
        # # Bioconduxctor envs
        'bioconductor-fourcseq',
        'bioconductor-deseq2',
        # # Highrhoughput sequencing
        'htseq',
        # # HiC
        'hicexplorer',
        'hicexplorer=3.2',
        'cooler',        
        'hint',
        'hicup',
        'hic2cool',
        'tadtool',
        # # viz
        'pygenometracks',
        # # ncbi
        'sra-tools'
        # # Others
        'bcftools',        # SNP calling
        'stringtie',
              ]
    
    ### TODO --- agregar? crear una version modular
    # rdock (en bioconda) > molecular docking small molecules against proteins and nuc ac
    # ambertools (conda forge) >  conda-forge
    base_cmd = '/home/anaconda/miniconda3/bin/conda create -n {} -c bioconda -c conda-forge {} -y'
    
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
            run(cmd.split(), preexec_fn=demote(1015, 1015), env=myenv)
        else:
            print('[NOT INSTALLING]', envname, 'already installed!')


#########################################
## main
#########################################

repopath = os.getcwd()

print('[START] Installing system packages')
debian_install_bioinfo()

print('[INFO] Creating anaconda user if not exists.')
if not os.path.exists('/home/anaconda'):
    print('[INFO] Creating anaconda user and asking for a password.')
    print('=====================')
    # adduser only works this way in Debian distrso
    # ArchLinux : install adduser-deb from AUR
    cmd_create = """adduser --shell /bin/bash --uid 1015 --gecos '' anaconda""".split()
    subprocess.run(cmd_create)
    print('=====================')    
    print('[INFO] Anaconda user created')
    print('=====================')    
else:
    print('[WARN] anaconda user already exists!!!')
    print('[INFO] Consider to delete this user')
    print('   $ sudo userdel -r anaconda')
    # TO DO : ask if ending program or continue with risk
    print('[END] exit program doing nothing!')
    # exit()

print('[INFO] Moving to anaconda home')
os.chdir('/home/anaconda/')
print('=====================')      
download_miniconda()

if not os.path.exists('/home/anaconda/miniconda3'):
    print('[INFO] Installing miniconda. ')
    install_miniconda()
else:
    print('[INFO] Minocaonda already isntalled.')

# os.chdir(repopath) # this was usefull using aditional scripts Now
# all th code is here - TODO - Delete this coment
print('[INFO] Updating anaconda and isntalling basic packages.')
update_miniconda()

print('[INFO] NEW packages.')
install_conda_base()

print('[INFO] virtual envs.')
install_virtual_envs()

print('[END] All packages instaled')