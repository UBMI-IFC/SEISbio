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
import argparse
import re
from subprocess import run, PIPE


def arguments():
    """"""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('-d', '--distribution', default='mambaforge',
                        choices=['mambaforge', 'miniconda'],
                        help='Select scientific software distribution.')
    parser.add_argument('--home', default='seisbio',
                        help='User and home directory to create for the distribution installation.'
                        'This will be created in /home/')
    parser.add_argument('--debupgrade',
                        action='store_true', default=False,
                        help='If specified  UPDATE Debian/ubuntu system')
    parser.add_argument('-f', '--envfile', default='virtual_envs.txt',
                        help=('Files that specifies the virtual environments'
                              'to create in SEISbio instalation.'
                              'Default=./virtual_envs.txt. You can read'
                              'the file specification in ./virtual_envs.txt'))
    args = parser.parse_args()
    return args


def debian_install_bioinfo(upgrade=False):
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
                   't-coffee',
                   'muscle',
                   'probcons',
                   'phylip',
                   'phyml',
                   'raxml',
                   'mrbayes',
                   'seaview',
                   'clustalo',
                   ]

    if upgrade:
        print('[INFO] Updating and upgrading system (Debian/Ubuntu)')
        run(cmd_update)
        run(cmd_upgrade)

    print('[INFO] Installing helping packages (Debian/Ubuntu)')
    run(cmd_basic)

    print('''[INFO] Installing Bioinformatic programs from repositories 
             (Debian/Ubuntu)''')
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


def donwload_distribution(distribution='mambaforge'):
    """Downloads the latest installator from the scientific distribution
to isntall.

    Keyword Arguments:
    distribution -- str (default 'mambaforge')
             'mambaforge' | 'miniconda'
    """
    urls = {'mambaforge': 'https://github.com/conda-forge/miniforge/releases/latest/download/Mambaforge-Linux-x86_64.sh',
            'miniconda': 'https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh'}
    url = urls[distribution]
    cmd = ['wget', '-N', url]
    run(cmd, preexec_fn=demote(1015, 1015))
    filename = url.split('/')[-1]
    return filename

def install_distribution(installer, distribution='mambaforge', home='seisbio'):
    """Downloads the latest installator from the scientific distribution
to isntall.

    Keyword Arguments:
    distribution -- str (default 'mambaforge')
             'mambaforge' | 'miniconda'
    """
    myenv = os.environ.copy()
    myenv['HOME'] = f'/home/{home}'
    run(['echo', '$HOME'])
    # se podra ejecutar con sudo esta parte?
    # INSTALL
    cmd = ['bash', f'/home/{home}/{installer}', '-b',
           '-p', f'/home/{home}/{distribution}']
    run(cmd, preexec_fn=demote(1015, 1015), env=myenv)
    # init conda, [WARN]
    cmd_init = [f'/home/{home}/{distribution}/bin/conda', 'init']
    run(cmd_init, preexec_fn=demote(1015, 1015), env=myenv)


def update_distribution(manager='mamba', distribution='mambaforge',
                        home='seisbio'):
    """Update miniconda installation
    """
    os.chdir(f'/home/{home}/')
    myenv = os.environ.copy()
    myenv['HOME'] = f'/home/{home}'
    cmd = [f'/home/{home}/{distribution}/bin/{manager}',
           'update',
           '-p',
           f'/home/{home}/{distribution}',
           '-y',
           '--all']
    run(cmd, preexec_fn=demote(1015, 1015), env=myenv)


def install_distribution_base(manager='mamba',
                              distribution='mambaforge',
                              home='seisbio'):
    """Completing miniconda base environment with scientific packages"""
    os.chdir(f'/home/{home}/')
    myenv = os.environ.copy()
    myenv['HOME'] = f'/home/{home}'
    # TODO pasar esto a un archivo
    cmd = [f'/home/{home}/{distribution}/bin/{manager}',
           'install',
           '-p',
           f'/home/{home}/{distribution}',
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


def install_virtual_envs(pkg_list, manager='mamba',
                         distribution='mambaforge',
                         home='seisbio'):
    """Installing virtual environments for many bioinformatics programs from:
    - conda-forge
    - bioconda
    - Other repositories
    """
    # paths
    manager_path = f'/home/{home}/{distribution}/bin/{manager}'
    home_path = f'/home/{home}/'
    # basic config
    os.chdir(home_path)
    myenv = os.environ.copy()
    myenv['HOME'] = home_path
    env_info = run([manager_path, 'info',  '--env'], stdout=PIPE)
    env_info = env_info.stdout.decode()
    base_cmd = manager_path + ' create -n {} -c bioconda -c conda-forge {} -y'
    for pkg in pkg_list:
        print(pkg)
        if '=' in pkg:
            pk, version = pkg.split('=')
            version = version.replace('.', '')
            envname = pk + version + '-env'
        else:
            envname = pkg + '-env'
        if envname not in env_info:
            print('[INSTALLING]', envname)
            # ###
            # CONDITIONALs for independent packages cases, lets try to avoid this
            if 'hicexplorer' in envname:
                pkgs = pkg + ' hic2cool'
                cmd = base_cmd.format(envname, pkgs)
            elif 'snakePipes' in pkg:
                cmd = base_cmd.format('snakePipes -c mpi-ie', 'snakePipes')
            else:
                cmd = base_cmd.format(envname, pkg)
            run(cmd.split(), preexec_fn=demote(1015, 1015), env=myenv)
            # CONDITIONALs END
            # ###
        else:
            print(f'[NOT INSTALLING] {envname}:, already installed!')

def read_env_file(fname):
    """Returns a lsit with the packages to install as conda environments
    
    Parameters
    ----------
    fname : filename, str


    Returns
    -------
    out : 

    """
    pkg_list = []
    with open(fname) as inf:
        for line in inf:
            line = line.strip()
            if line =='':
                continue
            elif line[0] == '#' :
                continue
            elements = line.split()
            if len(elements) == 1:
                # only one package per line -- assume existence ib bioconda or conda-foge?
                pkg_list.append(elements[0])
            else:
                # TO DO
                # Here put what to do if you want a special environmet
                pass
    return pkg_list

def update_bashrc(home, distribution):
    """Update the /etc/bash.bashrc and backup the original one

    Keyword Arguments:
    home         -- 
    distribution -- 
    """
    # backup bashrc
    run(['cp', '/etc/bash.bashrc', '/etc/bash.bashrc.backup'])
    with open('/etc/bash.bashrc.backup', 'a') as backuprc:
        msg = ("\n\n# --- Backup of /bash.bashrc created\n"
               "# --- by SEISbio installation\n")
        backuprc.write(msg)
        
    # Get conda bashrc stringtie
    conda_re = re.compile('(# >>> conda initialize >>>.*'
                          '# <<< conda initialize <<<)',
                          re.DOTALL)
    with open(f'/home/{home}/.bashrc') as inf:
        text = inf.read()
    try:
        conda_text = conda_re.findall(text)[0]
    except IndexError:
        print(f'[WARN] Something is wrong with /home/{home}/.bashrc file!')
        print('[EXIT!]')
        exit()
    # Update /etc/bash.bashrc
    with open('/etc/bash.bashrc', 'a') as bashrc:
        bashrc.write('\n\n# --- Added by SEISbio\n' + conda_text)


def main():

    args = arguments()
    if args.distribution == 'mambaforge':
        manager = 'mamba'
    elif args.distribution == 'miniconda':
        manager = 'conda'
    else:
        print(f'[WARN] Unrecognized distribution: {args.distribution}')
        exit()
    print('[START] Installing system packages')
    debian_install_bioinfo(upgrade=args.debupgrade)
    print('f[INFO] Creating {args.home} user if not exists.')
    if not os.path.exists(f'/home/{args.home}'):
        print(f'[INFO] Creating {args.home} user and asking for a password.')
        print('=====================')
        # adduser only works this way in Debian distrso
        # ArchLinux : install adduser-deb from AUR
        cmd_create = f"""adduser --shell /bin/bash --uid 1015 --gecos '' {args.home}""".split()
        subprocess.run(cmd_create)
        print('=====================')
        print(f'[INFO] {args.home} user created')
        print('=====================')
    else:
        print(f'[WARN] {args.home} user already exists!!!')
        print('[INFO] Consider to delete this user')
        print(f'   $ sudo userdel -r {args.home}')
        # TO DO : ask if ending program or continue with risk
        print('[END] exit program doing nothing!')
        # exit()n(distri
    
    print(f'[INFO] Moving to {args.home} home')
    os.chdir(f'/home/{args.home}/')
    print('=====================')
    installerfilename = donwload_distribution(distribution=args.distribution)

    if not os.path.exists(f'/home/{args.home}/{args.distribution}'):
        print(f'[INFO] Installing {args.distribution}.')
        install_distribution(installerfilename, distribution=args.distribution,
                             home=args.home)
        print('[INFO] Updating /etc/bash.bashrc')
        update_bashrc(args.home, args.distribution)
    else:
        print(f'[INFO] {args.distribution} already isntalled.')

    print('[INFO] Updating anaconda and isntalling basic packages.')
    update_distribution(manager=manager,
                        distribution=args.distribution,
                        home=args.home
                        )
    print('[INFO] Base scientific packages.')
    install_distribution_base(manager=manager,
                              distribution=args.distribution,
                              home=args.home
                              )
    
    print('[INFO] virtual envs.')
    env_list = read_env_file(args.envfile)
    install_virtual_envs(env_list,
                         manager=manager,
                         distribution=args.distribution,
                         home=args.home
                         )
    print('[END] All packages instaled')


if __name__ == '__main__':
    main()
