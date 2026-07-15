# scRNA-perturbation-oracle V1.0.0：CellOracle 虚拟敲除 / 过表达（Phase 2，Python + R 互操作）。
#
# 基于 quay.io/1733295510/scrna-interop:V2.5.2（含 Seurat、zellkonverter/reticulate、Quarto、/opt/venv），
# 叠加 celloracle、scanpy 及 GRN 模拟依赖。
#
# 典型工具：
#   scRNA_virtual_knockout_celloracle.qmd
#   scRNA_virtual_overexpression_celloracle.qmd
#
# 构建示例：
#   cd /home/ubuntu/zhaoyiran/TOOL-Dockerfile/singlecell/scRNA-perturbation-oracle
#   docker build -t quay.io/1733295510/scrna-perturbation-oracle:V1.0.0 .
#   docker push quay.io/1733295510/scrna-perturbation-oracle:V1.0.0
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

USER root

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    libxml2-dev \
    libxslt1-dev \
    zlib1g-dev \
    libffi-dev \
    libssl-dev \
 && rm -rf /var/lib/apt/lists/*

RUN /opt/venv/bin/pip install --no-cache-dir --upgrade pip setuptools wheel \
 && /opt/venv/bin/pip install --no-cache-dir \
    "scanpy>=1.9,<2" \
    "matplotlib>=3.7,<4" \
    "leidenalg>=0.10" \
    "python-igraph>=0.11" \
    "louvain>=0.8" \
    "genomepy>=0.16" \
    "gimmemotifs>=0.17" \
    "celloracle>=0.18" \
    "jupyter>=1.0" \
    "ipykernel>=6"

RUN R -e "nc <- suppressWarnings(as.integer(Sys.getenv('R_INSTALL_NCPUS', '4'))); \
  if (requireNamespace('BiocManager', quietly=TRUE)) { \
    BiocManager::install('zellkonverter', ask=FALSE, update=FALSE, Ncpus=nc); \
  } else { \
    install.packages('BiocManager', repos='https://cloud.r-project.org'); \
    BiocManager::install('zellkonverter', ask=FALSE, update=FALSE, Ncpus=nc); \
  }"

RUN /opt/venv/bin/python3 -c "\
import scanpy, matplotlib, celloracle; \
print('scRNA-perturbation-oracle OK:', \
      'scanpy', scanpy.__version__, \
      'celloracle', celloracle.__version__)\
" \
 && R -e "suppressPackageStartupMessages({library(Seurat); library(zellkonverter)}); cat('R interop OK\n')" \
 && quarto --version | head -1

WORKDIR /work
