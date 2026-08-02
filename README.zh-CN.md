# RoutePilot for Windows

RoutePilot 是一个面向 Windows 的本地双出口策略路由工具。它让账号、登录和控制面域名固定走可信主代理，同时仅将明确列出的媒体 CDN 与大文件下载域名送往高速代理。

项目适合已经合法拥有两个本地代理出口、希望获得可复现分流、健康检查、低权限后台服务和完整回滚能力的用户。RoutePilot 不提供代理服务器、节点凭据或第三方服务访问权限。

## 主要特性

- 受保护域名安全失败，不回落到直连或高速出口。
- 只有白名单中的媒体/CDN 域名走高速出口。
- PAC 以数据形式写入 Edge 用户级策略，不需要常驻 PAC Web 服务。
- Hysteria 2 客户端可由低权限 `LocalService` Windows 服务托管并自动拉起。
- 第三方程序只在用户主动执行时从官方 Release 下载，并校验官方 SHA-256。
- 本地配置、凭据、日志、运行状态与二进制文件全部排除在 Git 之外。
- 提供离线测试、健康检查和回滚脚本。

## 快速开始

```powershell
Copy-Item .\config\routepilot.example.json .\config\routepilot.local.json
Copy-Item .\config\hysteria-client.example.yaml .\config\hysteria-client.local.yaml
.\scripts\New-RoutePilotPac.ps1
node .\tests\Test-RoutingPac.js .\runtime\routepilot.pac .\config\routepilot.local.json
```

需要 Hysteria 2 高速出口时，先手动下载并校验官方程序：

```powershell
.\scripts\Download-Hysteria.ps1
```

随后在管理员 PowerShell 中安装低权限服务：

```powershell
.\scripts\Install-HysteriaService.ps1 `
  -HysteriaExecutable .\runtime\hysteria\hysteria-windows-amd64.exe `
  -ClientConfig .\config\hysteria-client.local.yaml `
  -DataRoot D:\RoutePilotData
```

应用 Edge 分流并检查：

```powershell
.\scripts\Install-EdgeRouting.ps1
.\scripts\Test-RoutePilotHealth.ps1
```

恢复原 Edge 策略：

```powershell
.\scripts\Restore-EdgeRouting.ps1
```

详细安全边界见 [安全模型](docs/security-model.md)。使用者应当只连接自己拥有或被授权管理的网络端点，并遵守当地法律及相关服务条款。
