---
name: writing-integration-docs
description: Use when asked to write or update an integration-facing API doc for a backend service/interface (写接口对接文档 / 接入文档 / api doc / integration doc / 对接方文档) — produce a doc that tells clients exactly how to call a set of endpoints, with full request/response examples and error cases.
---

# Writing Integration Docs

## Overview
对接文档的唯一标准 = **与代码实际行为一致**。最大风险是照抄/沿用旧文档或凭印象写，导致描述与实现脱节（返回字段、错误格式、SSE/JSON 边界、音频/数据格式等全可能错）。

铁律：**先读真实实现（router→controller→service→types），再动笔；文档只写对接所需，每个接口给完整请求/响应实例 + 真实错误情况。**

违反字面 == 违反精神。下面每条都不是建议，是必须。

## Iron rules
1. **先读代码，不信任任何现有文档。** 现有 `docs/*.md` 可能严重过时。沿 router → controller → service → repository → types 读真实实现，记录：实际接口路径、请求校验、响应包格式、SSE 事件序列、错误返回方式、音频/数据格式。
2. **文档只写"如何对接"。** 不写架构/设计/为什么（两阶段流水线、模型选型理由、为什么不是流式 等，不属于对接文档）。不写本接口包之外的接口（如图片 OSS 直传属于别的接口包——最多一行说明前置依赖）。
3. **每个接口必须有完整请求实例 + 成功响应实例。** 不止字段表——给真实可读的 JSON / SSE 片段，含多种调用场景（首调、续接、多图等）。
4. **错误响应必须真实，来自实际中间件 / ResponseHelper。** 读 `validateRequest` / `authenticateToken` / `ResponseHelper` 的真实返回格式与文案，照抄。禁止编造 errorCode 或 message。
5. **分清错误返回的两段边界。** 流式（SSE）接口：**进入流式前**的鉴权/参数错误是 JSON；**进入流式后**的错误是 SSE `event: error`。两段对客户端处理方式不同，必须分开写。
6. **覆盖意外情况，不只是 happy path。** 空结果（不报 404 的空数组）、无数据、连接中断、边界角色（如只能重听 assistant）、跨资源访问（别人的记录 → 404）等，逐个给真实响应实例。
7. **文档与代码冲突时，以代码为准修文档；发现代码 bug 顺手修并验证。** 例如 done 字段值与实际下发内容矛盾 → 修代码 + 文档写真实值。改动需用户拍板的关键决策（增删接口、改音色等）先问，不自作主张。
8. **用真实证据验证。** 改了代码就跑 `tsc` + 相关单测；与改动前基线对比失败数，证明零回归。不写"已验证 / 经真实 API 验证"这种无证据总结。

## Process
0. **读真实实现**：router（接口清单 + 校验规则）→ controller（返回格式、SSE 事件、错误分支）→ service（核心流程、数据格式、音色/格式常量）→ types（字段定义）→ 中间件（鉴权/校验失败返回）→ ResponseHelper（响应包结构 + 各 errorCode 文案）。
1. **定范围**：哪些接口属于"本接口包"。图片上传/换 code/鉴权获取等若属别的接口包，文档只用一行说明前置依赖，不展开。
2. **对照参考接口**（若有同类，如"家教老师"）：建议本服务该补/该删哪些接口，给用户拍板，不擅自扩范围。
3. **写每个接口**：请求（头 + body 字段表 + 完整实例，含多种场景）→ 成功响应（完整实例）→ done/事件字段表 → 错误与意外（真实格式实例）。
4. **核实错误真实性**：每个 errorCode/message 必须能在中间件或 controller 找到出处。SSE 接口写清 JSON 错误 vs `event: error` 边界。
5. **修代码 bug**（若有）：文档与实现不符且实现有 bug，顺手修，跑 `tsc` + 单测，基线对比零回归。
6. **交付**：本地 `docs/*.md`（按项目约定通常不进 git，保持 untracked）；按需导入飞书（`docx_builtin_import`，传最终版 markdown + file_name）。

## 对接文档骨架
```
0. 通用约定（响应包、HTTP 状态约定、Base URL —— 不写本地地址，客户端没后端代码可跑）
1. 鉴权（token 传法 + 鉴权失败的真实响应实例）
2. 接口清单（表格）
3..N. 每个接口：请求 / 成功响应 / 字段表 / 错误与意外
N+1. 错误码总表（含 500 / event:error / 各接口触发场景）
N+2. curl 自测（真实可跑）
N+3. 注意事项（对接相关，非架构解释）
```

## Red flags — STOP
- 即将照抄现有 `docs/*.md` 而没读 router/controller/service → STOP，先读真实实现。
- 即将写"流式 PCM / 边合成边推"之类描述而没核对 TTS/音频实际返回格式 → STOP，去读 synthesize 返回的 format 分支。
- 错误响应里写了"觉得应该有"的 errorCode/message 而没在中间件/ResponseHelper 找到出处 → STOP，照真实格式。
- SSE 接口把所有错误写成一种（全 JSON 或全 event:error）→ STOP，分进入流式前/后两段边界。
- 只写 happy path，没有空结果/无数据/连接中断/越权等意外 → STOP，补全。
- 写了架构/设计/为什么（两阶段、模型选型）或混入别的接口包的接口（OSS 上传）→ STOP，删，只留对接所需。
- Base URL 写了 `localhost` / `127.0.0.1` → STOP，客户端没有后端代码可跑，只写对外地址。
- 改了代码却不跑 tsc/单测，或写"已验证"无证据 → STOP，跑验证 + 基线对比。

## Rationalizations (forbidden)
| Excuse | Reality |
|---|---|
| "现有文档应该是对的，照着改改就行" | 现有文档常与实现严重脱节（音频方案、字段值都可能整段写错）。必须读代码。 |
| "错误响应大致这样写就行" | 编造的 errorCode/message 会让对接方写错处理逻辑。必须来自实际中间件。 |
| "架构/两阶段流水线客户端也该知道" | 对接文档只讲怎么调。架构解释放别处。 |
| "OSS 上传也写上，客户端方便" | 不属于本接口包。一行前置依赖即可，不展开。 |
| "happy path 写清楚就够了" | 对接方踩的全是意外（空结果、越权、断连）。必须覆盖。 |
| "Base URL 写个 localhost 方便本地测" | 客户端没有后端代码可跑。只写对外地址。 |
| "改了 1 行代码不用跑测试" | 1 行也可能回归。tsc + 基线对比零回归才算验证。 |
| "导入飞书随便贴个 markdown" | 导入前确认是最终版（修完交叉引用笔误、字段值等）。 |
