# 角色与 BD 构筑深化 v0.1

## 目标
角色设计要服务三个层次：

- 第一眼：玩家看到立绘和 UI，就知道这个角色大概怎么玩。
- 第一场：玩家掷几回合 D6，就能理解核心资源和风险。
- 第一轮 Run：玩家能通过奖励、装备、附魔和敌人压力，形成至少两种明显不同的 BD。

本项目的构筑单位是 D6，不是散装技能。角色深度来自：
- 选择带哪些 D6。
- 选择保留哪些负面面。
- 用附魔强化哪一面。
- 用装备把某个标签变成引擎。
- 根据敌人意图决定结算顺序和重骰策略。

## 全局 BD 原则

### 1. 每个角色要有“强但有代价”的爽点
- Cyan 的爽点是多段远程和 Overload 爆发，代价是过载锁骰、自伤和资源被抽。
- Helios 的爽点是 Mark 点杀和 Quiver 循环，代价是标记会被清、箭袋会断、铺垫回合偏脆。
- Aurian 的爽点是格挡反击和处决大回合，代价是启动慢、Stance 被抽会空转、自伤路线要求血量管理。

### 2. 每条 BD 至少有 3 个支点
一条 BD 不应该只靠一颗骰子成立。最低应由以下三类支点组成：
- 核心 D6：提供主要玩法。
- 支撑奖励：新增/替换/升级 D6 或附魔。
- 外部支点：装备、事件、补给、休息、敌人意图窗口。

### 3. 敌人必须能考到 BD，但不能废掉 BD
敌人可以：
- 抽资源。
- 清标记。
- 扣重骰。
- 锁骰。
- 给护甲。
- 压召唤。

敌人不应该：
- 永久禁止某类构筑。
- 无预兆清空玩家所有准备。
- 让某角色连续多回合没有可做决策。

## Cyan Ryder

### 角色定位
Cyan 是“高科技远程引擎”。他应该给玩家一种高速、精准、危险的感觉。

关键词：
- Overload
- 多段攻击
- 远程平伤
- 冷却
- 重骰
- 无人机/科技装备

### 核心资源：Overload
Overload 应该是“越用越强但不能一直满载”的资源。

设计要求：
- 低 Overload：输出稳定但不夸张。
- 中 Overload：远程面开始变强。
- 高 Overload：爆发明显，但会锁骰、自伤或被敌人抽资源。

玩家应该经常面对：
- 现在爆发，还是先冷却？
- 这回合要不要重骰找远程面？
- 敌人下回合要抽资源，我要不要提前花掉 Overload？

### BD A：Reactor Burst / 反应炉爆发
玩法：
- 快速堆 Overload。
- 用远程多段攻击吃平伤收益。
- 在敌人高压前一回合打出爆发。

核心 D6：
- `cyan_core_die`
- `cyan_pulse_die`

关键奖励：
- `upgrade_die`：把稳定 D6 换成高风险 Core。
- `grant_enchant`：Overload Capacitor。
- `equipment`：Pulse Carbine / Heat Sink Plating。

风险：
- 锁骰导致下回合选择减少。
- Overload 被抽会损失爆发窗口。
- 自伤会压低容错。

敌人反制：
- Vanguard 抽资源。
- Howler 深层资源压迫。
- Stalker 扣重骰，导致冷却面更难找。

### BD B：Prism Control / 棱镜控制
玩法：
- 通过 Shift、Vent、重骰、护甲稳定节奏。
- 不追求极限爆发，而是每回合都把坏骰修正成可接受结果。

核心 D6：
- `cyan_shift_die`
- `cyan_pulse_die`

关键奖励：
- `add_die`：额外 Shift Die。
- `remove_negative`：清理 Core 风险。
- `equipment`：Lucky Knuckle / Risk Ledger。

风险：
- 输出峰值低。
- 遇到重骰税敌人会掉节奏。

敌人反制：
- Reef Stalker 扣重骰。
- Howler 锁骰。

### BD C：Drone Fireline / 无人机火线
玩法：
- 后续引入 summon/drone D6 后成立。
- 通过远程、多段、mark 和召唤标签形成副输出轴。

当前阶段处理：
- 先保留接口，不强行完整实现。
- 装备 `Micro Drone Dock` 和 `Companion Whistle` 先作为未来 BD 支点。

美术/UI表达：
- 立绘突出蓝龙舰长、战术内衬、光束武器。
- UI 色彩偏蓝青、高亮线框、科技屏幕感。
- Dice 卡片可以强调“Overload 当前值”和“冷却风险”。

## Helios Windchaser

### 角色定位
Helios 是“猎人节奏与点杀规划”。他不是单纯射手，而是用 Mark、Quiver 和路线判断来兑现大伤害。

关键词：
- Mark
- Quiver
- Precision
- Trap
- Companion
- Pierce

### 核心资源：Quiver
Quiver 是“弹药和节奏”的混合资源。

设计要求：
- 强攻击消耗 Quiver。
- 回收面和标记收益恢复 Quiver。
- Quiver 为 0 时不是死局，但行动效率明显下降。

玩家应该经常面对：
- 现在消耗箭矢打伤害，还是先回收？
- 标记要叠高，还是尽快兑现？
- 敌人要清标记时，要不要提前打掉？

### BD A：Marked Execution / 标记处决
玩法：
- 先铺 Mark。
- 用 Pierce / Sniper 兑现单体爆发。
- 把敌人护甲、减伤和高 HP 转化为“点杀目标”。

核心 D6：
- `helios_mark_die`
- `helios_hunt_die`

关键奖励：
- `grant_enchant`：Marking Rune / Quiver Thread。
- `replace_die`：Mark -> Hunt 或 Hunt -> Wild。
- `equipment`：Hunter Scope。

风险：
- 标记被清会损失铺垫。
- Quiver 断档时爆发面只能打最低效果。

敌人反制：
- Stalker 清标记。
- Howler 清标记并抽资源。

### BD B：Skirmish Loop / 游击循环
玩法：
- 不追求单次最大伤害，而是通过低空掠过、回收、陷阱和补箭保持连续输出。
- 适合对抗锁骰和扣重骰，因为单面失败不至于断整套。

核心 D6：
- `helios_hunt_die`
- `helios_wild_die`

关键奖励：
- `add_die`：额外 Mark/Hunt D6。
- `remove_negative`：Steady Wild Path。
- `equipment`：Lucky Knuckle / Field Jacket。

风险：
- 爆发不足。
- 遇到高护甲敌人会被拖长。

敌人反制：
- Vanguard 护甲姿态。
- Stalker 扣重骰。

### BD C：Companion Hunt / 伙伴猎杀
玩法：
- 后续以 summon/companion 为副轴。
- 伙伴吃 Mark、装备和附魔收益。

当前阶段处理：
- `Companion Whistle` 先作为主动道具接口。
- 敌人已有 `disable_summon` 压力，用于未来测试。

美术/UI表达：
- 立绘突出狮鹫游侠、羽毛、罗马/DND 皮甲。
- UI 色彩偏金、风、羽翼、标记准星。
- Dice 卡片应突出 Mark 层数、Quiver 当前值、消耗/回收关系。

## Aurian

### 角色定位
Aurian 是“重型战士与承压爆发”。他不应该像普通坦克只挨打，而是通过 Stance、格挡、反击和处决把压力变成输出。

关键词：
- Stance
- Guard
- Counter
- Charge
- Execute
- Self-damage

### 核心资源：Stance
Stance 是“站稳之后才爆发”的资源。

设计要求：
- 防御和蓄力获得 Stance。
- 处决和爆发消耗 Stance。
- Stance 被抽时不会让玩家完全没事做，但会延迟大回合。

玩家应该经常面对：
- 这回合要防御攒 Stance，还是提前打小伤害？
- 敌人高攻回合要不要用防反吃收益？
- 血量够不够支持自伤路线？

### BD A：Iron Counter / 铁壁反击
玩法：
- 护甲、防反、荆棘、Stance。
- 敌人攻击越强，Aurian 的反击窗口越大。

核心 D6：
- `aurian_guard_die`
- `aurian_blade_die`

关键奖励：
- `equipment`：Iron Banner / Spiked Guard / Guardian Totem。
- `grant_enchant`：Stance Oath。
- `growth`：开局护甲。

风险：
- 敌人不攻击或清 counter 时空转。
- 输出依赖敌人意图窗口。

敌人反制：
- Vanguard 的 Cleave the Guard。
- Howler 抽 Stance。

### BD B：Oath Execution / 誓约处决
玩法：
- 蓄力、攒 Stance、等待大回合。
- 用 Ignore Block / Multiplier / Execute 收束。

核心 D6：
- `aurian_blade_die`
- `aurian_might_die`

关键奖励：
- `upgrade_die`：Aurian Might Path。
- `replace_die`：Guard -> Blade。
- `equipment`：Throwing Harness / Blood Whetstone。

风险：
- 前两回合偏慢。
- 被锁骰或抽 Stance 会错过爆发。

敌人反制：
- Howler 锁骰与抽资源。
- Stalker 快速攻击压低血量。

### BD C：Blood Price / 血价狂战
玩法：
- 主动接受自伤和负面面。
- 用自伤触发装备、附魔和高伤害。
- 在低 HP 压力下做风险判断。

核心 D6：
- `aurian_might_die`

关键奖励：
- `equipment`：Blood Whetstone / Heat Sink Plating。
- `grant_enchant`：Negative Focus。
- `remove_negative`：作为保守分支，给玩家回头路。

风险：
- 血量管理失败会暴毙。
- 需要清楚的 UI 提示自伤和收益。

敌人反制：
- Vanguard 锁负面面。
- Howler 抽资源，拖慢收束。

美术/UI表达：
- 立绘突出黑龙、厚重板甲、巨大重剑、沉默誓言。
- UI 色彩偏铁黑、炭火、金属边框。
- Dice 卡片应突出 Stance、下一击倍率、反击状态和自伤代价。

## 奖励池深化方向

### 通用奖励
- 新 D6：改变概率结构。
- 替换 D6：从稳定转爆发，或从风险转稳定。
- 附魔：强化关键面。
- 装备：引入跨角色标签联动。
- 补给/休息：提供下一场临时安全垫。

### Cyan 专属奖励
- Overload 上限变化。
- 冷却收益提高。
- 多段面平伤提高。
- 过载惩罚降低但爆发降低的安全路线。

### Helios 专属奖励
- Mark 不易被清。
- 消耗 Quiver 后返还。
- 首次精确射击强化。
- 标记转护甲/护甲转标记的游击路线。

### Aurian 专属奖励
- Stance 获得效率提高。
- 处决消耗降低。
- 防反收益提高。
- 自伤转护甲/伤害的狂战路线。

## 后续实现优先级

1. UI 显示角色核心资源说明。
2. Reward 卡片显示“适合哪个 BD”。
3. 每名角色补 2-3 个专属奖励。
4. 每名角色补 1 个专属附魔。
5. 敌人根据 BD 标签补更多反制预兆。
6. Hub 关系奖励转为解锁专属 D6 / 装备 / 附魔。

