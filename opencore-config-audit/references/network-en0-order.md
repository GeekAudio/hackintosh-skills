# `en0` 归属与网络接口顺序

网卡驱动或硬件变化后，记录接口编号、MAC、built-in 与联网状态。不要因为 Wi-Fi 被编号为 `en1` 就重建网络设置。

## 1. iServices 与 Wi-Fi 分别检查

[Dortania 的 iServices 指南](https://dortania.github.io/OpenCore-Post-Install/universal/iservices.html#fixing-en0) 要求检查 `en0` 是否存在且标记为 built-in；它可以是有线、Wi-Fi 或 Thunderbolt，类型不是判据。同一指南的 ROM 小节讨论网卡 MAC 转为 ROM 值的方法。

因此，有线为 `en0`、无线为 `en1` 是可用的组合。换网卡或补丁后先检查实际状态，不能把接口编号变化直接判成 iServices 或 Wi-Fi 故障。AirDrop / Handoff 的驱动能力另见 [连续互通排障](airdrop-handoff.md)。

## 2. 只读检查

```bash
networksetup -listallhardwareports      # 将 Wi-Fi / Ethernet 对应到实际 enX
ifconfig en0                           # en0 的 MAC 与状态
ioreg -l -w0 | grep -i IOBuiltin       # 结合控制器路径确认 built-in，不能只看任意一处命中
scutil --nwi                           # 当前网络状态
```

对 Wi-Fi 使用第一条命令查出的实际接口名检查 `ifconfig`，不要固定写 `en0` 或 `en1`。联网验证结合关联、IP、DHCP 与实际连接测试；仅有接口或驱动加载记录不足以证明功能正常。

## 3. 什么时候需要修复顺序

只有缺少 `en0`、built-in 不正确，或有明确的接口相关故障时，才按 Dortania 对应章节处理。已有正常 built-in `en0` 时，保留接口顺序。

重建网络设置会影响网络服务与偏好，执行前备份 `/Library/Preferences/SystemConfiguration/` 下相关文件，并准备本地访问和恢复路径。不要把删除 `NetworkInterfaces.plist`、禁用有线驱动当成修补 Wi-Fi 后的例行步骤；远程排障尤其不能先切断唯一可用连接。

## 4. ROM 与身份信息

记录 ROM 与目标网卡的关系，按 [SMBIOS 与身份信息](smbios-and-serials.md) 判断是否需要修改。接口编号改变不自动授权重写 ROM；不要为了排查 AirDrop 顺手换 ROM、UUID 或三码。MAC 与身份信息只留在用户的本地记录，不进入公开报告。

## 5. 修改网卡后的验收

- 按实际 `enX` 验证有线 / 无线的联网功能。
- 检查原本可用的 iServices 是否仍正常；异常时沿 iServices 指南逐项取证。
- AirDrop 与 Handoff 分别验证，不能以 `en0` 类型或 `awdl0` 是否存在代替完整功能测试。
