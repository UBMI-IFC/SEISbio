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
import sys
import argparse
import re
from subprocess import run
from subprocess import PIPE
from subprocess import check_output
from subprocess import TimeoutExpired
from subprocess import CalledProcessError
from pathlib import Path
# TODO (acph) add time tolerance to subprocess functoins
# TODO (acph) ... and catch TimeoutExpired
# TODO (acph) catch CalledProcessError ? it is necessary
#      In particular when the programm tries to do actions
#      as other user
# TODO (acph) add verbose for all functions 0.0
# TODO (acph) Complete documentation
# TODO (acph) Encapsulate isntall function or create one
#      for local and one for system wide isntallation


def arguments():
    """Argument parser function"""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('-d', '--distribution', default='mambaforge',
                        choices=['mambaforge', 'miniconda'],
                        help='Select scientific software distribution.')
    parser.add_argument('--home', default='seisbio',
                        help='User and home directory to create for the '
                        'distribution installation.'
                        'This will be created in /home/')
    parser.add_argument('--homeid', default=1015,
                        help='Distribution user UID and GUID')
    parser.add_argument('--debian', default=False, action='store_true',
                        help='Install basic and bioinformatic packages from '
                        'Debian/Ubuntu repositories. The lists of packages  '
                        'are specified in the dev directory in SEISbio root '
                        'directory.')
    parser.add_argument('--debupgrade', action='store_true', default=False,
                        help='If specified  UPDATE Debian/ubuntu system')
    parser.add_argument('-f', '--envfile', default='virtual_envs.txt',
                        help=('Files that specifies the virtual environments'
                              'to create in SEISbio instalation.'
                              'Default=./virtual_envs.txt. You can read'
                              'the file specification in ./virtual_envs.txt'))
    parser.add_argument('--local', default=False, action='store_true',
                        help='Prefers a local installation instead of a system'
                        ' wide isntallation. Does not needs root access.')
    # TODO(acph) Select instalation path
    # TODO(acph) Select local or systemwide isntalation
    args = parser.parse_args()
    return args


def debian_install_bioinfo(upgrade=False):
    """Installing bioinfo basic packages from Debian/Ubuntu repositories.
    WARNING: Only for debian/ubuntu

    1. Update
    2. Upgrade
    3. Install basic programs (emacs, vim, lm-sensors, htop, aptitude)
    4. Bioinfo software
    """
    cmd_update = ['apt', 'update']
    cmd_upgrade = ['apt', 'upgrade', '-y']
    # reading package lists
    basic_file = Path(__file__).parent.absolute()/'deb/basic_pkgs.txt'
    bioinfo_file = Path(__file__).parent.absolute()/'deb/bioinfo_pkgs.txt'
    #
    basic_pkgs = read_env_file(basic_file)
    bioinfo_pkgs = read_env_file(bioinfo_file)
    #
    cmd_basic = ['apt', 'install', '-y'] + basic_pkgs
    cmd_bioinfo = ['apt', 'install', '-y'] + bioinfo_pkgs

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
    user_uid = int(user_uid)
    user_gid = int(user_gid)

    def set_ids():
        os.setgid(user_gid)
        os.setuid(user_uid)
    return set_ids


def check_id_as_user():
    """Run the command 'id' in a subprocess as user 1010,
    return the result

    THIS FUNCTION IS NOT USED

    https://gist.github.com/sweenzor/1685717"""

    cmd = ['id']
    return check_output(cmd, preexec_fn=demote(1015, 1015))


def donwload_distribution(distribution='mambaforge', uid='1015', home='seisbio'):
    """Downloads the latest installator from the scientific distribution
to isntall.

    Keyword Arguments:
    distribution -- str (default 'mambaforge')
             'mambaforge' | 'miniconda'
    """
    urls = {'mambaforge':
            'https://github.com/conda-forge/miniforge/releases/latest/download/Mambaforge-Linux-x86_64.sh',
            'miniconda':
            'https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh'}
    url = urls[distribution]
    cmd = ['wget', '-N', url, '-P', '/home/'+home]
    check_output(cmd, preexec_fn=demote(uid, uid), stderr=PIPE)
    filename = url.split('/')[-1]
    return filename


def install_distribution(installer, distribution='mambaforge', home='seisbio', uid=1015):
    """Downloads the latest installator from the scientific distribution
to isntall.

    Keyword Arguments:
    distribution -- str (default 'mambaforge')
             'mambaforge' | 'miniconda'
    """
    myenv = os.environ.copy()
    myenv['HOME'] = f'/home/{home}'
    # run(['echo', '$HOME'])
    # se podra ejecutar con sudo esta parte?
    # INSTALL
    cmd = ['bash', f'/home/{home}/{installer}', '-b',
           '-p', f'/home/{home}/{distribution}']
    check_output(cmd, preexec_fn=demote(uid, uid), env=myenv)
    # init conda, [WARN]
    cmd_init = [f'/home/{home}/{distribution}/bin/conda', 'init']
    check_output(cmd_init, preexec_fn=demote(uid, uid), env=myenv)


def update_distribution(manager='mamba', distribution='mambaforge',
                        home='seisbio', uid=1015):
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
           '--all',
           '-q']
    check_output(cmd, preexec_fn=demote(uid, uid), env=myenv,
                 stderr=PIPE, timeout=600)


def install_distribution_base(manager='mamba',
                              distribution='mambaforge',
                              home='seisbio', uid=1015):
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
           '-q',
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
    check_output(cmd, preexec_fn=demote(uid, uid), env=myenv,
                 stderr=PIPE, timeout=600)


def install_virtual_envs(pkg_list, manager='mamba',
                         distribution='mambaforge',
                         home='seisbio', uid=1015):
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
    env_info = check_output([manager_path, 'info', '--env']).decode()
    # env_info = run([manager_path, 'info',  '--env'], stdout=PIPE)
    # env_info = env_info.stdout.decode()
    base_cmd = manager_path + ' create -n {} -c bioconda -c conda-forge {} -y -q'
    for pkg in pkg_list:
        if '=' in pkg:
            pkname, version = pkg.split('=')
            version = version.replace('.', '')
            envname = pkname + version + '-env'
        else:
            envname = pkg + '-env'
        if envname not in env_info:
            print('[INSTALLING]', 'Environmet for', envname, 'package')
            # ###
            # CONDITIONALs for independent packages cases, lets try to avoid this
            if 'hicexplorer' in envname:
                pkgs = pkg + ' hic2cool'
                cmd = base_cmd.format(envname, pkgs)
            elif 'snakePipes' in pkg:
                cmd = base_cmd.format('snakePipes -c mpi-ie', 'snakePipes')
            else:
                cmd = base_cmd.format(envname, pkg)
            check_output(cmd.split(), preexec_fn=demote(uid, uid), env=myenv,
                         stderr=PIPE, timeout=600)
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
            if line == '':
                continue
            elif line[0] == '#':
                continue
            elements = line.split()
            if len(elements) == 1:
                # only one package per line --
                # assume existence ib bioconda or conda-foge?
                pkg_list.append(elements[0])
            else:
                # TODO
                # Here put what to do if you want a special environmet
                pass
    return pkg_list


def update_bashrc(home, distribution):
    """Update the /etc/bash.bashrc and backup the original one

    Keyword Arguments:
    home         --
    distribution --
    bashrc       -- str, filepath
                    Bash rc file to modify
    """
    # backup bashrcn
    check_output(['cp', '/etc/bash.bashrc', '/etc/bash.bashrc.backup'])
    with open('/etc/bash.bashrc.backup', 'a') as backuprc:
        msg = ("\n\n# --- Backup of /bash.bashrc created\n"
               "# --- by SEISbio installation\n")
        backuprc.write(msg)

    # Get conda bashrc stringt RE
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
    # TODO (acph) ask if superuser
    args = arguments()
    if args.distribution == 'mambaforge':
        manager = 'mamba'
    elif args.distribution == 'miniconda':
        manager = 'conda'
    else:
        print(f'[WARN] Unrecognized distribution: {args.distribution}')
        sys.exit()
    # user info
    user = os.getlogin()
    uid = os.getuid()
    guid = os.getgid()
    # Env file
    if args.envfile == 'virtual_envs.txt':
        # default file
        mypath = Path(__file__)
        envfile = mypath.parent.absolute()/args.envfile
        print('     ... from default file:')
        print(f'     ... {envfile}')
    else:
        envfile = Path().absolute()/args.envfile
        print('     ... from file:')
        print(f'     ... {envfile}')

    # Isntalling
    if args.local:
        # TODO (acph) sub menus or warning of ignoring arguments
        print('[INFO] Installing systemm locally')
        print(f'[INFO] in  user {user} (uid: {uid}, gid:{guid})')
        args.home = user
        args.homeid = uid
        install(args)
        print('------ but no yet --------')
        print('------ working on it -----')
        sys.exit()
    else:
        if uid != 0:
            print('[INFO] You need to be root to install SEIS system wide'
                  ' or use --local flag for local installation.')
            print(f'       You are {user}!')
            print('[END] Ending program.')
            sys.exit()

    print('============ Installing as root')
    if args.debian:
        print('[START] Installing system packages for Debian/Ubuntu.')
        debian_install_bioinfo(upgrade=args.debupgrade)

    # creating seisbio user
    print(f'[INFO] Creating {args.home} user if not exists.')
    if not os.path.exists(f'/home/{args.home}'):
        print(f'[INFO] Creating {args.home} user and asking for a password.')
        print('=====================')
        # adduser only works this way in Debian distrso
        # ArchLinux : install adduser-deb from AUR
        # cmd_create = f"""adduser --shell /bin/bash --uid 1015 --gecos '' {args.home}""".split()
        # run(cmd_create)
        cmd_create = f"useradd -s /bin/bash -u {args.homeid} -m {args.home}".split()
        check_output(cmd_create)
        # password
        print(f'[INFO] Configuring {args.home} user.')
        print(f'[INPUT] Enter {args.home} user password:')
        cmd_passwd = ['passwd', args.home]
        check_output(cmd_passwd)
        # permissions
        cmd_chmod = ['chmod', '-R', 'go+r', f'/home/{args.home}']
        check_output(cmd_chmod)
        cmd_chmod = ['chmod', 'go+x', f'/home/{args.home}']
        check_output(cmd_chmod)

        print('=====================')
        print(f'[INFO] {args.home} user created')
        print('=====================')
    else:
        print(f'[WARN] {args.home} user already exists!!!')
        print('[INFO] Consider to delete this user')
        print(f'   $ sudo userdel -r {args.home}')
        answer = input("Do you want to continue? y/[n]: ")
        if answer == 'y':
            print('[INFO] Continue installation')
        elif answer == 'n':
            print('[END] exit program doing nothing more!')
            exit()
        else:
            print('[END] Invalid answer: exit!')
            exit()

    print(f'[INFO] Moving to {args.home} home')
    os.chdir(f'/home/{args.home}/')
    print('=====================')
    print(f'[INFO] Downloading {args.distribution} distribution')

    installerfilename = donwload_distribution(distribution=args.distribution,
                                              uid=args.homeid,
                                              home=args.home)

    if not os.path.exists(f'/home/{args.home}/{args.distribution}'):
        print(f'[INFO] Installing {args.distribution}.')
        install_distribution(installerfilename, distribution=args.distribution,
                             home=args.home, uid=args.homeid)
        print('[INFO] Updating /etc/bash.bashrc')
        update_bashrc(args.home, args.distribution)
        installed = False
    else:
        installed = True
        print(f'[INFO] {args.distribution} already isntalled.')

    if installed:
        answer_installed = input(f'Do you want to update base {args.distribution}'
                                 ' installation? y/[n]')
        if answer_installed == 'y':
            print('[INFO] Updating anaconda and isntalling basic packages.')
            update_distribution(manager=manager,
                                distribution=args.distribution,
                                home=args.home,
                                uid=args.homeid
                                )
            print('[INFO] Installing base scientific packages.')
            install_distribution_base(manager=manager,
                                      distribution=args.distribution,
                                      home=args.home,
                                      uid=args.homeid
                                      )
        elif answer_installed == 'n':
            print('[INFO]  Continue with envs installation!')
        else:
            print('[END] Invalid answer: exit!')
            exit()
    else:
        print('[INFO] Updating anaconda and isntalling basic packages.')
        update_distribution(manager=manager,
                            distribution=args.distribution,
                            home=args.home,
                            uid=args.homeid
                            )
        print('[INFO] Installing base scientific packages.')
        install_distribution_base(manager=manager,
                                  distribution=args.distribution,
                                  home=args.home,
                                  uid=args.homeid
                                  )

    print('[INFO] virtual envs.')
    # envfile defintion at the begining of main()b
    env_list = read_env_file(envfile)
    install_virtual_envs(env_list,
                         manager=manager,
                         distribution=args.distribution,
                         home=args.home,
                         uid=args.homeid
                         )
    print('[END] All packages instaled')


def install(args):
    # Distribution
    if args.distribution == 'mambaforge':
        manager = 'mamba'
    elif args.distribution == 'miniconda':
        manager = 'conda'
    else:
        print(f'[WARN] Unrecognized distribution: {args.distribution}')
        sys.exit()
    # envfile
    if args.envfile == 'virtual_envs.txt':
        # default file
        mypath = Path(__file__)
        envfile = mypath.parent.absolute()/args.envfile
        print('     ... from default file:')
        print(f'     ... {envfile}')
    else:
        envfile = Path().absolute()/args.envfile
        print('     ... from file:')
        print(f'     ... {envfile}')

    print(f'[INFO] Downloading {args.distribution} distribution.')
    installerfilename = donwload_distribution(distribution=args.distribution,
                                              uid=args.homeid,
                                              home=args.home)

    if not os.path.exists(f'/home/{args.home}/{args.distribution}'):
        print(f'[INFO] Installing {args.distribution}.')
        install_distribution(installerfilename, distribution=args.distribution,
                             home=args.home, uid=args.homeid)
        # print('[INFO] Updating /etc/bash.bashrc')
        # update_bashrc(args.home, args.distribution)
        installed = False
    else:
        installed = True
        print(f'[INFO] {args.distribution} already installed.')

    if installed:
        answer_installed = input('Do you want to update base {args.distribution}'
                                 ' installation? y/[n]')
        if answer_installed == 'y':
            print('[INFO] Updating anaconda and isntalling basic packages.')
            update_distribution(manager=manager,
                                distribution=args.distribution,
                                home=args.home,
                                uid=args.homeid
                                )
            print('[INFO] Installing scientific packages.')
            install_distribution_base(manager=manager,
                                      distribution=args.distribution,
                                      home=args.home,
                                      uid=args.homeid
                                      )
        elif answer_installed == 'n':
            print('[INFO]  Continue with envs installation!')
        else:
            print('[END] Invalid answer: exit!')
            exit()
    else:
        print('[INFO] Updating anaconda and isntalling basic packages.')
        update_distribution(manager=manager,
                            distribution=args.distribution,
                            home=args.home,
                            uid=args.homeid
                            )
        print('[INFO] Installing base scientific packages.')
        install_distribution_base(manager=manager,
                                  distribution=args.distribution,
                                  home=args.home,
                                  uid=args.homeid
                                  )

    print('[INFO] virtual envs.')
    # envfile defintion at the begining of main()b
    env_list = read_env_file(envfile)
    install_virtual_envs(env_list,
                         manager=manager,
                         distribution=args.distribution,
                         home=args.home,
                         uid=args.homeid
                         )
    print('[END] All packages instaled')


if __name__ == '__main__':
    main()
