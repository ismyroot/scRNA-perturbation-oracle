# scRNA-perturbation-oracle V1.0.0：CellOracle 虚拟敲除 / 过表达（Phase 2，Python + R 互操作）。
#
# 基于 quay.io/1733295510/scrna-interop:V2.5.2（R + /opt/venv anndata + Quarto），
# 另建 conda 环境 celloracle_env（Python 3.12）安装 CellOracle 栈。
#
# 说明：
# - gimmemotifs-minimal 0.18（bioconda）；gimmemotifs 0.18 已移除 default_motifs API。
# - PyPI celloracle 0.18.0 仍硬依赖 default_motifs，故从 GitHub 安装含兼容 shim 的版本。
# - 每个 mamba/pip 安装单独 RUN，便于平台超时重试时复用缓存层。

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

# Step B：Miniforge
RUN wget -q https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh -O /tmp/miniforge.sh \
 && bash /tmp/miniforge.sh -b -p ${CONDA_DIR} \
 && rm /tmp/miniforge.sh \
 && ${CONDA_DIR}/bin/conda config --set always_yes yes --set changeps1 no \
 && ${CONDA_DIR}/bin/conda config --set channel_priority flexible \
 && ${CONDA_DIR}/bin/conda config --add channels conda-forge \
 && ${CONDA_DIR}/bin/conda config --add channels bioconda

# Step C：Python 环境
RUN ${CONDA_DIR}/bin/mamba create -n ${CELLORACLE_ENV} python=3.12

# Step D：图算法 / 编译依赖
RUN ${CONDA_DIR}/bin/mamba install -n ${CELLORACLE_ENV} -c conda-forge -c bioconda \
      louvain \
      cython \
      numpy \
      numba

# Step E：数值与机器学习基础
RUN ${CONDA_DIR}/bin/mamba install -n ${CELLORACLE_ENV} -c conda-forge \
      scipy \
      pandas \
      scikit-learn \
      joblib \
      tqdm

# Step F：HDF / Arrow I/O
RUN ${CONDA_DIR}/bin/mamba install -n ${CELLORACLE_ENV} -c conda-forge \
      h5py \
      pyarrow

# Step G：绑图（matplotlib-base 无 Qt）
RUN ${CONDA_DIR}/bin/mamba install -n ${CELLORACLE_ENV} -c conda-forge \
      matplotlib-base \
      seaborn-base

# Step H：降维
RUN ${CONDA_DIR}/bin/mamba install -n ${CELLORACLE_ENV} -c conda-forge \
      python-igraph \
      umap-learn

# Step I：单细胞栈
RUN ${CONDA_DIR}/bin/mamba install -n ${CELLORACLE_ENV} -c conda-forge \
      anndata \
      scanpy

# Step J：gimmemotifs-minimal（bioconda 核心库，已含 genomepy）
RUN ${CONDA_DIR}/bin/mamba install -n ${CELLORACLE_ENV} -c conda-forge -c bioconda \
      gimmemotifs-minimal

# Step K：goatools
RUN ${CONDA_DIR}/bin/mamba run -n ${CELLORACLE_ENV} pip install --no-cache-dir --no-build-isolation \
      "goatools"

# Step L：velocyto
RUN ${CONDA_DIR}/bin/mamba run -n ${CELLORACLE_ENV} pip install --no-cache-dir --no-build-isolation \
      "velocyto>=0.17"

# Step M：celloracle + 运行时依赖（同层安装，避免平台漏跑 M2；git --no-deps 不含 IPython）
RUN ${CONDA_DIR}/bin/mamba run -n ${CELLORACLE_ENV} pip install --no-cache-dir --no-build-isolation \
      "ipython" "matplotlib-inline<=0.1.7" \
 && ${CONDA_DIR}/bin/mamba run -n ${CELLORACLE_ENV} pip install --no-cache-dir --no-build-isolation --no-deps \
      "git+https://github.com/morris-lab/CellOracle.git@aad70bd"

# Step N：R 侧 RDS → h5ad
RUN R -e "nc <- suppressWarnings(as.integer(Sys.getenv('R_INSTALL_NCPUS', '4'))); \
  if (requireNamespace('BiocManager', quietly=TRUE)) { \
    BiocManager::install('zellkonverter', ask=FALSE, update=FALSE, Ncpus=nc); \
  } else { \
    install.packages('BiocManager', repos='https://cloud.r-project.org'); \
    BiocManager::install('zellkonverter', ask=FALSE, update=FALSE, Ncpus=nc); \
  }"

# Step O：验收
RUN ${CONDA_DIR}/envs/${CELLORACLE_ENV}/bin/python3 -c "\
import celloracle as co; \
import scanpy; \
import matplotlib; \
base = co.data.load_mouse_scATAC_atlas_base_GRN(force_download=False); \
print('scRNA-perturbation-oracle OK:', \
      'scanpy', scanpy.__version__, \
      'celloracle', co.__version__, \
      'matplotlib', matplotlib.__version__, \
      'base_grn_rows', len(base))\
" \
 && R -e "suppressPackageStartupMessages({library(Seurat); library(zellkonverter)}); cat('R interop OK\n')" \
 && quarto --version | head -1

WORKDIR /work
