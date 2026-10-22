# API 契约工作区（0.3.0）

本库面向 SDK、服务边界、契约编辑器和 CI 的**离线、可复现契约生命周期**。`contracts` 是可独立导入的 MoonBit 包，原 URI 根包维持兼容。下面是可验收的实现范围，不是完整 OpenAPI 实现或生态唯一性声明。

## 生态分工与独立贡献

2026-10-22 第一方文档对比：Magic486 的 [moon-uri-template](https://github.com/Magic486/moon-uri-template) 已提供 RFC 6570 Level 4，不再把本项目同类展开能力作为新增价值。API 校验、兼容性 diff 和回归也已有近邻：

| 参考项目 | 公开定位，不是本项目执行的性能结论 | 本项目分工 |
| --- | --- | --- |
| [mooncontract](https://mooncakes.io/docs/Han-Wentao/mooncontract) 0.1.1 | OpenAPI 3.0、HTTP 交互校验、Mock、回放 | 不重复服务器/Mock/路由/YAML；管理离线 Schema 修订和操作依赖 |
| [moonapi_check](https://mooncakes.io/docs/WeiR-h/moonapi_check) 0.1.1 | OAS 3.0.3 请求兼容性与影响定位 | 不以 diff 单独立项；提供更新事务、候选快照和升级门禁 |
| [moon_contractguard](https://mooncakes.io/docs/yyqdbngt/moon_contractguard) 0.2.0 | 请求/响应 Schema 变化与 review | 不宣称首次双向分析；结合显式审批、旧基线和定向候选执行 |
| [bzhangui/moonapi](https://mooncakes.io/docs/bzhangui/moonapi) 0.3.0 | 状态行为回归与缩减 | 不模拟业务状态；提供依赖感知工作区 |
| [moonschema](https://mooncakes.io/docs/moonbitstack/moonschema) 0.2.0 | 多 draft JSON Schema 解释验证 | 直接复用，不冒称原创验证器或将上游 suite 成绩当本项目实测 |

独立贡献组合：**持有离线锁 → 跨文档传递依赖 → 原子更新 → 受影响操作重建 → 保守变化审阅 → 基线与正向覆盖约束 → 定向候选重放 → JSON 决策**。不是在 URI 展开函数外加几条参数规则。此比较不证明未发布/私有项目无类似功能；独立立项仍由赛事方判断。

## 入口和数据

```text
import { "JSJ222/moonuritemplate/contracts" @contracts, }
```

`compile_workspace(Json, limits?)` 接受显式格式；`compile_workspace_text(String, limits?)` 还拒绝重复 JSON 键：

```json
{
  "documents": {"id": {"type": "string", "minLength": 1}},
  "operations": [{
    "operationId": "getUser", "method": "GET", "path": "/users/{id}",
    "parameters": [{"name": "id", "in": "path", "required": true, "schema": {"$ref": "id"}}],
    "responses": {"200": {"content": {"application/json": {"schema": {"type": "object"}}}}}
  }]
}
```

`shared#/properties/id` 只访问显式提供的 shared 文档，不联网/读盘。支持对象及数组 JSON Pointer，含 `~0`/`~1`、无前导零数组索引；不实现 URI 百分号解码、相对 URI 基址或锚点。文档名是精确、非空、无 `#` 的资源 ID；坏引用报错。

`manifest()` 深复制可复建锁；`resolved_operation(name)` 返回复制的解析结果。操作 ID 和 method/path 不重复；path 声明对应简单 `{name}`。按 operationId 校验，不执行反向路由。空工作区是合法中间态，不是有意义的独立项目。

## 支持 profile 和明确不做的范围

| 范围 | 行为 / 限制 |
| --- | --- |
| OAS 接入 | `import_openapi(document, document_id, documents?, limits?)` 接受 3.1.0/3.1.1/3.1.2 JSON 支持字段：paths 操作、参数、请求/响应 body、headers、components/schemas。操作参数覆盖同 `(in,name)` 的路径级参数；不是整个规范 lint |
| 方言 | 本 profile 按 Draft 2020-12 解释；显式 `$schema` / `jsonSchemaDialect` 仅接受 `https://json-schema.org/draft/2020-12/schema`，不支持其他自定义词汇 |
| 约束 | 类型和 nullable type 数组、enum/const、数值区间/multipleOf、字符串长度/pattern、对象/数组规则、组合条件和 unevaluated 族由 moonschema 解释。定义层检查断言类型、合法取值和正则；只在真实 schema 位置解析 `$ref`，未知非扩展关键字拒绝；enum 最多 1024 项、长度/计数断言限非负 Int32 |
| 引用缺口 | `$id` 重定位、anchors/dynamic/recursive refs 和循环拒绝；合法递归 Schema 也不在支持范围 |
| OAS 缺口 | YAML、Reference Object 参数/响应/pathItem、security、webhooks、callbacks、links、非 JSON 内容、参数 content/style/explode 显式字段拒绝；components 限 schemas。info/servers/tags/externalDocs 是非执行性元数据，不构造/授权请求 |
| 类型化参数 | Path/Query/Header/Cookie 的解码后 Json 值；检查必填、重复、未知和 Schema，header 大小写归一。SDK 精确对象采用拒绝未知策略，不可直接传入全部真实 HTTP headers |
| 线格式 | 不拆解 query 多值/cookie，不作 percent decode、style/explode/deepObject、强制类型转换或默认值注入；宿主负责解码。`request_path` 只构造非 null 标量 path，不序列化 query |
| 请求体 | None 是缺席，Some(Null) 是 JSON null；required 决定缺席是否合法。只匹配 exact JSON / `+json` 媒体类型，无通配匹配 |
| 响应 | exact → class（如 2XX）→ default；声明头校验、未知头允许、大小写归一后的重复拒绝。有 JSON content 的普通响应须有 body；1xx/204/304/HEAD 禁止 body；无 content 的额外 body 判非法 |
| 错误 | WorkspaceError 的 Invalid / Unsupported / Budget；交互不符合返回 Violation，含操作、位置、instance/schema pointer 和 code，不回显值；不能忽略错误当作有效 |
| 数值/字符 | 有限 IEEE-754 且绝对值 ≤ 2^53−1，不承诺任意精度；拒绝未配对 UTF-16。format 是注释，不作断言；上游字符/正则语义限制仍适用 |
| 所有权/并发 | 捕获文档/修订时深复制，公开容器返回复制；快照定义不变。上游有内部状态，**同一工作区及共享旧操作必须串行校验**；并发需要宿主隔离 |

OAS 导入只把主文档 components/schemas 投影为独立锁，组件引用改为显式资源 ID，不改 const/enum/example 中形似 `$ref` 的数据。内联 schema 捕获于操作定义。**改路径、required、状态等操作声明必须重新导入，再 compare/gate；update_documents 只处理 schema 锁，不是整个 OAS 文本热重载。**

## 生命周期和升级政策

1. `operations_using(document)` 返回包含传递引用的操作，按工作区顺序。
2. `update_documents(changes)` 接受替换或移除；重复补丁拒绝，相同内容不增加 revision。旧反向图选出受影响操作，重解引用，生成新的依赖图。改向后下一轮用新图；未被旧操作引用的新资源不可能单独改变其行为。
3. 全部成功才返回 `WorkspaceUpdate.workspace()`；坏引用、循环、预算失败不改旧锁和索引。changed_documents / rebuilt_operations 统计实际工作；上游是解释器，不宣称生成验证代码。
4. `compare(candidate)` 对删除操作、method/path 变化、新增必填参数/请求体判 breaking；任意 resolved 约束差异判 review；新增操作 additive。顺序/注释变化也可能保守 review，不求解任意 Schema 接受集合包含关系。
5. `gate_upgrade(candidate,cases,approve_review=false)` 要求相同限制策略；执行当前操作全部旧基线。已有消费者预期失败拒绝；新操作无旧基线但须候选正向覆盖；两个版本都无此操作是用例配置错误。
6. 候选只重放变化操作的用例，未变化者复用基线；每个变化操作至少有一个正向且候选有效的样例。breaking、未批准 review、缺覆盖、任一候选预期不符都拒绝；仅通过后 approved_workspace 才返回候选。
7. `to_json()` 导出决策、变化、计数和用例结果，宿主决定 CI 退出码、持久化和回滚。**显式 review 批准是政策豁免，有限样例不是全体消费者兼容性证明。**

## 三个完整场景

1. **SDK / 服务边界**：运行 `moon run examples/contract_sdk --target wasm-gc`。库存 OpenAPI → SKU 预检 → team/a 编为 team%2Fa → 正常响应通过、负库存/缺路径参数拒绝。宿主在真实 HTTP 前后复用，不需要本库另建 Web 框架。
2. **共享 DTO 演进**：运行 `moon run examples/contract_workspace --target wasm-gc`。orders/users 共用 DTO，DTO 引用 identity；提高长度重建 2/3 操作、health 复用，旧快照仍有效，新快照拒绝旧短值，坏引用回滚，并逐操作对照冷启动。
3. **CI / 编辑器门禁**：运行 `moon run examples/contract_ci --target wasm-gc`。SDK/health 消费者 → schema 变化分类 → 缺审阅阻断 → 样例回归即使审批也阻断 → 获批且样例通过后仅对 save 候选重放，输出 JSON 决策。宿主须检查 accepted，不以无异常等同放行。

这些是可执行、有断言的合成集成场景，不是企业用户采用记录。

## 量化验证

2026-10-22，Windows 10 x64（10.0.19045），Intel64 Family 6 Model 165，moonc v0.10.16+b1a0e846e，native release。毫秒墙钟、12 次/组，P95 用向上取整次序统计；小样本，不作跨硬件保证。

| 操作 / 每轮变化 | 冷编译 P50/P95 ms | 增量准备 P50/P95 ms | gate P50/P95 ms | 重建 / 候选重放 |
| --- | --- | --- | --- | --- |
| 200 / 1 | 4 / 6 | 1 / 2 | 2 / 3 | 1 / 1 |
| 1000 / 10 | 28 / 32 | 10 / 13 | 12 / 14 | 10 / 10 |
| 1000 / 1000 | 28 / 30 | 29 / 33 | 21 / 26 | 1000 / 1000 |

复现 `moon run benchmarks/contract_management --target native --release`。三组每轮都比较候选/冷启动 resolved 操作和全量消费者结果、诊断，共 **26,400 个操作版本及回归结果比较**。不是 26,400 个独立规范样例。另有 24 轮修订测试、依赖改向、无关文档和失败回滚。

冷编译计时从预备 manifest 开始；增量含完整锁扫描和选择性准备；gate 另计时，**每次仍执行 200/1000 个旧基线**。不能把候选重放减少比例当作全部验证提速。全量变化增量略慢，应考虑冷编译；未测峰值 RSS，不承诺内存收益。

独立参考：安装 `jsonschema==4.26.0`，运行 `python tools/compare_contract_oracle.py`。13 类 Schema × 27 个 Json 值由 MoonBit 请求体验证，Python Draft202012Validator 分别独立验证，**351/351 一致**。覆盖类型、区间、nullable、pattern、对象/数组、组合、依赖、contains、unevaluated。这是支持 profile 的原创新数据，不是完整 OAS/Schema conformance；引用生命周期另有公共接口测试。

## 算法、限制及维护

设锁树大小 N、操作数 O、展开 schema 总大小 R、操作—文档依赖边 E、受影响集 A、参数数 P、解释验证成本 V：

- 冷编译复制锁并排序对象键，有 Σ k log k 项；逐操作准备 O(R)、索引 O(E)，空间 O(N+R+E)。共享 schema 可能被多操作分别展开，R 可大于原树；resolved_nodes 是每操作预算，不是进程总内存上限。
- 更新仍约 O(N+O+E+ΣR_A)，含排序成本；不是 O(变更字节)。复用未变化操作有利于小改动，但需全锁扫描、Map 复制和反向图重建，持有旧快照也有内存代价。
- compare 扫描操作和 resolved 树；简单参数匹配最坏 Σ(P_old×P_new)。多数操作参数少，暂不增索引；若实际成为瓶颈，可用 `(in,name)` 哈希表降至线性，代价为索引内存，这不是已实现优化。
- gate 包括 ΣV_old、变化比较、ΣV_A，不宣称只验证变化用例或跨 gate 缓存基线。
- JSON 深度/节点/文本、文档/操作/用例、解析节点/返回诊断均有预算；输入构造发生在宿主，预算不控制此前分配。数值、UTF-16、重复 ID、引用环要报错。
- 上游正则、uniqueItems、组合可能昂贵；faults 急切分配，findings 只限制返回，不限制上游峰值。对于不可信契约/实例，宿主需进程隔离、超时和配额，预算不是硬 CPU 保证。
- 定义检查中的 enum 去重最坏为二次比较，限制 1024 项；诊断不输出完整实例，但自定义用例名、Schema 名和实例 JSON Pointer 可能包含敏感标识，记录日志前仍须宿主脱敏。

验证使用 check/build/test 的 `--target all --deny-warn`、fmt --check、info，以及上述对照/场景。Windows 受扩展路径问题影响时，用 `pwsh -NoProfile -File tools/windows/moon.ps1` 替代 moon。CI 覆盖全部核心检查和新增场景。未来优先独立参照、真实集成和边界修复，不以空提交/改名制造工作量。许可见 [THIRD_PARTY](../THIRD_PARTY.md)。
