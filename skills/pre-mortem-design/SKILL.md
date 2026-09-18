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
- **Serverless / FC / Lambda 部署**——后台 worker / goroutine / setInterval 不可靠（实例 freeze / recycle），任何"靠 worker 兜底"的链路必须改用 timer + HTTP endpoint
- **错误响应 / 内部信息泄露**——DB 错误、SQL 片段、连接串、stack trace 直接 surface 到客户端响应

**不在这些域**（纯展示、纯读、单进程无状态工具）——别滥用，直接做。

## Pre-Mortem 十维自检（方案定稿前过一遍）

假设方案上线挂了，逐条问"会不会因此挂"：

| 维度 | 要回答的问题 | 挂的方式 |
|---|---|---|
| **1. 并发/race** | 两个请求/进程/webhook/设备**同时**操作同一资源会怎样？check-then-act 有没有 TOCTOU 窗口？ | 抢座超卖、重复扣款、双开结账 |
| **2. 幂等** | 同一操作**重复**执行（重试/双击/网络重放/webhook 重复投递）结果一致吗？幂等 reservation/lock 是否覆盖 fresh pending、stale pending、succeeded、provider failure、进程崩溃恢复？ | 重复 enrollment、重复退款、重复扣款、同一 key 永久卡死 |
| **3. 原子性/CAS** | 状态转换是 `UPDATE ... WHERE status='X'`（条件更新）还是 read-then-write？跨进程的竞态有没有 DB CAS/锁兜底？ | 丢失更新、覆盖了他人的转换 |
| **4. 状态机完备** | 所有状态、所有转换（含**失败/超时/取消/补偿/回滚**）都定义了？有死状态/不可达/卡死状态吗？ | 卡 pending 永不流转（见反面例子） |
| **5. 源真相对齐 ⭐** | 本地状态 vs 外部系统（Stripe/第三方/DB）**谁是 source of truth**？本地状态会不会**滞后**外部？**仅凭本地状态"作废/取消/判定已死"安全吗？** 每个会阻断用户动作或否决资金/履约的本地状态，**有没有一条真的能走通的收敛出口**（自动/管理端/回调）？ | 误取消"已付款但本地未翻转"的单（见反面例子）；用户/资金被本地判死且**永久无出口** |
| **6. 失败兜底/对账** | 支付成功但履约失败？webhook 丢失/延迟/乱序？钱或数据**会不会丢**？有没有 `requires_review`/对账/重放兜底？stale pending 是安全恢复、人工复核，还是永久阻塞/粗暴释放？ | 客户被扣款却没拿到货、静默丢支付、二次扣款 |
| **7. 安全** | 鉴权/越权/IDOR/注入/敏感数据/重放？destructive 操作校验归属了吗？用户可控 metadata/JSON/map merge 会不会覆盖 server-owned keys（如 `idempotency_key`/`status`/`customer_id`/`recovery_*`）？ | 越权取消他人订单、数据泄漏、幂等查询被污染 |
| **8. 资源乘数/容量上界** | 资源按 request/session/user/process/instance/key/provider 各分配多少？独立重试、worker、pool 相乘后的**系统级最坏上界**是多少？队列和池饱和后是排队、拒绝还是继续扩实例？ | 单连接看似便宜，扩成数百云并发、数百 Sleep 连接、重试风暴 |
| **9. 生命周期/释放顺序** | socket/lease/timer/pool/worker 谁 create→renew→drain→release→force-expire？SDK 回调永不返回怎么办？日志/DB/告警失败会不会挡住稀缺资源释放和安全看门狗启动？ | 孤儿会话、半开死锁、资源已无业务价值却占到一小时上限 |
| **10. 可观测/灰度/回滚** | 哪些指标证明方案有效？灰度单位、停止条件、最小回滚提交是什么？监控是否能区分真实业务增长、内部放大和攻击？ | 全量上线后才发现延迟/资源继续爬升，只能整体回滚或停服 |

**第 5 维（源真相对齐）是最容易被漏的**——下面的反面例子就是。

### 终态出口矩阵（第 5/6 维的落地检查）⭐

方案里对**每一个会阻断用户动作、或会否决资金/履约**的本地状态，逐行填这张表；填不出来就是方案没定稿：

| 本地状态 | 渠道侧是否仍可能成功？ | 冲突时谁赢（渠道事实 vs 本地判定）？ | 收敛路径（自动 / 管理端 / 回调，写具体接口或任务） | 没有出口时的最坏影响 |
| --- | --- | --- | --- | --- |
| PENDING / INITIATED | 是 | 渠道 | 自动查单 / 回调 | 用户等待 |
| 人工复核（如 REQUIRES_REVIEW） | 不确定 | 渠道确认成功 > 本地 | **必须写出一条**（管理端查单 / 迟到回调 / 超时兜底） | 无人处理 → 用户被永久锁死 |
| 本地判死（如 FAILED） | 可能（迟到成功） | 渠道确认成功 > 本地 | 迟到成功必须能收敛并继续履约 + 冲突审计 | 钱已收、货不发，只能手工修库 |

硬规则：

- **没有收敛路径的终态 = P1**。"我们停止等待、转人工复核"这类状态最容易变成永久锁门：它看起来是终态，业务上却必须留一条自动或管理端出口，而且要在方案里**点名该出口并证明它对该状态可用**（不是"审计留痕了"就算出口）。
- **审计兜底 ≠ 出口**：能查到事实，不等于能把钱或货补上。写"由人工处理"时，必须指出具体动作（哪个接口/按钮/工单），并说明它在该状态下真的能执行；只在 N 天后可用、或需要手工改库的，要显式标注为风险。
- **本地判定只允许"中断等待"，不允许"否决渠道事实"**：渠道已确认成功时，本地 `FAILED` / `已取消` 只能作为冲突审计与人工追溯，不能成为拒绝履约的理由。
- **阻断集合不许用 `<> X` 表达**：未知/新增取值会默认放行。必须写成显式集合，并配"穷举全部取值逐一断言分类"的用例，新增取值不分类即测试失败。
- 反向也要查：本地成功态会不会被过期失败通知回退？门禁查询与放行查询是否共用同一份状态口径（两处各写一份必然漂移）。

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

## 跨地域数据库专项检查

应用与数据库跨地域且方案新增或合并持久化结构时，plan 必须以在线路径 SQL RTT 和数据职责为依据：

- **表数不是性能指标**：性能判断看每个在线请求新增的串行 SQL 网络往返、事务和锁等待；不能用“表更多/更少”直接推导延迟改善或退化。
- **新表影响矩阵**：每张新表一行，列出生命周期、所有权、预估基数、运行时读写方、访问频率、是否位于在线请求路径、每请求新增串行 SQL 轮次、锁范围、索引与清理/归档策略，以及复用现有表或部署/迁移流程的替代方案。
- **一次性状态不进热路径**：迁移状态、`READY` 标记和一次性校验优先由部署、迁移或 CI 承担；无运行时安全理由不得新增热路径查询。
- **持久化必须有理由**：新持久表至少要服务于审计、崩溃恢复、并发协调或运行时安全之一；否则优先改部署流程或使用短生命周期产物。
- **合并也要算成本**：合并表必须评估锁竞争、索引膨胀和生命周期耦合，不能把“少一张表”当成天然优化。
- **JSON 有硬边界**：需要独立查询、唯一约束、CAS/事务或支付审计的核心状态不得塞进 JSON；JSON 只承载不参与这些一致性约束的附属数据。

## Serverless / FC 专项检查

部署在阿里云 FC / AWS Lambda / Cloudflare Workers 等 serverless 平台时，plan 必须明确：

- **后台 worker 不可靠**：FC 按量实例无请求时 CPU 冻结；进程内 `go worker.Run()` / `setInterval` / `Timer` 都可能被 freeze 或实例 recycle 中断。**任何"靠 worker 兜底"的 correctness 链都是不可靠的**。
- **正确架构 = timer + HTTP endpoint**：用平台定时触发器调内部 HTTP endpoint（如 `/internal/cron/reconcile-*`），每次调用即起即收，匹配 serverless 模型。后台 goroutine 仅作开发环境优化，生产由 timer 驱动。
- **timer endpoint 鉴权**：必须三重鉴权——HMAC-SHA256(timestamp+nonce+body) 用 `hmac.Equal` 常量时间 + timestamp ±5min 窗口（防长期重放）+ nonce 5min 去重（防短期重放）。仅 IP 白名单不可靠（serverless 出口 IP 不固定）。
- **配置面最小化（少造新 env/secret）⭐**：新增 timer/endpoint 时，HMAC secret、签名函数、nonce 缓存、lease 模式**必须优先复用既有设施**（同一 secret 盖多个 endpoint，nonce 缓存跨 endpoint 共享反而更安全）。新增**必需**环境变量/密钥/控制台配置，必须在方案里显式论证"为何无法复用"；缺省答案是**零新增**。配置项是部署失误乘数：每个必需项漏配 = fatal 或 fail-open 一次事故，且运维要在更多地方找配置。端点可以按"节奏 × 灰度状态 × 爆炸半径"拆（稳态与 DRY_RUN 观察期不合并），但**管理面**（secret/鉴权/签名设施）必须收敛。
- **timer endpoint DoS 防护**：body 用 `http.MaxBytesReader` 限上限（如 4-32KB），否则攻击者发 GB 级伪造请求 OOM 函数。
- **多实例并发**：FC 可能多实例处理同一 timer event。reconcile 入口必须复用 DB lease 跨实例互斥；rate limiter / nonce cache 仅单实例有效，需明确这是兜底而非唯一防线。
- **分布式 ID 撞号**：snowflake / uuid-with-nodeid / 自增 counter 等进程本地 ID 生成器在多实例下节点 ID 撞号会生成相同 ID。env 注入实例 ID 或用无协调 UUID。
- **函数 timeout 预算**：webhook 同步处理总时间（验签 + 主动查单 + 履约）必须 < 平台函数 max duration 且 < webhook 重发阈值。否则 ACK 没发触发重发风暴。
- **凭证阻塞识别**：sandbox / 测试凭证不可达时，所有"对外部 API 行为"假设（签名算法、字段名、幂等性）必须明确标 P0 阻塞，不冒充验证。单测只证"自洽性"不证"与真实 provider 一致"。

**关键失败模式**（来自 KingLuckyRealtime V2 Onerway 接入）：
- `RunOnce`（cron 调用）原本无 lease → 多 FC 实例并发 timer 重复查单浪费 provider 配额
- snowflake 节点 ID 写死 → 多实例撞号导致 merchantTxnId 重复被 provider 拒
- webhook body 无大小限制 → 攻击者发伪造 webhook（无需通过签名，body 在验签前读）OOM 函数
- ACK-first vs 同步处理：webhook 重发阈值通常很宽（Onerway 30min），同步处理（含主动查单）只要 < 函数 timeout（FC 通常 60s）就无需 ACK-first

## 错误响应 sanitize 专项检查

handler / service 返回错误时，plan 必须明确：

- **内部错误绝不进响应体**：DB 连接串、SQL 片段、表名、gorm/ORM 内部错误、stack trace 都不能直接 `c.JSON(500, "error": err.Error())`。
- **sentinel 错误分类**：service 层用 sentinel（`ErrNotFound`/`ErrUnauthorized`/`ErrConflict`/`ErrInternal`）+ `fmt.Errorf("internal: %w", err)` 标记内部错误。
- **集中 HTTPErrorHandler**：web 框架统一拦截，sentinel 映射 HTTP 状态 + 安全消息；带 "internal:" 前缀的统一返 500 + 通用消息 + requestID。
- **RequestID 关联**：响应体只返 requestID；服务端日志按 requestID 存完整错误堆栈；客户端报问题提供 requestID 给运维查。
- **API 响应 envelope**：固定 `{code, message, data, requestId}`，message 来自错误码字典而非 `err.Error()`。
- **审计现有代码**：`grep -rn "err\.Error()" api/handlers/` 找直接 surface err 的 handler；内部 endpoint（cron / webhook）也审计，"反正内部用"不是借口。

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
| "新功能配新 env / 新 secret，各管各的更清晰" | 配置面是部署失误乘数：漏配一个 = fatal 或 fail-open。secret/签名/lease 等管理设施必须复用收敛；新增必需项默认零，要加先论证复用不可行。 |
| "跨地域慢是因为表太多，赶进度先都塞进一个 JSON" | 表数不决定请求 RTT；应比较在线路径的串行 SQL 轮次和数据职责。JSON 会丢掉查询、唯一约束、CAS/事务与支付审计能力。 |

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
- 方案顺手新增 env / secret / 控制台配置，却没先问"既有配置（共享 secret、既有开关）能否复用"
- 用表数量判断跨地域性能，或把需要查询、唯一约束、CAS/事务、支付审计的核心状态机械合并进 JSON

**以上任一出现 → 停，回十维表；状态/支付至少补第 1/3/5/6 维，实时资源至少补第 1/8/9/10 维再下笔。**

## 和事后 review 的分工

| | 时机 | 干什么 |
|---|---|---|
| **pre-mortem-design（本 skill）** | 设计/plan 阶段 | 让方案生来就硬：结构化排除 race/丢钱/越权等 |
| `code-review` / `security-review` | 实现后 | 兜底查实现是否偏离了已硬化的方案、查漏网之鱼 |

两者**配套**，不可互相替代。设计期没硬度，review 期只能补丁。
