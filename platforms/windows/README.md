# Windows 平台入口

## 使用

双击或在 PowerShell 中运行：

```powershell
.\启动千里马计划.ps1
```

这会自动生成工作区索引并校验骨架完整性。

## 脚本结构

| 文件 | 用途 | 可独立运行 |
|------|------|:----------:|
| `启动千里马计划.ps1` | 用户入口，保证 `-ExecutionPolicy Bypass` | ✅ |
| `start-qianlima.ps1` | 核心启动流程：bootstrap + validate | ✅ |

依赖的共享模块（位于 `.qianlima/scripts/`）：

| 文件 | 用途 | 可独立运行 |
|------|------|:----------:|
| `qianlima-core.ps1` | 骨架定义 + 三个函数（`Invoke-QianlimaBootstrap`、`Test-QianlimaWorkspace`、`Get-QianlimaListEntries`） | ❌ (需 dot-source) |
| `bootstrap-qianlima.ps1` | 生成索引（薄 wrapper） | ✅ |
| `validate-qianlima.ps1` | 校验骨架（薄 wrapper） | ✅ |

## 执行流程

```
启动千里马计划.ps1
  └─ powershell -ExecutionPolicy Bypass -File start-qianlima.ps1
        ├─ . qianlima-core.ps1                    (dot-source,同进程)
        ├─ Invoke-QianlimaBootstrap               (生成 WORKSPACE_INDEX.md + workspace-index.json)
        └─ Test-QianlimaWorkspace                 (校验 13 目录 + 12 治理文件 + 2 索引)
```

**设计要点**：
- 骨架定义（`$QianlimaFixedDirs` / `$QianlimaGovernanceFiles`）在 `qianlima-core.ps1` 唯一定义，bootstrap 和 validate 复用同一份。
- `start-qianlima.ps1` 用 dot-source 加载核心、同进程调函数，避免为每一步另开 `powershell` 子进程。
- 典型启动时间 **~1.9 秒**（测试环境：Windows 11，SSD）。进程层级：2 层（用户入口 → start）。

## 跳过校验

```powershell
.\start-qianlima.ps1 -SkipValidation
```

仅生成索引，不检查骨架（节省约 0.02 秒）。

## 单独运行 bootstrap 或 validate

```powershell
# 只生成索引
powershell -ExecutionPolicy Bypass -File .qianlima\scripts\bootstrap-qianlima.ps1

# 只校验骨架
powershell -ExecutionPolicy Bypass -File .qianlima\scripts\validate-qianlima.ps1
```

## 编辑注意事项

四个脚本均存为 **UTF-8 with BOM**（Windows PowerShell 5.1 要求中文字面量必须带 BOM，否则按系统 ANSI 编码解析会报错）。编辑后请保持 BOM：

```powershell
$content = Get-Content -LiteralPath <file> -Raw -Encoding UTF8
Set-Content -LiteralPath <file> -Value $content -Encoding UTF8
```

PowerShell 5.1 的 `-Encoding UTF8` 默认写入 BOM。
