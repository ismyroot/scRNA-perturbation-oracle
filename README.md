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

CellOracle 安装在独立 conda 环境 `celloracle_env`（Python 3.12）：

- `gimmemotifs`、`louvain` 经 **bioconda/conda-forge** 预编译安装（避免 pip 在 Py3.12 下构建失败）
- `celloracle==0.18.0` 经 `pip install --no-deps` 安装（避免 pip 再次源码编译 gimmemotifs）
- Quarto 通过 `QUARTO_PYTHON=/opt/miniconda/envs/celloracle_env/bin/python3` 调用该环境

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
