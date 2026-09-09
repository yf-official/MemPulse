# MemPulse

[English](README.md) | [简体中文](README.zh-CN.md)

[下载 macOS 版](https://github.com/yf-official/MemPulse/releases/latest) · [全部版本](https://github.com/yf-official/MemPulse/releases)

**Monitor. Detect. Release.**

MemPulse 是一款轻量、原生的 macOS 内存监控应用。它同时提供紧凑的菜单栏状态项和完整应用窗口，重点展示真正有诊断价值的 Memory Pressure、压缩内存、交换空间、高内存进程与进程持续增长。

MemPulse 不把正常文件缓存包装成“垃圾内存”，不通过制造内存压力让数字暂时变小，核心功能也不需要高权限。

## 预览

![使用演示数据的 MemPulse 内存概览](docs/images/mempulse-overview.png)

| 菜单栏弹窗 | 进程列表 |
|---|---|
| ![使用演示数据的 MemPulse 菜单栏弹窗](docs/images/mempulse-menu-popover.png) | ![使用演示数据的 MemPulse 进程列表](docs/images/mempulse-processes.png) |

截图中的进程名称和内存数值均为演示数据，不包含用户 Mac 上的真实信息。

## 功能

- 菜单栏固定 28 pt 内容画布，使用 10 pt 双行居中显示 `80% / RAM`
- 原生应用窗口：概览、进程、增长检测、设置、关于
- 关闭主窗口后隐藏 Dock 图标，菜单栏和监控继续运行
- Physical、Used、Available、App、Wired、Compressed、Cached、Purgeable、Swap
- 直接读取 macOS normal / warning / critical Memory Pressure
- 按 physical footprint 排序的 Top 5 与完整进程列表
- 最近 10 分钟内存历史与 5 分钟持续增长判断
- 内存增长、Memory Pressure、RAM 百分比阈值通知
- RAM 阈值可在 70%～95% 之间选择，建议 85%
- Smart Release 只发送普通应用正常退出请求
- English、简体中文、跟随系统三种语言
- 使用 `SMAppService` 登录时启动
- 一键打开活动监视器

## 系统要求

- macOS 13.0 或更高版本
- Apple Silicon 或 Intel Mac
- 监控和 Smart Release 不需要管理员、辅助功能或完全磁盘访问权限

## 安装与运行

1. 打开[最新发布页面](https://github.com/yf-official/MemPulse/releases/latest)，从 Assets 下载 **MemPulse-1.0.0-universal.zip**。
2. 解压 ZIP，将 **MemPulse.app** 移到“应用程序”目录。
3. 打开 MemPulse。同一个安装包兼容 Apple Silicon 和 Intel Mac。

[直接下载 1.0.0 版](https://github.com/yf-official/MemPulse/releases/download/v1.0.0/MemPulse-1.0.0-universal.zip)

当前版本使用 ad-hoc 签名，尚未通过 Apple 公证，macOS 可能阻止直接打开下载的应用。也可以按照下方说明使用 Xcode 自行构建。克隆仓库的用户还可以在 `dist/MemPulse.app` 找到应用副本。

## 构建

在 Xcode 中打开 `MemPulse.xcodeproj` 并运行 MemPulse scheme，或使用终端：

```bash
xcodebuild -project MemPulse.xcodeproj \
  -scheme MemPulse \
  -configuration Release \
  -derivedDataPath build/release \
  ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  build
```

也可以使用 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 从 `project.yml` 重新生成已纳入仓库的 Xcode 工程。

运行测试：

```bash
xcodebuild -project MemPulse.xcodeproj \
  -scheme MemPulse \
  -configuration Debug \
  -derivedDataPath build/tests \
  test
```

## RAM 计算

MemPulse 使用运行时 Mach page size 和 `host_statistics64(HOST_VM_INFO64)`：

```text
Cached Files ≈ (external pages + purgeable pages) × page size
Available    = min(Physical, Free + Cached Files)
Memory Used = Physical − Available
RAM %       = Memory Used ÷ Physical × 100
```

在 Apple Silicon 上，GPU 与系统保留页不一定完整落入 App、Wired、Compressed 三项；使用物理内存残差更接近活动监视器标题中的“已使用内存”。RAM 百分比只作为概览与可选提醒信号，状态颜色和风险判断优先使用 macOS Memory Pressure。

## Smart Release

Smart Release 不是 RAM Cleaner：

- 候选来自当前用户的普通 GUI 应用。
- 排除前台 App、MemPulse、Finder、系统服务和受保护进程。
- 默认不勾选，用户逐项选择。
- 仅调用 `NSRunningApplication.terminate()`；应用可以提示保存、拒绝或延迟退出。
- 不使用 Force Quit、`purge`、sudo、root helper、私有 API 或“先占满再释放”。
- “预计可释放”来自所选进程当前 physical footprint，系统实测结果可能不同。

## 后台运行与退出

- 关闭主窗口或按 `Command-W`：隐藏 Dock 图标，菜单栏和监控继续运行。
- 从菜单栏弹窗选择“打开 MemPulse”：恢复 Dock 图标和主窗口。
- 从弹窗选择“退出”，或从应用菜单选择“退出 MemPulse”：停止监控并结束程序。

## 性能与数据生命周期

- 系统内存默认每 2 秒采样，进程默认每 5 秒扫描，均在 utility 串行队列执行。
- 增长历史只存在内存中，仅保留 10 分钟，并限制为最多 60 个进程。
- 离开跟踪集合的进程会立即移除，不向磁盘写入历史。
- 菜单栏百分比和压力状态不变时不会重复生成图像。
- 采样与增长历史均设有明确上限，以保证长期运行时的资源占用可预测。

## 隐私

MemPulse 完全本地运行且不发起网络请求。它不会上传内存数据、进程名、Bundle ID 或系统信息，也不包含分析、广告、遥测或追踪 SDK。
