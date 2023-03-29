#!/bin/bash

# A set of scripts for projects that I work on. run the following line to access these functions
# echo "source ~/scripts/shortcuts.sh" >> ~/.bashrc

# End the current working session
bye() {

    # Close any conda windows
    if ! [[ -z "${CONDA_DEFAULT_ENV}" ]] ; then
        conda deactivate
    fi

    # Go to home
    cd
}

cuda-versions() {
    echo "=========================================================================="
    echo "CUDA Toolkit Version (nvcc --version) [Needs to be lower than Driver version]" 
    echo "------------------------------------------------"
    nvcc --version

    echo "=========================================================================="
    echo "Cuda GPU Driver Version (nvidia-smi)": 
    echo "------------------------------------------------"
    nvidia-smi
}

glibc-version() {
    echo "=========================================================================="
    echo "GLIBC Version (ldd --version)": 
    echo "------------------------------------------------"  
    ldd --version
}

versions() {
    cuda-versions 
    glibc-version

    echo "========================================================"
    echo "Python Version (python3 version)": 
    python3 --version

    echo "========================================================"
    echo "Git Version (git --version)": 
    git --version
}