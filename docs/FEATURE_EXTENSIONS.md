# 契约工作区投影与消费者覆盖证据

## 可独立编译的操作子集

`Workspace::project_operations(selected)` 按源顺序保留指定操作及其已编译的
传递文档依赖锁，重新编译成独立 Workspace。重复操作名、未知操作和预算超限
明确失败，空投影有效；原工作区不变，新工作区修订号从零开始。

用于面向不同 SDK、服务消费者或离线工具的最小契约包，避免携带无关资源文档。
这是操作/资源级裁剪，不是授权控制；选中操作中内联的字段和文字会保留，不能
作为敏感字段清洗器。JSON manifest 可直接重新编译。
投影选择与依赖集合期望 O(N+R+S)，再加选中部分的正常编译代价和输出大小，
其中 N 是原操作数、R 是选中操作依赖总数、S 是选择数；编译预算沿用原工作区。

## 消费者样例覆盖证据

`Workspace::consumer_coverage(cases)` 复用 replay 语义，按原顺序为全部操作返回
正例通过数、负例通过数、失败数、未覆盖的响应规则。只有通过的正例且包含实际
响应，才覆盖按 exact > class > default 选中的一条状态规则；仅请求测试、拒绝负例、
失败案例不冒充响应覆盖。未覆盖规则按字符串排序，未知操作名与案例预算超限被拒绝。

用于契约测试缺口定位、SDK 消费者测试清单和升级前证据整理。报告只含操作名、
计数和状态规则，不复制请求/响应值。状态规则被覆盖不代表所有 schema 分支、
业务路径或安全条件被验证，也不等于升级审批通过。
在 replay 成本之外，计数期望 O(C+N+R)，未覆盖规则排序 O(sum R_i log R_i)，
空间 O(N+R+C)（含 replay 结果）；C 是案例数、R 是全部响应规则数。

## 验证范围

`contracts/projection_coverage_test.mbt` 检查传递依赖裁剪、独立重编译、空投影、
未知/重复操作、请求与响应覆盖的区别、负例、失败案例和报告值脱敏边界。

## 本地复现

要求 moonc >= 0.10.16。在本地源码目录执行：

```sh
moon update
python tools/verify_toolchain.py
moon check --target all --deny-warn
moon build --target all --deny-warn
moon test --target all --deny-warn
moon run examples/contract_projection --target wasm-gc --deny-warn
moon run examples/contract_projection --target native --deny-warn
```

Windows 如遇 OCaml 扩展路径问题，使用仓库提供的 `tools/windows/moon.ps1`
代替 `moon`。

以上 API 从 **0.4.0** 起提供：`moon add JSJ222/moonuritemplate@0.4.0`。
全部示例为可运行断言，不代表已有生产部署。
