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
    return subprocess.run(cmd, preexec_fn=demote(1015, 1015))


def install_miniconda():
#    cmd_p = ['sudo', '-u', 'anaconda', 'chmod', 'u+x',
#            '/home/anaconda/Miniconda3-latest-Linux-x86_64.sh']
#    subprocess.run(cmd_p)
    # cmd = ['sudo', '-u', 'anaconda',
    #        'bash', '/home/anaconda/Miniconda3-latest-Linux-x86_64.sh', '-b',
    #        '-p', '/home/anaconda/miniconda3']
    myenv = os.environ.copy()
    myenv['HOME'] = '/home/anaconda'
    subprocess.run(['echo', '$HOME'])
    # INSTALL
    ## TODO : define by the user the conda prefix
    cmd = ['bash', '/home/anaconda/Miniconda3-latest-Linux-x86_64.sh', '-b',
           '-p', '/home/anaconda/miniconda3']
    subprocess.run(cmd, preexec_fn=demote(1015, 1015), env=myenv)
    # init conda
    cmd_init = ['/home/anaconda/miniconda3/bin/conda', 'init']
    subprocess.run(cmd_init, preexec_fn=demote(1015, 1015), env=myenv)

#########################################
## main
#########################################

print('[INFO] Creating anaconda user if not exists.')

if not os.path.exists('/home/anaconda'):
    print('[INFO] Creating anaconda user and asking for a password.')
    print('=====================')
    cmd_create = """adduser --shell /bin/bash --uid 1015 --gecos '' anaconda""".split()
    subprocess.run(cmd_create)
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
print('[INFO] Installing miniconda and ')
install_miniconda()

