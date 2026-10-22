# MoonUriTemplate — API 契约工作区与变更治理基础库

从 0.3.0 开始，主能力是纯 MoonBit 的**离线 API 契约工作区**：锁定跨文档 Schema → 校验类型化请求/响应 → 原子更新文档 → 按传递依赖重建操作 → 对受影响消费者执行升级门禁。工作区可作为 SDK、Web 框架中间件、契约编辑器和 CI 的基础库，不绑定某个 HTTP 框架。原 RFC 6570 Level 4 接口保持兼容；不通过改名掩盖历史。

## 0.3.0 核心能力与三个场景

- **标准接入及双向边界校验**：支持明确限定的 OpenAPI 3.1 JSON 导入、四种位置的类型化参数、JSON 请求体、状态/媒体类型/声明响应头及响应体校验。复用 `moonbitstack/moonschema@0.2.0`，不再重复制造浅层 Schema 验证器。
- **多文档契约生命周期**：显式离线资源锁、跨文档 JSON Pointer、传递反向依赖、不可变快照、原子文档替换/移除、失败回滚、无变化复用和受影响操作重建。
- **消费者驱动升级门禁**：结构性破坏阻断；复杂 Schema 变化保守标记 `review`，需要显式审批和正向用例覆盖。每次重验旧基线，候选只重放变化操作的用例，结果与冷启动对照，导出不含调用值的 JSON 报告。不是任意 Schema 的兼容性证明。

| 代表场景 | 输入到输出 | 运行命令 |
| --- | --- | --- |
| SDK / 服务边界 | OpenAPI 库存接口 → 参数预检与路径编码 → 接收响应时拒绝负库存 | `moon run examples/contract_sdk --target wasm-gc` |
| 多服务共享 DTO 演进 | 身份 Schema 的跨文档修改 → 2/3 操作重建 → 引用错误回滚及冷启动等价检查 | `moon run examples/contract_workspace --target wasm-gc` |
| CI / 契约编辑器发布门禁 | 消费者正反样例 → 变化分类 → 受控审批 → 定向重放和 JSON 结果 | `moon run examples/contract_ci --target wasm-gc` |

三个是有断言的可运行集成示例，不是已有企业用户采用证明。完整格式、支持矩阵、复杂度、量化验证和生态分工见 [API 契约工作区](docs/API_CONTRACTS.md)。

```text
import {
  "JSJ222/moonuritemplate/contracts" @contracts,
}
```

关键入口：`compile_workspace` / `import_openapi`、`validate_request` / `validate_response`、`update_documents`、`compare` / `gate_upgrade`。工作区文档更新仅用于 Schema；操作定义变更须重新导入或冷编译，不能把改 OpenAPI 操作声明当 Schema 补丁。库不负责 HTTP I/O、认证、YAML、线格式解码或 SDK 代码生成。所有调用必须串行使用同一工作区的上游验证器。

## 保留的 URI 模板能力

根包仍为 RFC 6570 Level 4 URI Template 编译与展开库，处理 UTF-8 百分号编码、8 种标准展开运算符、前缀和 explode 修饰符、标量和复合值。它为工作区提供 path 构造，但不是本次差异化贡献的主体。

## 解决什么问题

API 客户端、MCP 资源客户端和服务端超媒体响应常需要把变量嵌入 URI。手写字符串拼接容易把路径中的 `/`、空格、`%`、Unicode 和可选查询参数处理错。RFC 6570 为这些情况规定统一的展开语义，本库提供可复用的编译结果及显式错误。

根包专注**前向展开**。它不解析一般 URI、不反向匹配路由、不发送 HTTP 请求；OpenAPI 导入位于独立的 `contracts` 包。OpenAPI 的线格式参数序列化不能仅由 RFC 6570 表达；旧 [API 示例](examples/api/main.mbt)只展示 URI 构造子集。

## 作为依赖使用

公开仓库：[JSJ222/MoonUriTemplate](https://github.com/JSJ222/MoonUriTemplate)。包命名空间为 `JSJ222/moonuritemplate`。

```sh
moon add JSJ222/moonuritemplate@0.3.0
```

在使用方的 `moon.pkg` 中配置导入：

```text
import {
  "JSJ222/moonuritemplate" @uri_template,
}
```

库作者、维护提交身份和发布账户为 `JSJ222`。第三方测试向量仍遵循原作者及其许可证，详见 `THIRD_PARTY.md`。
## 从源码运行

需要 MoonBit 工具链。在此源码目录运行：

```sh
moon version --all
moon check --target all --deny-warn
moon build --target all --deny-warn
moon test --target all --deny-warn
moon run examples/api --target wasm-gc
moon run examples/mcp --target wasm-gc
moon run examples/hypermedia --target wasm-gc
```

上述三个示例分别生成 API 请求 URI、MCP 资源 URI 和订单链接。`moon run cmd/main --target wasm-gc` 提供最小独立样例。

## 基本 API

```moonbit
let template = @uri_template.parse("/users/{id}{?fields*,limit}")
let values : Array[(String, @uri_template.Value)] = [
  ("id", Scalar("team/a")),
  ("fields", List(["name", "email"])),
  ("limit", Scalar("20")),
]
// 对 Ok(template) 调用 template.expand(values)，得到：
// /users/team%2Fa?fields=name&fields=email&limit=20
```

完整、可直接执行的错误处理见 [examples/api/main.mbt](examples/api/main.mbt)。编译一次模板可反复调用 `Template::expand`；只用一次时可调用 `expand(source, values)`，返回区分解析和展开阶段的 `TemplateError`。`Template::variables`、`Template::analyze` 和 `Template::inspect_bindings` 可用于 SDK 预检。`bindings_from_json` 将只含字符串、null、字符串数组和字符串对象的 JSON 树转换为确定性绑定；它拒绝数字和布尔值的隐式字符串化。

批量链接生成可调用 `Template::expand_many`，为每行使用同一个编译结果并设置单行与总输出限额。`Template::bind` 将常用的租户或 API 前缀变量固定为 `BoundTemplate`；捕获时复制复合值，避免调用方后续修改数组影响结果。命名端点集合可通过 `compile_catalog` 一次编译，重复名称会报错。

对固定 SDK 操作，`Template::expand_required` 可要求每个变量均有绑定，并可拒绝未使用参数；普通 `expand` 仍遵循 RFC 6570 的未定义变量省略语义。`Template::variable_profiles` 提供每个变量的标量限制、修饰符和使用次数，`Template::check_policy` 可预检保留字符、片段、特性级别及重复引用。`Template::expand_detailed` 返回每个源段对应的输出位置，供编辑器和诊断工具定位。已有 JSON 树可直接交给 `Template::expand_json`。

`Template::measure` 在不构造最终 URI 的前提下计算精确输出长度，并应用与 `expand` 相同的输入和输出限额。该操作仍会分配 UTF-8 输入字节数组，适用于生成大量链接前的容量预检。`BoundTemplate::measure` 与 `TemplateCatalog::measure` 对应部分绑定和命名模板。`Template::diff_contract` 只报告变量及运算符的静态变化，不证明两版模板生成的 URI 相同。

已有 JSON 配置的客户端可用 `compile_catalog_json` 把“端点名 → 模板字符串”的对象编译为命名目录，再用 `TemplateCatalog::expand_json` 根据 JSON 参数生成链接。JSON 键按 UTF-16 词法顺序排列；如果上游 JSON 解析器已丢弃重复键，应在读取文本时自行拒绝重复键。

十月新增 `TemplateCatalog::measure_requests`，可在批量生成前检查精确总输出长度而不构造 URI 数组；`templates_using` 按目录顺序列出引用某变量的模板，便于 SDK 字段迁移时定位受影响端点。详见 [十月新增能力](docs/OCTOBER_FEATURES.md)。

## 新增：运行时参数契约与增量链接

- `Template::with_contract` 为 SDK、MCP 参数声明必填项及标量/列表/关联数组类型，提前拒绝类型错误、缺失项和未知参数；普通 RFC 展开语义保持不变。
- `TemplateCatalog::start_session` 捕获共享绑定；`LinkSession::update` 按变量依赖只重新展开受影响端点，返回实际变化的链接和新快照。复合输入被复制，失败更新保留旧快照，输出预算包含未变化的链接。

运行 `moon run examples/contracts --target wasm-gc` 和 `moon run examples/incremental_links --target wasm-gc`。语义、预算和复杂度见[运行时集成](docs/RUNTIME_INTEGRATIONS.md)。这些能力自 `0.2.0` 提供。

已适配官方 MoonBit 0.10.16。受影响的 Windows 工具链使用 `./tools/windows/moon.ps1` 代替 `moon`；参见[工具链说明](docs/WINDOWS_TOOLCHAIN.md)。

内部可变容器已改为私有，直接读字段的旧代码需改用 `variables()`、`names()`、`get()`、`fixed_names()` 等已有方法。

## 语义与边界

- 默认解析模式按 RFC 6570 字面量语法检查 Unicode、括号、变量名和修饰符。公开测试集中有一条包含模板外单引号的历史样例，与规范的字面量 ABNF 不一致；`strict_literals=false` 仅为这类兼容输入开放。
- 空字符串是已定义值，空列表和空关联数组视为未定义。`SparseList` 与 `SparseAssoc` 支持成员级未定义值。关联数组按调用方给定顺序展开；JSON 桥接器则按键排序。
- 前缀长度按 Unicode 标量计数；已编码的有效 UTF-8 百分号序列作为一个字符，避免截断。变量名中的百分号序列保持原样，不被解码。
- 错误偏移使用 UTF-16 代码单元。模板长度、表达式数、变量数、绑定数、单值长度、复合成员数和输出长度均有限额；可按调用方需求调整。
- 只负责展开字符串，不验证最终 URI 的 scheme、authority 或目的地址。对不可信变量使用 `+` 或 `#` 时，应由上层限制允许的目标；详见 [安全边界](docs/security.md)。

## 验证与来源

测试包含 [uri-templates/uritemplate-test](https://github.com/uri-templates/uritemplate-test) 固定提交中的 270 条用例，并保留其 Apache-2.0 许可证。测试代码由 [生成脚本](tools/generate_conformance.py) 从 JSON 向量生成；生成代码不计入手写源码规模。另有解析错误、Unicode、资源限制、JSON 桥接和静态分析测试。详见 [符合性说明](docs/conformance.md) 和 [第三方材料](THIRD_PARTY.md)。

`moon run benchmarks/main --target native --release` 可执行固定的 20,000 次展开工作量；本机基线和复现条件见 [性能记录](docs/performance.md)。

项目采用 Apache-2.0 许可证，见 [LICENSE](LICENSE)。

## 十月第二轮：目录迁移与请求审查

`TemplateCatalog::diff_catalog(next)` 列出新增、删除和变更端点，连字面量路径变化也保留；每项变更附原有变量/运算符契约报告。`inspect_requests` 检查混合请求的全部诊断，限制请求、绑定及结果数量，返回请求索引和变量名，不包含绑定值。缺失变量属于提示，普通 RFC 展开允许省略。

`expand_requests` 现在先调用精确计量，再构造输出，确保总预算超限在生成 URI 数组前被拒绝。计量仍有输入编码的临时分配，展开需额外遍历一次。运行 `moon run examples/maintenance --target wasm-gc`。详见 [功能与边界](docs/OCTOBER_FEATURES.md)。
