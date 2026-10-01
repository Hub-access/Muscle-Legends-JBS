# 力量传奇 JBS

《Muscle Legends / 力量传奇》的 Blank-Hub 脚本可读源码整理版，包含重建变量名、中文注释和验证记录。

## 查看源码

- [Muscle-Legends.luau](./Muscle-Legends.luau)：完整 Luau 源码。
- [变量说明](./变量说明.txt)：主要变量和函数的中文用途索引。
- [变量命名映射](./变量命名映射.json)：旧名、新名、行号和命名依据。
- [验证说明](./验证说明.txt)及 [verification.json](./verification.json)：验证结果和已知限制。

用 VS Code 打开本仓库即可阅读和编辑；仓库已包含 `.luau` 文件的 Lua 语法显示设置。

## 当前状态

- 已解码的 176 个函数原型均已输出为原生 Luau，无未翻译代码块或虚拟机分派回退。
- 本轮重命名 1,158 个局部绑定，新增 57 处注释块；其中 265 个绑定仍使用中性技术名称。
- 官方 Luau 0.740 编译检查通过。
- 改名后的局部绑定规范化语法树与 v3 一致；全局引用名称和数量不变。
- 两组有界离线模型与原混淆脚本的规范化行为轨迹相同：27,554 行、23,939 行。
- **尚未把这份本地源码加载到真实游戏中，不能声称游戏功能实测通过。**

变量名和中文注释是依据代码重建的说明，不是作者原稿；函数转换覆盖率也不是原文相似度或全部行为覆盖率。离线模型中双方共有的错误保留在对照中。

## 已知代码疑点

- `unresolvedAuraNameLookup` 只返回 `nil`，仍被用于光环名称格式化。
- `checkBossPresence` 的一个分支包含 `flag or true`，不等价于严格的存活检查。

上述逻辑均原样保留并添加说明，没有通过猜测修复。外部 WindUI 库仍使用原脚本的 latest 发布地址，其实际在线兼容性尚未验证。

## 来源

原加载器与载荷来自 [blankdevs-hub/BlankScript](https://github.com/blankdevs-hub/BlankScript)。

- [原 Blank-Hub 加载器](https://raw.githubusercontent.com/blankdevs-hub/BlankScript/refs/heads/main/Blank-Hub)
- [原 Muscle Legends 载荷](https://raw.githubusercontent.com/blankdevs-hub/BlankScript/refs/heads/main/Script/Muscle%20Legends)

保留原脚本中的作者署名和界面文字。“力量传奇 JBS”是本整理仓库的标题，不表示原脚本由本仓库原创。上游地址内容可能变化，处理版本由下列摘要固定。

原混淆载荷 SHA-256：
`bd8d9614f8a85e067dff0f77d31d3834b8aa1ac08e461c988544d5f028c01168`

当前注释源码 SHA-256：
`665b71a6b8183ece0174647fc6431ce8d73e69ff94b1c1d3a91edbaed7f89858`
