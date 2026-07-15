# macOS 适配

千里马运行时使用 PowerShell 7。macOS 不需要重写 YAML 或 workflow，只需安装跨平台的 `pwsh`。

## 安装

```bash
cd "/path/to/qianlima"
bash scripts/install-powershell-macos.sh
```

上面的命令只显示将要执行的安装步骤，不会下载任何软件。确认后执行：

```bash
bash scripts/install-powershell-macos.sh --install
```

脚本会在缺少 Homebrew 时调用其官方安装程序，再执行 `brew install --cask powershell`，最后验证 `pwsh --version`。安装 Homebrew 可能要求输入 macOS 管理员密码。

也可以自行安装：

```bash
brew install --cask powershell
pwsh --version
```

## 启动

```bash
cd "/path/to/qianlima"
bash start-qianlima.sh
```

高风险任务或配置变更时：

```bash
bash start-qianlima.sh -Force
```

## 边界

- `pwsh` 是唯一脚本运行时；不要维护一套独立 Bash 业务逻辑。
- `start-qianlima.sh` 不会自行安装软件；系统级下载只由显式执行的安装器完成。
- macOS 路径使用 `/`，PowerShell 脚本通过 `Join-Path` 和 `Resolve-Path` 处理路径。
- 未安装 `pwsh` 时，只能浏览项目源码，不能视为已完成启动、索引或安全校验。
