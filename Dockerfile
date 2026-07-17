# scRNA-perturbation-oracle V1.17：基于已验证 V1.16 叠加 Quarto Python kernel 依赖。
#
# V1.16 已包含 CellOracle 全栈（FROM scrna-interop 全量构建，见 git tag V1.16）。
# 本层修复 Galaxy 工具 quarto render 报错：
#   ModuleNotFoundError: No module named 'nbformat'
#   Jupyter is not available in this Python installation.
#
# 构建：
#   docker build -t quay.io/1733295510/scrna-perturbation-oracle:V1.17 .
#   docker push quay.io/1733295510/scrna-perturbation-oracle:V1.17

ARG BASE_IMAGE=quay.io/1733295510/scrna-perturbation-oracle:V1.16
FROM ${BASE_IMAGE}

LABEL maintainer="1733295510 <1733295510@qq.com>"
LABEL org.opencontainers.image.title="scRNA-perturbation-oracle"
LABEL org.opencontainers.image.description="CellOracle virtual KO/OE on V1.16 + Quarto Python Jupyter stack."

ENV QUARTO_PYTHON=/opt/miniconda/envs/celloracle_env/bin/python3

USER root

# Step P：Quarto 执行 engine: python qmd 所需 Jupyter 最小栈
RUN /opt/miniconda/bin/mamba install -n celloracle_env -c conda-forge -y \
      nbformat \
      nbclient \
      ipykernel \
      jupyter_client \
      jupyter_core \
 && /opt/miniconda/bin/mamba clean -afy

# Step Q：验收（CellOracle 已在 V1.16 验证；此处确认 Quarto 可启动 Python kernel）
RUN /opt/miniconda/envs/celloracle_env/bin/python3 -c "\
import nbformat; \
import nbclient; \
import ipykernel; \
import jupyter_client; \
print('jupyter stack OK', 'nbformat', nbformat.__version__, 'nbclient', nbclient.__version__)\
" \
 && quarto check jupyter 2>&1 | tee /tmp/quarto-jupyter-check.txt \
 && grep -q "Checking Python 3 installation" /tmp/quarto-jupyter-check.txt \
 && ! grep -q "Jupyter: (None)" /tmp/quarto-jupyter-check.txt \
 && grep -q "Checking Jupyter engine render" /tmp/quarto-jupyter-check.txt \
 && grep -q "\[✓\] Checking Jupyter engine render" /tmp/quarto-jupyter-check.txt

WORKDIR /work
