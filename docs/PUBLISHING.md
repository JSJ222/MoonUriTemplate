# JSJ222 发布准备记录（2026-10-03）

- GitHub 目标：`https://github.com/JSJ222/MoonUriTemplate`，公开仓库，默认分支 `main`。
- Mooncakes：`JSJ222/moonuritemplate@0.1.0`。
- 本仓库 Git 作者及提交者统一为 `JSJ222 <326471407+JSJ222@users.noreply.github.com>`，仅设置项目级配置。
- 54 条尚未推送的旧本地提交按用户要求统一身份；提交树、消息、父子关系及时间保留，提交哈希随身份变化。
- 原历史完整 Git bundle、改写映射和修改前配置/README 保存在工作区的 `发布备份/MoonUriTemplate-JSJ222-20261003/`，不进入发布包。
- 既有审查记录中的旧提交哈希属于改写前历史；不应将其当作新公开仓库的可访问哈希。
- 命名空间、全部内部包导入、生成接口及申报书仓库链接已同步；申报书参赛者仍为空。

## 发布门禁

改名后本地严格 check/build 全后端通过，wasm、wasm-gc、js、native 各 119 项测试通过；维护示例和 Native release 基准负载正常。
推送后必须确认仓库 owner 和所有提交的 GitHub 关联身份，等待默认分支 CI 成功，再发布 Mooncakes 并进行独立安装使用验证。
远端结果和发布版本以 GitHub Actions、GitHub Release、Mooncakes 实际记录为准。

## 已完成发布

- 公开仓库 `JSJ222/MoonUriTemplate`，默认分支 `main`；GitHub API 核验公开仓库拥有者为 JSJ222。
- 首次推送 55 条提交，GitHub API 核验作者和提交者的关联账号均只有 `JSJ222`，包括全部历史提交。
- 发布源提交：`0f8bf2df774b37cd144d0f4af0d877edabd79a7f`；[对应 CI](https://github.com/JSJ222/MoonUriTemplate/actions/runs/37108333078) 的 Ubuntu 和 Windows 作业全部成功。
- Mooncakes `JSJ222/moonuritemplate@0.1.0` 发布 API 返回 `200 OK`，归档及解包检查通过。
- 在工作区独立 `发布验证/MoonUriTemplate-JSJ222-0.1.0` 中，从公共注册表实际下载 0.1.0；运行展开、目录迁移、参数审查及混合请求 API 成功，不依赖本地 path 依赖。
- 版本标签 `v0.1.0` 对应上述发布源提交；后续本记录完善仅为发布证据，不改变已发布 0.1.0 的实现。
- 原来的带日期审查记录为发布前快照，外部未满足项以本记录更新；申报资料仍需申请人按十月章程人工核实定稿。
