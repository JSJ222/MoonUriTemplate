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
