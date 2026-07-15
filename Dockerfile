# scRNA-perturbation-oracle V1.0.0：CellOracle 虚拟敲除 / 过表达（Phase 2，Python + R 互操作）。
#
# 基于 quay.io/1733295510/scrna-interop:V2.5.2（R + /opt/venv anndata + Quarto），
# 另建 conda 环境 celloracle_env（Python 3.12）安装 CellOracle 栈。
#
# 说明：gimmemotifs 无 PyPI wheel，Python 3.12 下 pip 源码构建会因 versioneer/SafeConfigParser 失败。
# 参照 CellOracle 官方 CI：conda 预装 gimmemotifs/louvain，celloracle 用 --no-deps 避免 pip 重复拉取 gimmemotifs。
#
# 构建示例：
#   cd /home/ubuntu/zhaoyiran/TOOL-Dockerfile/singlecell/scRNA-perturbation-oracle
#   docker build -t quay.io/1733295510/scrna-perturbation-oracle:V1.0.0 .
#
# 同步到 Galaxy 集群镜像仓库：
#   docker tag quay.io/1733295510/scrna-perturbation-oracle:V1.0.0 \
#     genaibase-cn-beijing.cr.volces.com/genaibase/scrna-perturbation-oracle:v1
#   docker push genaibase-cn-beijing.cr.volces.com/genaibase/scrna-perturbation-oracle:v1

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

# 1) Miniconda + 预编译依赖（禁止在此阶段 pip install gimmemotifs/celloracle 到 /opt/venv）
RUN wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh \
 && bash /tmp/miniconda.sh -b -p ${CONDA_DIR} \
 && rm /tmp/miniconda.sh \
 && ${CONDA_DIR}/bin/conda config --set always_yes yes --set changeps1 no \
 && ${CONDA_DIR}/bin/conda create -n ${CELLORACLE_ENV} python=3.12 \
 && ${CONDA_DIR}/bin/conda install -n ${CELLORACLE_ENV} -c bioconda -c conda-forge \
      gimmemotifs \
      louvain \
      cython \
      numpy \
      numba \
      scipy \
      pandas \
      matplotlib \
      seaborn \
      scikit-learn \
      h5py \
      pyarrow \
      tqdm \
      python-igraph \
      umap-learn \
      anndata \
      scanpy \
      joblib

# 2) celloracle 仅用 wheel + --no-deps，避免 pip 再次从 PyPI 源码编译 gimmemotifs
RUN ${CONDA_DIR}/bin/conda run -n ${CELLORACLE_ENV} pip install --no-cache-dir --no-build-isolation --no-deps \
      "celloracle==0.18.0"

RUN R -e "nc <- suppressWarnings(as.integer(Sys.getenv('R_INSTALL_NCPUS', '4'))); \
  if (requireNamespace('BiocManager', quietly=TRUE)) { \
    BiocManager::install('zellkonverter', ask=FALSE, update=FALSE, Ncpus=nc); \
  } else { \
    install.packages('BiocManager', repos='https://cloud.r-project.org'); \
    BiocManager::install('zellkonverter', ask=FALSE, update=FALSE, Ncpus=nc); \
  }"

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
