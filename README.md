# video-pipeline

短视频一条龙脚本引擎。从选题策划到分镜脚本、视频生成提示词、封面图提示词、多平台发布包、数据复盘的完整工作流技能。

**定位**：[脚本引擎] —— 只输出脚本、分镜、提示词与发布包，不产出视频文件。生视频由用户在即梦、可灵、Sora 等工具中手动完成。

---

## 架构特点

- **分层默认发布**：不默认全量输出 14 个平台，先给平台优先级建议，用户确认后才生成对应平台包。
- **参数化模型**：`模型=seedance|hailuo|全部`，默认只输出单模型提示词，避免三套全量输出浪费 Token。
- **阶段落盘**：第 1-4 步成果写入 `workspace.md`，第 5 步只读 workspace + 规则文件，切断历史对话上下文。
- **按需加载**：启动只读 SKILL.md 和 model-limits.yaml，赛道切片、风格权重、模型细节等命中才读。
- **固定装载顺序**：SKILL → track-core → multi-model → common-variables → 切片 → 模板，最大化 Prompt Caching 命中率。

---

## 目录结构

```
skill-update/
├── SKILL.md                          # 主路由：硬边界、装载顺序、5步流程、评分卡
├── README.md                         # 本文件
├── 使用教程.md                        # 面向使用者的操作手册
├── feedback-library.md               # @复盘反馈经验库
├── config/
│   └── model-limits.yaml             # 模型能力上限（唯一数据源）
├── references/
│   ├── track-core.md                 # 编译核心：固定叙事链、风格基线、B站公式
│   ├── multi-model-prompt.md         # 模型=路由、导演台、修正注入、输出格式
│   ├── platform-publishing.md        # 分层默认路由、平台池、紧凑字段行
│   ├── sensitive-words.md            # 敏感词库过滤器
│   ├── segment-split.md              # 拆段公式（段数=CEILING(时长/上限)）
│   ├── style-weight.md               # 风格权重表 + 负面词注入
│   ├── character-card.md             # 真人主体 CHARACTER_CARD 结构
│   ├── presets.md                    # 8 个快捷预设定义
│   ├── tracks/                       # 10 个赛道切片（按需加载）
│   │   ├── travel-vlog.md
│   │   ├── personal-growth-vlog.md
│   │   ├── personal-experience.md
│   │   ├── advertising.md
│   │   ├── live-commerce.md
│   │   ├── promo.md
│   │   ├── travel-promo.md
│   │   ├── fpv.md
│   │   ├── outdoor-documentary.md
│   │   └── past-narrative.md
│   └── ...                           # 其余条件加载参考文件
├── templates/
│   └── by-track/                     # 各赛道输出模板 + 公共变量
└── scripts/
    ├── scan_sensitive_words.ps1      # 敏感词扫描（PowerShell，ASCII 源码）
    └── replication_frames.ps1        # 链接复刻每秒帧索引建立
```

---

## 快速开始

最简单的触发方式，在对话里说一句：

```
做一条旅行Vlog，主题是重庆3天2晚
```

或用快捷预设：

```
@产品广告 15秒 16:9 模型=hailuo 主题是一款平价精华液
```

技能自动输出第 1-4 步：选题策划 → 分镜脚本 → 视频生成提示词 → 封面图提示词。

剪辑完成后说 `剪完了`，技能进入发布包确认流程：先给 `[平台优先级建议]`，等你确认平台名单后只输出指定平台包 + 自查评分卡。

## 常用参数

| 参数 | 说明 |
|---|---|
| `模型=seedance` | 默认，只出豆包 Seedance 2.5 |
| `模型=hailuo` | 只出海螺 Hailuo 3 |
| `模型=全部` | 三套都出（成本最高） |
| `风格强度=0-100` | 0 纯写实，100 纯超现实科幻 |
| `节点=口播` | 跳过起承转合，适合带货/种草 |
| `热点词=A,B,C` | 必填，不填会留占位提醒 |
| `叙事密度=低/中/高` | 单产品展示为低，多事件多转折为高 |
| `平台=主流3` | 抖音、小红书、视频号 |
| `平台=出海` | TikTok、Instagram、YouTube 等 7 个 |
| `平台=全量` | 全部 14 个平台 |

## 链接复刻

```
复刻这个链接：https://www.douyin.com/video/xxxxx
```

- 只提供链接：标注 `[缺乏原片素材]`，只提炼结构骨架做风格仿写。
- 提供本地原片路径：逐秒对位复刻，先用 `scripts/replication_frames.ps1` 建立秒桶索引。

## 数据复盘

```
@复盘 播放12万，完播率38%，点赞2300
```

技能做归因分析并把结论存入 `feedback-library.md`，下一轮生成自动注入修正。

---

## 平台池（14 个）

国内：抖音、快手、小红书、视频号、微博、B站

海外：TikTok、Instagram、Facebook、YouTube、Threads、X、Pinterest、U Lifestyle

---

## Token 消耗优化记录

| 优化项 | 效果 |
|---|---|
| 赛道切片按需加载 | 启动不再读全部 8+ 参考文件 |
| `模型=` 参数化 | 单轮输出减 4-8K tokens |
| 阶段落盘切断历史 | 第 5 步不携带前 4 步对话全文 |
| 分镜 10 列→7 列 | 表格 Token 减约 30% |
| 固定装载顺序 | Prompt Caching 命中，输入费用降 10-25% |
| 发布包分层默认 | 杜绝 13 平台全量输出的极端场景 |
