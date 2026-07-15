# scRNA-perturbation-oracle

CellOracle 虚拟敲除 / 过表达 Galaxy 工具专用镜像（Phase 2）。

## 与 scrna-perturbation 的区别

| 镜像 | 语言栈 | 算法 |
|------|--------|------|
| `scrna-perturbation:v1` | 纯 R | scTenifoldKnk、decoupleR、Signature Shift 等 |
| `scrna-perturbation-oracle:v1` | R + Python | CellOracle GRN + 嵌入向量场 |

## 依赖基础镜像

- `quay.io/1733295510/scrna-interop:V2.5.2`
  - Seurat RDS 读取
  - `zellkonverter` / MTX 导出
  - Quarto 报告渲染

## Python 环境

CellOracle 安装在独立 conda 环境 `celloracle_env`（Python 3.12，基于 **Miniforge**）：

- 使用 Miniforge 而非 Miniconda，避免 Docker 非交互构建时 `CondaToSNonInteractiveError`
- **Dockerfile 拆分为多个 RUN 层**（Miniforge → 建 env → gimmemotifs → 基础栈 → scanpy → celloracle），平台超时重试时可复用已完成层
- 使用 `mamba` 加速依赖求解与安装
- `gimmemotifs`、`louvain` 经 **bioconda/conda-forge** 预编译安装
- `celloracle==0.18.0` 经 `pip install --no-deps` 安装（避免 pip 再次源码编译 gimmemotifs）
- Quarto 通过 `QUARTO_PYTHON=/opt/miniconda/envs/celloracle_env/bin/python3` 调用该环境

### Dockerfile 分层（便于超时重试）

| 层 | 内容 |
|----|------|
| A | apt 系统依赖 |
| B | Miniforge 安装与 channel 配置 |
| C | `mamba create` python=3.12 环境 |
| D | gimmemotifs（bioconda，最耗时） |
| E | louvain / cython / numpy / numba |
| F | scipy / pandas / matplotlib 等 |
| G | scanpy / anndata / umap-learn 等 |
| H | pip celloracle --no-deps |
| I | R zellkonverter |
| J | 导入验证 |

## 主要 Python 包

- celloracle（conda env）
- scanpy（celloracle 依赖）
- gimmemotifs / louvain（conda 预编译）

## 关联 Galaxy 工具

- `scRNA_VirtualKnockout_CellOracle`
- `scRNA_VirtualOverexpression_CellOracle`

共享库路径：`TOOL-k8s/singlecell/_celloracle_shared/`

## 构建与推送

```bash
cd TOOL-Dockerfile/singlecell/scRNA-perturbation-oracle
docker build -t quay.io/1733295510/scrna-perturbation-oracle:V1.0.0 .
docker push quay.io/1733295510/scrna-perturbation-oracle:V1.0.0

docker tag quay.io/1733295510/scrna-perturbation-oracle:V1.0.0 \
  genaibase-cn-beijing.cr.volces.com/genaibase/scrna-perturbation-oracle:v1
docker push genaibase-cn-beijing.cr.volces.com/genaibase/scrna-perturbation-oracle:v1
```

## 注意事项

- 首次运行会下载 CellOracle Base GRN，需网络与足够磁盘缓存。
- 建议输入 RDS 含 UMAP（或其它降维坐标）；若无则工具内自动计算 UMAP。
- 大规模数据建议设置 `max_cells` 下采样。
