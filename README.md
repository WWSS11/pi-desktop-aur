# pi-desktop-aur

[PI-Desktop](https://github.com/vastsa/PI-Desktop)（本地优先的 AI 编码 Agent 桌面端）的 Arch Linux 打包仓库。

**维护者**：WWSS11 <3244364961@qq.com>

## 关于（About）

**PI-Desktop** 是一个本地优先的 AI 编码 Agent 桌面客户端：Electron 前端 + Rust `host-core` 宿主内核 + pi Agent Harness，支持导入 Claude Code / Codex / OpenCode / Pi 等 Agent 的会话、可安装插件、MCP/Skills 管理、Git worktree、远程主机与定时任务。由 [vastsa/PI-Desktop](https://github.com/vastsa/PI-Desktop) 开发，LGPL-3.0 许可。

**pi-desktop-aur** 是其 Arch Linux 打包仓库，提供两种安装方式：

| 包 | 类型 | 特点 |
|---|---|---|
| `pi-desktop-bin` | 预编译 | 云端自动构建，即装即用，`pacman -Syu` 自动更新 |
| `pi-desktop-git` | 源码构建 | 本地编译，跟随上游 `main` 最新提交 |

> 本项目**不需要 AUR 账号**：包发布在自建的 pacman 仓库上，因此本仓库既是打包脚本仓库，也是包源本身。

## 安装方式

### 方式 1：自定义 pacman 仓库（推荐，自动更新）

在 `/etc/pacman.conf` 末尾添加：

```
[pi-desktop-aur]
Server = https://github.com/WWSS11/pi-desktop-aur/releases/latest/download
Server = https://wwss11.github.io/pi-desktop-aur/$arch
SigLevel = PackageOptional
```

然后执行：

```bash
sudo pacman -Syu
sudo pacman -S pi-desktop-bin
```

之后上游有新提交时，仓库会自动重新构建，`sudo pacman -Syu` 即可升级。

> 说明：
> - 仓库数据库（`pi-desktop-aur.db`）与包都放在 GitHub Release 上，`releases/latest/download` 始终指向最新一次构建，因此数据库与包永远一致。
> - 第二行是 `gh-pages` 上的数据库镜像（只有数据库，没有包），作为备用源。
> - 本仓库为未签名仓库（`SigLevel = PackageOptional`），经 HTTPS 分发。所有包均由上游 LGPL-3.0 源码构建，非官方仓库，使用风险自负。

### 方式 2：预编译包直接安装

从 [Releases](https://github.com/WWSS11/pi-desktop-aur/releases) 页面下载对应的 `pi-desktop-bin-*.pkg.tar.zst` 后：

```bash
sudo pacman -U pi-desktop-bin-*.pkg.tar.zst
```

所有历史版本都保留在 Releases 页面。

### 方式 3：源码构建（跟随上游 main 最新提交）

```bash
git clone https://github.com/WWSS11/pi-desktop-aur.git
cd pi-desktop-aur/pi-desktop-git
makepkg -si
```

需要 Node.js >= 22.19（提供 `node`/`npm`），其余依赖由 `makedepends` 声明。首次编译约 20-40 分钟（Rust + 前端 + Electron 打包），之后增量编译很快。

## 自动化说明

- 本仓库通过 [GitHub Actions](https://github.com/WWSS11/pi-desktop-aur/actions) 每 6 小时检查上游 `main` 更新
- 检测到新提交时，自动在云端 Arch 容器中编译并发布：
  1. 编译 `pi-desktop-git`（`electron-vite build` + `electron-builder --linux dir`）
  2. 用该产物重新打包 `pi-desktop-bin`，同步更新其 PKGBUILD 版本号与校验和
  3. 校验包内布局（`scripts/verify-package.sh`），不合格直接中断，不会发布
  4. 先创建草稿 Release 并上传全部产物（两个包 + 仓库数据库）
  5. 全部就绪后再发布 Release，并更新 `gh-pages` 的数据库镜像
- 另有 `verify` 工作流（每周 + 手动触发）会按用户实际的 `Server` URL 下载数据库与包，校验校验和与包内布局，并比对 `gh-pages` 镜像
- 手动触发：仓库 Actions 页 → build → Run workflow（可勾选 `force` 强制重建）

> 上游 `main` 是滚动目标。如果它自身处于不可构建状态（例如 `pnpm-lock.yaml` 与工作区的 `package.json` 不一致），构建会失败并且**不会发布任何包**，下一次计划任务会自动重试；已发布的历史版本不受影响。

## 包说明

- `pi-desktop-bin` 与 `pi-desktop-git` 互斥（`conflicts`），同一台机器只能装其一
- `pi-desktop-bin` 是 `pi-desktop-git` 的预编译产物，内容一致
- 应用安装在 `/opt/PI-Desktop`，启动器为 `/usr/bin/pi-desktop`
- 许可证：LGPL-3.0（随包附带 LICENSE）

## 与上游发行版的区别

上游提供的 AppImage / deb / rpm 自带整套 Electron 运行时。本仓库的包同样捆绑 Electron（这是 Electron 应用的标准做法），但在 Arch 容器内编译 `host-core` 与前端，并按 Arch 的目录规范安装（`/opt/PI-Desktop` + `/usr/share/applications` + hicolor 图标），因此能直接被 `pacman` 跟踪、升级和卸载。

## 维护备忘

- 包体积约 100 MB，超过 GitHub 单文件 100 MiB 的 git push 限制，所以包体只放在 Release，`gh-pages` 只放数据库与 `.last-built-sha` 标记。
- 构建在 `archlinux/archlinux:latest` 容器中进行；容器内使用官方 Node.js 24（Arch 只提供 Node 26）。
- 上游 `package.json` 的 `packageManager` 字段决定 pnpm 版本，`prepare()` 会在 `$srcdir` 内安装该版本，保证与上游 lockfile 一致。
