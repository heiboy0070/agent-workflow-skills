---
name: pre-mortem-design
description: "Use when designing or planning a fix/feature in high-risk domains BEFORE finalizing the plan — state machines, payments/billing/money, concurrency or multi-process/multi-device, durable data mutation, auth/authorization, external system integration (webhooks, 3rd-party APIs, message queues). Symptoms: about to propose \"cancel/supersede/invalidate\" based on local state, designing retry/idempotency, writing a status transition, or wiring a webhook/listener."
---

# Pre-Mortem Design

## 核心原则（先内化）

**方案要"生来就硬"，不是事后靠 code-review / red-team 补。**

在出方案/写 plan **之前**，假设它已经上线出事了——倒推最可能的死法。每条死法对应一个维度的自检。`code-review` / `security-review` 是**事后**兜底；这个 skill 是**事前**让方案不必靠兜底。

**违反字面规则就是违反规则精神。** "先把 happy path 写出来，并发/安全等 review 再说"——这就是这个 skill 要拦的。

## 何时用（高风险域，才触发）

设计/plan 涉及以下任一，**必须**先做 pre-mortem 自检再定方案：
- 状态机 / 状态转换（pending/paid/...、订单/报名/支付生命周期）
- 钱 / 支付 / 计费 / 退款 / 余额
- 并发 / 多进程 / 多设备 / 多请求操作同一资源
- 必须持久、不能丢、不能重复的数据写
- 鉴权 / 授权 / 越权 / 敏感数据
- 外部系统集成（webhook、Stripe/第三方 API、消息队列、定时任务）——凡是"本地状态要和外部系统对齐"的

**不在这些域**（纯展示、纯读、单进程无状态工具）——别滥用，直接做。

## Pre-Mortem 八维自检（方案定稿前过一遍）

假设方案上线挂了，逐条问"会不会因此挂"：

| 维度 | 要回答的问题 | 挂的方式 |
|---|---|---|
| **1. 并发/race** | 两个请求/进程/webhook/设备**同时**操作同一资源会怎样？check-then-act 有没有 TOCTOU 窗口？ | 抢座超卖、重复扣款、双开结账 |
| **2. 幂等** | 同一操作**重复**执行（重试/双击/网络重放/webhook 重复投递）结果一致吗？幂等 reservation/lock 是否覆盖 fresh pending、stale pending、succeeded、provider failure、进程崩溃恢复？ | 重复 enrollment、重复退款、重复扣款、同一 key 永久卡死 |
| **3. 原子性/CAS** | 状态转换是 `UPDATE ... WHERE status='X'`（条件更新）还是 read-then-write？跨进程的竞态有没有 DB CAS/锁兜底？ | 丢失更新、覆盖了他人的转换 |
| **4. 状态机完备** | 所有状态、所有转换（含**失败/超时/取消/补偿/回滚**）都定义了？有死状态/不可达/卡死状态吗？ | 卡 pending 永不流转（见反面例子） |
| **5. 源真相对齐 ⭐** | 本地状态 vs 外部系统（Stripe/第三方/DB）**谁是 source of truth**？本地状态会不会**滞后**外部？**仅凭本地状态"作废/取消/判定已死"安全吗？** | 误取消"已付款但本地未翻转"的单（见反面例子） |
| **6. 失败兜底/对账** | 支付成功但履约失败？webhook 丢失/延迟/乱序？钱或数据**会不会丢**？有没有 `requires_review`/对账/重放兜底？stale pending 是安全恢复、人工复核，还是永久阻塞/粗暴释放？ | 客户被扣款却没拿到货、静默丢支付、二次扣款 |
| **7. 安全** | 鉴权/越权/IDOR/注入/敏感数据/重放？destructive 操作校验归属了吗？用户可控 metadata/JSON/map merge 会不会覆盖 server-owned keys（如 `idempotency_key`/`status`/`customer_id`/`recovery_*`）？ | 越权取消他人订单、数据泄漏、幂等查询被污染 |
| **8. 性能/资源** | 热点锁/锁粒度/N+1/资源泄漏？大事务挡住别人？ | 锁竞争、超时、连接耗尽 |

**第 5 维（源真相对齐）是最容易被漏的**——下面的反面例子就是。

## 怎么做（流程）

1. **先写一句话假设**："假设这个方案上线一周后炸了，最可能的 3 种死法"。强制自己写失败假设，不要先写实现。
2. **逐维过表**：对每个维度，要么"不会因此挂 + 为什么"，要么"会 → 改方案/加防护"。
3. **改完再下笔写 plan**：plan 里要能看到这些防护（CAS、状态机、对账兜底），不是事后补。
4. 如果你发现自己只想画 happy path（正向 pending→paid），**停**——补失败/并发/重放分支再继续。

## 支付幂等专项检查

设计 payment/refund/charge 的幂等表、reservation、lock 或 JSON metadata 时，plan 必须明确：

- **server-owned fields 不可被 caller 覆盖**：任何 `req.Metadata` / extra JSON / map merge 都要有保留字段 denylist 或 server-fields-last 规则，并测试 hostile keys（`idempotency_key`、`status`、`customer_id`、`recovery_*`、大小写/空白变体）。
- **reservation 生命周期**：fresh pending、stale pending、succeeded with pointer、provider failure release、crash after reserve before provider result、crash after provider success before local complete。
- **provider idempotency key 兼容**：改变 Stripe/第三方幂等 key 格式前，必须考虑已部署版本的重试窗口。pre-deploy 请求可能已经到 provider 但本地未落库；retry 若换 key 会变成第二笔外部操作。
- **stale 策略**：不能二选一地永久 409 或超时直接删除。支付场景要复用同一个 provider idempotency key、retrieve/reconcile 外部事实，或进入人工复核；不查外部事实的 TTL 释放是风险。

## 反面例子（真实，来自本项目）

**场景**：课程结账失败后 checkout session 卡 `pending`，挡住同一孩子重新购买。要修。

❌ **朴素方案（漏了第 5 维）**：
> "重新发起结账时，把同孩子的旧 pending session **取消**，放新的。"

朴素方案的隐含假设："pending = 未付款 = 可安全取消"。但这是**本地状态**。真实 race：
- T0：session S1 `pending`，家长正在 Stripe 付款
- T1：S1 在 **Stripe 侧付款成功**，但本地还是 `pending`（webhook 异步、还在路上）
- T2：家长/另一设备发起 S2 → 朴素逻辑看 S1 是 `pending` → **取消 S1**
- T3：S1 的 paid webhook 到达，但 S1 已被取消 → 客户**被扣款、enrollment 没建**（钱货两空）

**根因**：本地 `status` 滞后 Stripe 真相；仅凭本地 pending 作废不安全。

✅ **pre-mortem 后的硬方案**：
- 清理死 session **必须绑外部证据**（Stripe `expires_at` 已过 / `retrieve` 确认未付），不绑本地 pending。
- 状态转换用 CAS（`UPDATE WHERE status='pending'`），webhook 的 paid 更新与本地作废竞争同一行，谁先谁赢。
- webhook **必须可对账**：即便本地已 canceled/superseded，收到 PAID 事件绝不丢，转 `requires_review` 人工兜底（不丢支付事实）。
- 占容量名额要在状态转换的**同一事务**里释放。

## Rationalization 表（自己骗自己时对照）

| 借口 | 现实 |
|---|---|
| "守卫已经用事务锁了，并发安全" | 守卫的 TOCTOU 安全 ≠ 你新增的清理/作废逻辑也安全。新增路径要单独验。 |
| "pending 就是未付款，可以安全取消" | 本地 pending ≠ 外部未付款。状态有滞后窗口。第 5 维。 |
| "webhook 会处理" | webhook 异步、可能延迟/丢失/乱序/重复。不能作唯一清理源，必须有对账兜底。 |
| "先把主流程跑通，并发/安全后面 review 再补" | 这就是本 skill 要拦的。事后 review 是补丁，补丁会漏。 |
| "这种 race 太罕见，不用考虑" | 钱和数据的 race，罕见=爆炸时不可逆。必须考虑。 |
| "我用的框架/事务会处理并发" | 框架不替你想 source-of-truth 滞后和跨系统对账。自己验。 |
| "只是改个小状态，不用 pre-mortem" | 状态机改动是高风险域的本体。越小的改动越容易漏 race。 |

## 红旗清单（出现就停，回去做 pre-mortem）

- 方案里出现 "取消/删除/作废/覆盖/重置" 等 destructive 动词，却没问"会不会误伤进行中的操作"
- 只描述 happy path，没列**失败/超时/取消/重放/并发**分支
- 把外部系统当同步且可靠（"webhook 会及时到"、"第三方 API 不会挂"）
- 基于 read-then-write 改共享状态（`if status==X then save Y`），没有 CAS/锁
- 状态机只画正向（pending→paid→fulfilled），没画失败/补偿/超时出口
- 用本地时间/本地状态判定"外部已经发生的事"（如本地 pending 判定"Stripe 没收款"）

**以上任一出现 → 停，回八维表，至少补第 1/3/5/6 维再下笔。**

## 和事后 review 的分工

| | 时机 | 干什么 |
|---|---|---|
| **pre-mortem-design（本 skill）** | 设计/plan 阶段 | 让方案生来就硬：结构化排除 race/丢钱/越权等 |
| `code-review` / `security-review` | 实现后 | 兜底查实现是否偏离了已硬化的方案、查漏网之鱼 |

两者**配套**，不可互相替代。设计期没硬度，review 期只能补丁。
