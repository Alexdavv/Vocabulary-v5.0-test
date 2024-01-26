# Mapping machine
This repository hosts the Mapping Machine: OHDSI vocabularies solution for automated finding
matches in the from source to target concepts mapping task.

# Requirements
* Windows
    - Linux, WSL or MacOS all should work, but are not the primary target. Make
    sure to use `environment-compat.yaml` to install the correct versions for
    important packages, and let Conda handle the rest. Compatibility may be
    limited!
* A lot of RAM (at least, 32 Gb, while 64 Gb or more is preferable)
* Conda installation

# How to work with this repository
1. Install [Conda](https://docs.anaconda.com/free/anaconda/install/index.html)(anaconda/miniconda)
2. Clone this repository
3. Change (`cd`) into the cloned repository and run:
    ```sh
    conda env create
    conda activate mapping_machine
    pre-commit install
    ```
    This will make sure you have compatible versions of all libraries and
    consistent development environment. Only `conda activate mapping_machine`
    needs to be ran on subsequent sessions.

4. Place all input files in `source/`
5. Place all downloaded binary models (e.g. BioWordVec) in `models/`. If you do
not have them, Mapping Machine will download them.
6. Update names of input files and execution constants in the second cell.
*TODO: move this to a config file*
7. Start `jupyter lab` or `jupyter notebook` **from this conda environment**.
It might work with your system installation or a base environment, but is not
likely to. Visual Studio Code or any other IDE with `.ipynb` support will also
work, but you need to make sure to select the correct ipykernel.
8. After runnning the interactive session, intermediary files can be found in
`working` and resulting output in `output`.

# Contributing
* It is recommended to run `pre-commit` when first initializing this repository
or to manually clean all cell outputs before commiting changes to the notebook.
* If you are installing additional packages, [prefer](https://docs.anaconda.com/free/anaconda/packages/install-packages/)
`conda install` to `pip install`. Make sure to run `conda env export` and to
subsequently include `environment.yaml` in the commit to reflect changes to the
environment.
