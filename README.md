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

- 使用 bioconda **`gimmemotifs-minimal`**（非完整 `gimmemotifs`，避免 homer/ghostscript/meme 导致 Step 25 超时）
- 另装 `genomepy`（conda-forge）、`goatools` / `velocyto`（pip）
- 使用 Miniforge 而非 Miniconda，避免 Docker 非交互构建时 `CondaToSNonInteractiveError`
- **Dockerfile 拆分为多个 RUN 层**，平台超时重试时可复用已完成层
- 使用 `mamba` 加速依赖求解与安装
- `louvain` 经 bioconda 预编译安装
- `celloracle==0.18.0` 经 `pip install --no-deps` 安装
- Quarto 通过 `QUARTO_PYTHON=/opt/miniconda/envs/celloracle_env/bin/python3` 调用该环境

### Dockerfile 分层（便于超时重试）

| 层 | 内容 |
|----|------|
| A | apt 系统依赖 |
| B | Miniforge 安装与 channel 配置 |
| C | `mamba create` python=3.12 环境 |
| D | louvain / cython / numpy / numba |
| E | scipy / pandas / scikit-learn / joblib / tqdm |
| F | h5py / pyarrow |
| G | matplotlib-base / seaborn-base（无 Qt6） |
| H | python-igraph / umap-learn |
| I | anndata / scanpy |
| J | gimmemotifs-minimal（bioconda，轻量） |
| K | genomepy |
| L | pip goatools |
| M | pip velocyto |
| N | pip celloracle --no-deps |
| O | R zellkonverter |
| P | 导入 + Base GRN 加载验证 |

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

# V1.19（2026-07-17）：叠加 scikit-misc，修复 scanpy seurat_v3 HVG 缺 skmisc
docker build -t quay.io/1733295510/scrna-perturbation-oracle:V1.19 .
docker push quay.io/1733295510/scrna-perturbation-oracle:V1.19
docker tag quay.io/1733295510/scrna-perturbation-oracle:V1.19 \
  genaibase-cn-beijing.cr.volces.com/genaibase/scrna-perturbation-oracle:v1
docker push genaibase-cn-beijing.cr.volces.com/genaibase/scrna-perturbation-oracle:v1
```

## 注意事项

- 首次运行会下载 CellOracle Base GRN，需网络与足够磁盘缓存。
- 建议输入 RDS 含 UMAP（或其它降维坐标）；若无则工具内自动计算 UMAP。
- 大规模数据建议设置 `max_cells` 下采样。
