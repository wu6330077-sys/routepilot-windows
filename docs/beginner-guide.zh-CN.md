# RoutePilot 中文新手指南

这份指南假设你没有接触过 PAC、Windows 服务或策略路由。

## 开始前需要准备什么？

RoutePilot 负责分流，但不会凭空产生两条网络线路。请先准备并启动：

1. 一个走住宅或可信出口的本地 HTTP 代理；
2. 一个走高速 VPS 出口的本地 HTTP 代理。

代理软件和端口不必与示例完全相同，向导会询问实际端口。

## 第一步：下载项目

你可以使用 Git 克隆，也可以在 GitHub 仓库点击 **Code → Download ZIP**，下载并解压。

打开解压后的 RoutePilot 文件夹即可。如果 Windows 提示脚本来自互联网或阻止运行，再点击资源管理器顶部的地址栏，输入 `powershell` 并回车，然后运行：

```powershell
Get-ChildItem -Recurse -File | Unblock-File
```

## 第二步：双击启动新手向导

直接双击项目根目录的：

```text
Start-Setup.cmd
```

它会自动从正确目录启动 PowerShell，并在结束时保留窗口，方便你阅读结果。

如果双击脚本被安全软件拦截，也可以在项目文件夹中手动运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Setup-RoutePilot.ps1
```

默认端口是：

- 住宅或可信 HTTP 代理：`127.0.0.1:10809`
- 高速 VPS HTTP 代理：`127.0.0.1:10818`

端口正确时直接回车；不同时输入自己的端口。向导会生成 `config/routepilot.local.json`，该文件已被 Git 忽略，不会上传。

## 第三步：查看端口检查

两个端口都显示 `READY / 正常` 才能继续。如果出现 `NOT READY / 未监听`，向导不会修改 Edge。请先启动或修复对应代理，再重新运行向导。

两个端口必须提供 **HTTP 代理**。如果端口只提供 SOCKS，PAC 中的 `PROXY` 指令无法使用它。

## 第四步：安装 Edge 分流

两个端口正常后，在“是否安装 Edge 分流策略”处输入 `Y`。向导结束后关闭所有 Edge 窗口，再重新打开 Edge。

Edge 可能显示“由你的组织管理”。这是因为 RoutePilot 使用了当前用户的本机 Edge 策略，不代表电脑加入了外部组织。

## 向导修改了什么？

- 在被 Git 忽略的运行目录生成 PAC；
- 在被 Git 忽略的状态目录备份原 Edge `ProxySettings`；
- 给当前 Windows 用户安装内嵌 PAC 的 Edge 策略。

向导不会切换代理软件中的活动节点，不会开启 TUN，不会重启代理，也不会上传本地配置。

## 一键恢复原设置

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Restore-EdgeRouting.ps1
```

恢复后重启 Edge。

## 常见问题

### 端口显示未监听

可以单独检查：

```powershell
Test-NetConnection 127.0.0.1 -Port 10809
Test-NetConnection 127.0.0.1 -Port 10818
```

看到 `TcpTestSucceeded : True` 才表示端口正常。

### 我只有一条代理线路

RoutePilot 不能凭空创建第二条远程线路。请先准备一台你有权使用的 VPS 代理。如果已经拥有 Hysteria 2 服务端，可以按照 [手动部署指南](manual-install.md) 把 Windows 客户端托管为后台服务。

### 端口填错了

重新运行向导即可。替换旧配置前，向导会先询问，并自动保存备份。

### Edge 中受保护网站突然打不开

通常是住宅/可信代理没有运行。受保护域名会按设计安全失败，不会偷偷改走其他出口。启动主代理，或者运行回滚脚本恢复原 Edge 策略。
