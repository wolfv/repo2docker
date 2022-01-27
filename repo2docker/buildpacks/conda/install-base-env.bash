#!/bin/bash
# This downloads and installs a pinned version of micromamba
# and sets up the base environment
set -ex

cd $(dirname $0)

export MAMBA_VERSION=0.19.1
export CONDA_VERSION=4.11.0

URL="https://anaconda.org/conda-forge/micromamba/${MAMBA_VERSION}/download/linux-64/micromamba-${MAMBA_VERSION}-0.tar.bz2"

# make sure we don't do anything funky with user's $HOME
# since this is run as root
unset HOME
mkdir -p ${CONDA_DIR}

time wget -qO- ${URL} | tar -xvj bin/micromamba
chmod 0755 /tmp/bin/micromamba

export MAMBA_ROOT_PREFIX=${CONDA_DIR}
export MAMBA_EXE="/tmp/bin/micromamba"

eval "$(/tmp/bin/micromamba shell hook -p ${CONDA_DIR} -s posix)"

micromamba activate

export PATH="${PWD}/bin:$PATH"

cat <<EOT >> ${CONDA_DIR}/.condarc
channels:
  - conda-forge
  - defaults
auto_update_conda: false
show_channel_urls: true
update_dependencies: false
# channel_priority: flexible
EOT

micromamba install conda=${CONDA_VERSION} mamba=${MAMBA_VERSION} -y

echo "installing notebook env:"
cat "${NB_ENVIRONMENT_FILE}"


time micromamba create -p ${NB_PYTHON_PREFIX} -f "${NB_ENVIRONMENT_FILE}"

if [[ ! -z "${NB_REQUIREMENTS_FILE:-}" ]]; then
    echo "installing pip requirements"
    cat "${NB_REQUIREMENTS_FILE}"
    ${NB_PYTHON_PREFIX}/bin/python -mpip install --no-cache --no-deps -r "${NB_REQUIREMENTS_FILE}"
fi
# empty conda history file,
# which seems to result in some effective pinning of packages in the initial env,
# which we don't intend.
# this file must not be *removed*, however
echo '' > ${NB_PYTHON_PREFIX}/conda-meta/history

if [[ ! -z "${KERNEL_ENVIRONMENT_FILE:-}" ]]; then
    # install kernel env and register kernelspec
    echo "installing kernel env:"
    cat "${KERNEL_ENVIRONMENT_FILE}"
    time micromamba create -p ${KERNEL_PYTHON_PREFIX} -f "${KERNEL_ENVIRONMENT_FILE}"

    if [[ ! -z "${KERNEL_REQUIREMENTS_FILE:-}" ]]; then
        echo "installing pip requirements for kernel"
        cat "${KERNEL_REQUIREMENTS_FILE}"
        ${KERNEL_PYTHON_PREFIX}/bin/python -mpip install --no-cache --no-deps -r "${KERNEL_REQUIREMENTS_FILE}"
    fi

    ${KERNEL_PYTHON_PREFIX}/bin/ipython kernel install --prefix "${NB_PYTHON_PREFIX}"
    echo '' > ${KERNEL_PYTHON_PREFIX}/conda-meta/history
    micromamba list -p ${KERNEL_PYTHON_PREFIX}
fi

# Clean things out!
time micromamba clean --all -y

# Remove the pip cache created as part of installing micromamba
rm -rf /root/.cache

chown -R $NB_USER:$NB_USER ${CONDA_DIR}

micromamba list -p ${NB_PYTHON_PREFIX}

# Set NPM config
${NB_PYTHON_PREFIX}/bin/npm config --global set prefix ${NPM_DIR}