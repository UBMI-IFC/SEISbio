# Basic isntalation of scientific stack for miniconda
# Installing one at a time in order to catch problems

########################################
# For a Python script you can use this #
########################################
# https://stackoverflow.com/questions/41767340/using-conda-install-within-a-python-script
# import conda.cli.python_api as Conda
# import sys

# ###################################################################################################
# # Either:
# #   conda install -y -c <CHANNEL> <PACKAGE>
# # Or (>= conda 4.6)
# #   conda install -y <CHANNEL>::<PACKAGE>

# (stdout_str, stderr_str, return_code_int) = Conda.run_command(
#     Conda.Commands.INSTALL,
#     '-c', '<CHANNEL>',
#     '<PACKAGE>'
#     use_exception_handler=True, stdout=sys.stdout, stderr=sys.stderr
# )

conda update --all -y ;

# maybe is important to install these (both present in base):
# pytest
# cython
# 

conda install -y numpy ;
conda install -y scipy ;
conda install -y matplotlib ;
conda install -y pandas ;
conda install -y statsmodels ;
conda install -y seaborn ;
conda install -y biopython ;
conda install -y scikit-learn ;
conda install -y scikit-image ;
# scikit bio conflicts :(
# conda install -y scikit-bio ;
conda install -y networkx ;
conda install -y jupyter ;
conda install -y spyder ;
# no problem with orange installation
conda install -y orange3 ;
# no problem with keras installation
conda install -y keras ;
# jupyterlab
conda install -y jupyterlab
# Downgrades pysmq zeromq
# conda install -y r-irkernel;
# rstudio donwgrades arrond 4 packages
# conda install -y rstudio ;
