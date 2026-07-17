# scRNA-perturbation-oracle V1.18：基于 V1.17 叠加 papermill（Quarto -P 参数执行）。
#
# V1.17 已修复 Jupyter/nbformat；Galaxy 工具 quarto render -P ... 仍需 papermill：
#   The papermill package is required for processing --execute-params
#
# 构建：
#   docker build -t quay.io/1733295510/scrna-perturbation-oracle:V1.18 .
#   docker push quay.io/1733295510/scrna-perturbation-oracle:V1.18

ARG BASE_IMAGE=quay.io/1733295510/scrna-perturbation-oracle:V1.17
FROM ${BASE_IMAGE}

LABEL maintainer="1733295510 <1733295510@qq.com>"
LABEL org.opencontainers.image.title="scRNA-perturbation-oracle"
LABEL org.opencontainers.image.description="CellOracle virtual KO/OE on V1.17 + papermill for Quarto -P params."

ENV QUARTO_PYTHON=/opt/miniconda/envs/celloracle_env/bin/python3

USER root

# Step R：Quarto render -P / --execute-params 所需
RUN /opt/miniconda/bin/mamba install -n celloracle_env -c conda-forge -y \
      papermill \
 && /opt/miniconda/bin/mamba clean -afy

# Step S：验收
RUN /opt/miniconda/envs/celloracle_env/bin/python3 -c "\
import papermill; \
print('papermill OK', papermill.__version__)\
" \
 && quarto check jupyter 2>&1 | tee /tmp/quarto-jupyter-check.txt \
 && grep -q "Checking Python 3 installation" /tmp/quarto-jupyter-check.txt \
 && ! grep -q "Jupyter: (None)" /tmp/quarto-jupyter-check.txt \
 && grep -q "\[✓\] Checking Jupyter engine render" /tmp/quarto-jupyter-check.txt

WORKDIR /work
