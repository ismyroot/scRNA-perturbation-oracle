# scRNA-perturbation-oracle V1.0.0：CellOracle 虚拟敲除 / 过表达（Phase 2，Python + R 互操作）。
#
# 基于 quay.io/1733295510/scrna-interop:V2.5.2（R + /opt/venv anndata + Quarto），
# 另建 conda 环境 celloracle_env（Python 3.12）安装 CellOracle 栈。
#
# 说明：
# - gimmemotifs 须经 bioconda 预编译安装，不可 pip 源码构建（Py3.12 SafeConfigParser 问题）
# - 使用 Miniforge（conda-forge/bioconda），避免 Miniconda Anaconda ToS 非交互报错
# - conda/mamba 安装拆分为多个 RUN，便于平台超时重试时复用已缓存层
#
# 构建示例：
#   cd /home/ubuntu/zhaoyiran/TOOL-Dockerfile/singlecell/scRNA-perturbation-oracle
#   docker build -t quay.io/1733295510/scrna-perturbation-oracle:V1.0.0 .

ARG INTEROP_IMAGE=quay.io/1733295510/scrna-interop:V2.5.2
FROM ${INTEROP_IMAGE}

LABEL maintainer="1733295510 <1733295510@qq.com>"
LABEL org.opencontainers.image.title="scRNA-perturbation-oracle"
LABEL org.opencontainers.image.description="CellOracle virtual KO/OE on scrna-interop (Seurat RDS + Python GRN simulation)."

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV RETICULATE_PYTHON=/opt/venv/bin/python3
ENV MPLBACKEND=Agg
ENV CONDA_DIR=/opt/miniconda
ENV CELLORACLE_ENV=celloracle_env
ENV PATH=${CONDA_DIR}/bin:${PATH}
ENV QUARTO_PYTHON=${CONDA_DIR}/envs/${CELLORACLE_ENV}/bin/python3

USER root

# Step A：系统依赖
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    bedtools \
    cmake \
    wget \
    git \
    libxml2-dev \
    libxslt1-dev \
    zlib1g-dev \
    libffi-dev \
    libssl-dev \
 && rm -rf /var/lib/apt/lists/*

# Step B：Miniforge 基础（仅安装发行版，不装 CellOracle 依赖）
RUN wget -q https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh -O /tmp/miniforge.sh \
 && bash /tmp/miniforge.sh -b -p ${CONDA_DIR} \
 && rm /tmp/miniforge.sh \
 && ${CONDA_DIR}/bin/conda config --set always_yes yes --set changeps1 no \
 && ${CONDA_DIR}/bin/conda config --set channel_priority flexible \
 && ${CONDA_DIR}/bin/conda config --add channels conda-forge \
 && ${CONDA_DIR}/bin/conda config --add channels bioconda

# Step C：创建独立 Python 环境
RUN ${CONDA_DIR}/bin/mamba create -n ${CELLORACLE_ENV} python=3.12

# Step D：bioconda 重包（gimmemotifs 单独一层，通常最耗时）
RUN ${CONDA_DIR}/bin/mamba install -n ${CELLORACLE_ENV} -c conda-forge -c bioconda \
      gimmemotifs

# Step E：图算法 / 编译依赖
RUN ${CONDA_DIR}/bin/mamba install -n ${CELLORACLE_ENV} -c conda-forge -c bioconda \
      louvain \
      cython \
      numpy \
      numba

# Step F：科学计算基础栈
RUN ${CONDA_DIR}/bin/mamba install -n ${CELLORACLE_ENV} -c conda-forge \
      scipy \
      pandas \
      matplotlib \
      seaborn \
      scikit-learn \
      h5py \
      pyarrow \
      tqdm \
      joblib

# Step G：单细胞 / 降维依赖
RUN ${CONDA_DIR}/bin/mamba install -n ${CELLORACLE_ENV} -c conda-forge \
      python-igraph \
      umap-learn \
      anndata \
      scanpy

# Step H：celloracle wheel（--no-deps 避免 pip 再次拉取 gimmemotifs）
RUN ${CONDA_DIR}/bin/mamba run -n ${CELLORACLE_ENV} pip install --no-cache-dir --no-build-isolation --no-deps \
      "celloracle==0.18.0"

# Step I：R 侧 RDS → h5ad 互操作
RUN R -e "nc <- suppressWarnings(as.integer(Sys.getenv('R_INSTALL_NCPUS', '4'))); \
  if (requireNamespace('BiocManager', quietly=TRUE)) { \
    BiocManager::install('zellkonverter', ask=FALSE, update=FALSE, Ncpus=nc); \
  } else { \
    install.packages('BiocManager', repos='https://cloud.r-project.org'); \
    BiocManager::install('zellkonverter', ask=FALSE, update=FALSE, Ncpus=nc); \
  }"

# Step J：验收
RUN ${CONDA_DIR}/envs/${CELLORACLE_ENV}/bin/python3 -c "\
import scanpy, celloracle; \
print('scRNA-perturbation-oracle OK:', \
      'python', __import__('sys').version.split()[0], \
      'scanpy', scanpy.__version__, \
      'celloracle', celloracle.__version__)\
" \
 && R -e "suppressPackageStartupMessages({library(Seurat); library(zellkonverter)}); cat('R interop OK\n')" \
 && quarto --version | head -1

WORKDIR /work
