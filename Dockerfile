# scRNA-perturbation-oracle V1.19：基于 V1.18 叠加 scikit-misc（scanpy seurat_v3 HVG）。
#
# Job 2979：sc.pp.highly_variable_genes(flavor="seurat_v3") 需要 skmisc.loess
#   ModuleNotFoundError: No module named 'skmisc'
#
# 构建：
#   docker build -t quay.io/1733295510/scrna-perturbation-oracle:V1.19 .
#   docker push quay.io/1733295510/scrna-perturbation-oracle:V1.19

ARG BASE_IMAGE=quay.io/1733295510/scrna-perturbation-oracle:V1.18
FROM ${BASE_IMAGE}

LABEL maintainer="1733295510 <1733295510@qq.com>"
LABEL org.opencontainers.image.title="scRNA-perturbation-oracle"
LABEL org.opencontainers.image.description="CellOracle virtual KO/OE on V1.18 + scikit-misc for scanpy seurat_v3 HVG."

ENV QUARTO_PYTHON=/opt/miniconda/envs/celloracle_env/bin/python3

USER root

# Step T：scanpy highly_variable_genes(flavor="seurat_v3") 所需
RUN /opt/miniconda/bin/mamba install -n celloracle_env -c conda-forge -y \
      scikit-misc \
 && /opt/miniconda/bin/mamba clean -afy

# Step U：验收
RUN /opt/miniconda/envs/celloracle_env/bin/python3 -c "\
from skmisc.loess import loess; \
import scanpy as sc; \
print('scikit-misc OK', loess); \
print('scanpy OK', sc.__version__)\
"

WORKDIR /work
