---
name: pre-mortem-design
description: "Use when designing or planning a fix/feature in high-risk domains BEFORE finalizing the plan — state machines, payments/billing/money, concurrency or multi-process/multi-device, realtime connections/reconnects, scarce resource or connection pools, durable data mutation, auth/authorization, external system integration (webhooks, 3rd-party APIs, message queues). Symptoms: about to propose \"cancel/supersede/invalidate\" based on local state, designing retry/idempotency, writing a status transition, wiring a webhook/listener, or changing socket/lease/pool/worker lifecycle."
---

# Pre-Mortem Design

## 核心原则（先内化）

**方案要"生来就硬"，不是事后靠 code-review / red-team 补。**

在出方案/写 plan **之前**，假设它已经上线出事了——倒推最可能的死法。每条死法对应一个维度的自检。`code-review` / `security-review` 是**事后**兜底；这个 skill 是**事前**让方案不必靠兜底。

**违反字面规则就是违反规则精神。** "先把 happy path 写出来，并发/安全等 review 再说"——这就是这个 skill 要拦的。

**这是实施前硬门禁，不是 plan 末尾的风险附录。** 高风险方案必须先交付可审阅的 pre-mortem、证据和最坏上界，再写实现步骤；证据不足就标为未知并安排只读核查，不能用猜测填空后直接实施。

## 何时用（高风险域，才触发）

设计/plan 涉及以下任一，**必须**先做 pre-mortem 自检再定方案：
- 状态机 / 状态转换（pending/paid/...、订单/报名/支付生命周期）
- 钱 / 支付 / 计费 / 退款 / 余额
- 并发 / 多进程 / 多设备 / 多请求操作同一资源
- 实时连接 / 自动重连 / 长连接 / 心跳 / 看门狗 / 半开探测
- 稀缺资源与连接池（数据库连接、云并发、租约、线程、队列、serverless 实例）
- 必须持久、不能丢、不能重复的数据写
- 鉴权 / 授权 / 越权 / 敏感数据
- 外部系统集成（webhook、Stripe/第三方 API、消息队列、定时任务）——凡是"本地状态要和外部系统对齐"的

**不在这些域**（纯展示、纯读、单进程无状态工具）——别滥用，直接做。

## Pre-Mortem 十维自检（方案定稿前过一遍）

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
| **8. 资源乘数/容量上界** | 资源按 request/session/user/process/instance/key/provider 各分配多少？独立重试、worker、pool 相乘后的**系统级最坏上界**是多少？队列和池饱和后是排队、拒绝还是继续扩实例？ | 单连接看似便宜，扩成数百云并发、数百 Sleep 连接、重试风暴 |
| **9. 生命周期/释放顺序** | socket/lease/timer/pool/worker 谁 create→renew→drain→release→force-expire？SDK 回调永不返回怎么办？日志/DB/告警失败会不会挡住稀缺资源释放和安全看门狗启动？ | 孤儿会话、半开死锁、资源已无业务价值却占到一小时上限 |
| **10. 可观测/灰度/回滚** | 哪些指标证明方案有效？灰度单位、停止条件、最小回滚提交是什么？监控是否能区分真实业务增长、内部放大和攻击？ | 全量上线后才发现延迟/资源继续爬升，只能整体回滚或停服 |

**第 5 维（源真相对齐）是最容易被漏的**——下面的反面例子就是。

## 怎么做（流程）

1. **先写一句话假设**："假设这个方案上线一周后炸了，最可能的 3 种死法"。强制自己写失败假设，不要先写实现。
2. **列参与者和资源**：客户端、服务端、SDK、worker、数据库、第三方分别会创建/重试/释放什么；标明状态是进程内、Redis、DB 还是外部事实。
3. **算最坏上界**：写出容量乘法式，例如 `用户 × 每用户会话 × 每会话 recognizer × 重试代际`、`实例 × 每实例 Pool 上限`；不能只审一条连接或一个实例。
4. **逐维过表**：对每个维度，要么"不会因此挂 + 证据"，要么"会 → 改方案/加防护"。
5. **先定灰度和回滚再写 plan**：plan 里要能看到 CAS、状态机、对账、资源强制过期、停止条件和独立回滚单元，不是事后补。
6. 如果你发现自己只想画 happy path（正向 pending→paid、连接→识别→关闭），**停**——补失败/超时/取消/重放/并发/回调不返回/依赖饱和分支再继续。

## 实时连接与资源池专项检查

设计 WebSocket、语音识别、长轮询、数据库 Pool、云资源租约、自动恢复或后台探针时，plan 必须明确：

- **重连所有权矩阵**：客户端、服务端、SDK、网关、定时 worker 各自在什么条件重连；每层的单飞、退避、上限、熔断和取消条件。不同层的重试不能互相产生新的无界会话。
- **身份与代际**：connectionId/sessionId/messageId/leaseId 分别代表什么；恢复是复用业务会话还是创建新连接代际。不能为了合并结果而破坏唯一标识语义。
- **系统级容量式**：至少计算 `每用户连接上限 × 活跃用户`、`实例数 × 每实例 Pool connectionLimit`、`Resource 数 × 每 Resource 探针/租约上限`，并写清饱和后的行为。
- **配置真的生效**：不能只看 `idleTimeout`/TTL/limit 的名字。核对依赖版本、默认值、启用条件和源码；例如某些 Pool 只有 `maxIdle < connectionLimit` 才启动 idle 回收。
- **完整生命周期**：对 WS、Recognizer、PushStream、租约、timer、PoolConnection 和 worker 分别写 create→renew→drain→release→force-expire，尤其覆盖 SDK stop/close 回调永不返回。
- **释放优先级**：稀缺云资源/租约先释放，埋点、MySQL 最终写入、告警和统计不得阻塞；安全看门狗也不能等这些依赖成功后才启动。
- **活跃定义**：区分“持续真实数据”“持续静音/空帧”“完全没有包”“仅心跳”。淘汰策略必须基于代码可观测的信号，不能把“用户没说话”直接等同于“连接失活”。
- **半开恢复**：探针必须单飞、有超时、有释放；多个真正独立 Resource 应能独立探测，健康状态下不做无意义全量扫描，异常时保证有限周期内有恢复尝试。
- **体验预算**：释放/恢复会增加多少首包和首字延迟，如何避免恢复触发包丢失，缓存上限和溢出策略是什么；不能用长等待换“正确”后再声称是 realtime。
- **灰度停止条件**：至少观察并发占用、连接/会话年龄、Pool Sleep/Running、恢复耗时、首字延迟、重复/缺失业务消息；任一单调爬升或用户体验回归都必须能停止并回滚最小提交。

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

## 反面例子（真实生产事故：实时语音资源放大）

**场景**：实时语音服务出现异常重连/孤儿会话。云语音并发从低位持续爬升到约 400，MySQL 出现 `427/500` 连接告警，最终导致直播停止并造成实际经营损失。

❌ **只看单连接的朴素判断**：
> "一条空闲 WebSocket 不独占 MySQL 连接；SDK 最后会超时；Pool 配了 60 秒 idleTimeout，所以先保留，避免影响体验。"

这个判断逐句看都像合理，但漏了系统乘数和释放顺序：

- 外层 WS 被反复新建，服务端没有每用户上界，单用户可形成数百 sessionId。
- 长 WS 延长 serverless/Node 实例生命周期；每个实例都有独立 MySQL Pool 和后台 worker。
- mysql2 当时默认 `maxIdle === connectionLimit`，60 秒 `idleTimeout` 的清理任务实际没有启动；Sleep 连接按实例水位累积。
- pause-close 先等识别和 MySQL 用量写入，再释放云租约；数据库拥塞反过来拖慢资源释放。
- SDK stop 回调没有有界 fallback，Key 的 half-open 探针也可能长期占住恢复机会。
- ASR 看门狗在 MySQL 埋点成功后才启动；故障中的依赖阻塞了保护机制本身。

✅ **pre-mortem 后的硬方案**：

- 给外层会话设置符合多设备需求的服务端上界和短交接窗口，只淘汰明确超额/被接管的旧代。
- 按真正独立云 Resource 管理探针：异常时有限周期主动恢复，健康时不全量扫描，单 Resource 探针单飞且有超时释放。
- 区分持续静音与完全无包；只对长期无包的业务连接释放稀缺 Azure 资源，保留可恢复的外层 WS。
- 先 drain/release 租约和 SDK 资源，再做有界、可失败的 MySQL/埋点收尾；SDK 回调永不返回时强制超时释放。
- 显式验证 Pool 源码启用条件并激活 idle 回收；跨实例清理使用分布式锁，不能只靠进程内时间戳。
- 保护定时器在非关键埋点之前启动；恢复首包使用小型有界缓存，避免为了资源治理牺牲 realtime 体验。
- 修复拆成会话上界、Key 恢复、Pool 防御、空闲释放等独立提交，逐层灰度和回滚。

**教训**：高影响事故通常不是某个 if 写错，而是多个“单看没问题”的局部设计相乘。pre-mortem 必须在 plan 前问系统级最坏上界和失败依赖顺序；事后 review 无法挽回已经发生的直播中断与损失。

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
| "一条 WS 不占数据库连接，保留没关系" | 单 WS 不独占连接，不代表长 WS 不会延长并放大实例；实例 × Pool 水位才是系统上界。 |
| "已经配了 idleTimeout/TTL，资源会自己回收" | 参数可能有额外启用条件；必须核对依赖版本、源码和真实监控曲线。 |
| "SDK close 最终会回调" | 回调永不返回就是必须设计的失败分支；稀缺资源要有本地超时和租约 force-expire。 |
| "为了不影响体验，所有旧连接先保留" | 没有容量上界的“体验保护”会拖垮全体用户；应保留合理多设备空间，并对超额旧代做有证据的淘汰。 |

## 红旗清单（出现就停，回去做 pre-mortem）

- 方案里出现 "取消/删除/作废/覆盖/重置" 等 destructive 动词，却没问"会不会误伤进行中的操作"
- 只描述 happy path，没列**失败/超时/取消/重放/并发**分支
- 把外部系统当同步且可靠（"webhook 会及时到"、"第三方 API 不会挂"）
- 基于 read-then-write 改共享状态（`if status==X then save Y`），没有 CAS/锁
- 状态机只画正向（pending→paid→fulfilled），没画失败/补偿/超时出口
- 用本地时间/本地状态判定"外部已经发生的事"（如本地 pending 判定"Stripe 没收款"）
- 只说“单连接/单实例开销很小”，没有计算 session × process × instance × pool/resource 的乘法上界
- 同时存在客户端、服务端、SDK、worker 重连，却没有重连所有权矩阵、单飞和取消条件
- 稀缺资源释放排在日志/数据库/告警之后，或依赖一个可能永不回调的 SDK callback
- 只配置 timeout/TTL/limit，没有验证当前依赖版本中使其生效的条件
- 计划写了“可灰度”，却没有指标、停止阈值、最小回滚提交和用户体验预算

**以上任一出现 → 停，回十维表；状态/支付至少补第 1/3/5/6 维，实时资源至少补第 1/8/9/10 维再下笔。**

## 和事后 review 的分工

| | 时机 | 干什么 |
|---|---|---|
| **pre-mortem-design（本 skill）** | 设计/plan 阶段 | 让方案生来就硬：结构化排除 race/丢钱/越权等 |
| `code-review` / `security-review` | 实现后 | 兜底查实现是否偏离了已硬化的方案、查漏网之鱼 |

两者**配套**，不可互相替代。设计期没硬度，review 期只能补丁。
