# JBS R9i：快速锻炼优化与60秒对照

[完整脚本](./JBS-Fast-R9i.lua) · [实测报告](./BENCHMARK.md) · [完整资料ZIP](./JBS-R9i-and-Benchmark.zip?raw=true) · [数据表](./data/measurements.csv)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Hub-access/Muscle-Legends-JBS/main/releases/JBS-R9i-2026-10-20/JBS-Fast-R9i.lua"))()
```

从干净游戏会话加载，进入面板后开启“快速锻炼”。仅此功能改为原生Pushups训练，停用恢复原工具，帧率不降低；其余功能代码保持一致。需要账号已拥有Pushups；原生条件不可用时保留原R7回退路径。


本轮 JBS 全程快 **1.47%**，后30秒持续速度快 **2.28%**，网络 Data Ping 中位数降低 **97.94%**。这是本轮测量，不是跨设备或长期稳定性保证。

| 指标 | JBS R9i | 第二脚本25档 |
|---|---:|---:|
| 60秒平均速度（亿力量/秒） | 14.5010 | 14.2911 |
| 后30秒持续速度（亿/秒） | 12.7503 | 12.4656 |
| 后15秒持续速度（亿/秒） | 12.6885 | 12.4715 |
| 网络Data Ping中位数（ms） | 316.27 | 15320.81 |
| 网络Data Ping P95（ms） | 450.60 | 36409.01 |
| 网络Data Ping最大值（ms） | 474.71 | 38201.51 |
| 实际FPS | 112.99 | 111.57 |
| 关闭后观察到稳定所需时间（秒） | 4.03 | 248.05 |

JBS实际开启60.003198秒，参考实际开启60.005299秒。速度使用游戏实际力量增长，未把发送次数当成成功锻炼次数。


Mac＋Opiumware实测；安卓Delta未验证。各一次60秒，结果只适用于本轮环境。完整方法与限制见[报告](./BENCHMARK.md)。
