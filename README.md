# MoonURITemplate

MoonURITemplate 是纯 MoonBit 的 RFC 6570 Level 4 URI Template 编译与展开库。它把 `/users/{id}{?fields*,limit}` 和调用时的变量转换为 URI 引用，处理 UTF-8 百分号编码、8 种标准展开运算符、前缀和 explode 修饰符，以及标量、列表、关联数组。代码可在 wasm、wasm-gc、js 和 native 后端运行。

## 解决什么问题

API 客户端、MCP 资源客户端和服务端超媒体响应常需要把变量嵌入 URI。手写字符串拼接容易把路径中的 `/`、空格、`%`、Unicode 和可选查询参数处理错。RFC 6570 为这些情况规定统一的展开语义，本库提供可复用的编译结果及显式错误。

本项目专注**前向展开**。它不解析一般 URI，不反向匹配路由，不发送 HTTP 请求，不读取 OpenAPI 文档。OpenAPI 的部分参数序列化方式不能仅由 RFC 6570 表达；[API 示例](examples/api/main.mbt)只展示适用子集。

## 从源码运行

需要 MoonBit 工具链。当前仓库尚未发布到 mooncakes.io，请先在此源码目录运行：

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

## 语义与边界

- 默认解析模式按 RFC 6570 字面量语法检查 Unicode、括号、变量名和修饰符。公开测试集中有一条包含模板外单引号的历史样例，与规范的字面量 ABNF 不一致；`strict_literals=false` 仅为这类兼容输入开放。
- 空字符串是已定义值，空列表和空关联数组视为未定义。`SparseList` 与 `SparseAssoc` 支持成员级未定义值。关联数组按调用方给定顺序展开；JSON 桥接器则按键排序。
- 前缀长度按 Unicode 标量计数；已编码的有效 UTF-8 百分号序列作为一个字符，避免截断。变量名中的百分号序列保持原样，不被解码。
- 错误偏移使用 UTF-16 代码单元。模板长度、表达式数、变量数、绑定数、单值长度、复合成员数和输出长度均有限额；可按调用方需求调整。
- 只负责展开字符串，不验证最终 URI 的 scheme、authority 或目的地址。对不可信变量使用 `+` 或 `#` 时，应由上层限制允许的目标；详见 [安全边界](docs/security.md)。

## 验证与来源

测试包含 [uri-templates/uritemplate-test](https://github.com/uri-templates/uritemplate-test) 固定提交中的 270 条用例，并保留其 Apache-2.0 许可证。测试代码由 [生成脚本](tools/generate_conformance.py) 从 JSON 向量生成；生成代码不计入手写源码规模。另有解析错误、Unicode、资源限制、JSON 桥接和静态分析测试。详见 [符合性说明](docs/conformance.md) 和 [第三方材料](THIRD_PARTY.md)。

`moon run benchmarks/main --target native --release` 可执行固定的 20,000 次展开工作量；本机基线和复现条件见 [性能记录](docs/performance.md)。

项目采用 Apache-2.0 许可证，见 [LICENSE](LICENSE)。[选题与竞品核查](docs/topic-research.md) 记录了 2026-10-01 的调查；Mooncakes 目录会变化，申报及发布前应实时复查。

## 十月第二轮：目录迁移与请求审查

`TemplateCatalog::diff_catalog(next)` 列出新增、删除和变更端点，连字面量路径变化也保留；每项变更附原有变量/运算符契约报告。`inspect_requests` 检查混合请求的全部诊断，限制请求、绑定及结果数量，返回请求索引和变量名，不包含绑定值。缺失变量属于提示，普通 RFC 展开允许省略。

`expand_requests` 现在先调用精确计量，再构造输出，确保总预算超限在生成 URI 数组前被拒绝。计量仍有输入编码的临时分配，展开需额外遍历一次。运行 `moon run examples/maintenance --target wasm-gc`。详见 [本轮审查与复杂度](docs/SECOND_REVIEW.md) 和 [十月申报资料稿](十月项目申报书.md)。
