---
name: video-pipeline
description: 短视频一条龙工作流。当用户说"做一条【类型/赛道】，主题是【XXX】"（类型可省略，自动推荐候选赛道）、"复刻这个链接：[链接]"，或提到旅行、个人成长、个人经历、往事、FPV、广告片、TVC、PV/PVC、宣传片、旅行宣传片、户外纪实、口播带货、种草，或要求短视频选题、分镜、豆包 Seedance/MiniMax Hailuo 3提示词、封面提示词、多平台发布包或视频数据复盘时使用。
---

# 短视频一条龙

## 定位与硬边界

- 主赛道：旅行Vlog、个人成长Vlog、个人经历、广告片、PV/宣传片、旅行宣传片、FPV、户外纪实。兼容赛道与叙事模式：TVC、PV/PVC、口播带货、种草；往事/人物追踪是横跨赛道的叙事模式。
- 平台池：抖音、快手、小红书、视频号、微博、B站、TikTok、Instagram、Facebook、YouTube、Threads、X、Pinterest、U Lifestyle。
- 从视频逻辑从零执行，不套用图文或公众号工作流。
- 不调用任何生视频API；只输出提示词和发布包，生视频由用户在即梦、可灵、Sora等工具中手动完成。
- 本技能定位为[脚本引擎]：只负责脚本、分镜、提示词与发布包，不产出视频文件。
- 常规流程强制执行四步确认流：先赛道、后主题、再参数（选配确认单）、最后生成；每一步同时提供AI推荐和用户自定义入口，未经确认禁止生成。平台名单在选配确认单中确认后，随生成一并输出对应平台包；用户事后追加平台或生成时未确认平台时，仍按“先推荐、再确认、后输出”执行。
- 第5步禁止未经用户确认输出任何发布包代码块，更禁止一次性输出全平台。第1步只确定1-3个首发重点；确认后的平台必须按其画幅、语感、标签、SEO关键词、互动和分享规则重写，禁止一稿多投。
- 链接复刻只保留结构、节奏、镜头、光影、情绪和互动逻辑，不复刻人物、文案、品牌和专有内容。
- 默认创意结构强制套用 [references/track-core.md](references/track-core.md) 的固定叙事链：“现实压力锚点 -> 幻想种子 -> 微缩奇观 -> 触发物穿越 -> 主体登场 -> 动作证明 -> 收口 -> 现实回声”。链接复刻时原片结构优先，非复刻片禁止跳过固定叙事链；同时保留“B站双参考结构公式”作为骨架校验。
- 风格强度滑块（0-100）：用户可用`风格强度=N`指定，N=0纯写实，N=100纯超现实科幻；仍兼容`视频风格=纯写实/超现实科幻`。默认强度按预设或赛道决定；乡村生活、纯自然纪实等无奇幻内容自动设为0并告知用户。具体权重、影响范围和负面提示词注入按 [references/style-weight.md](references/style-weight.md) 执行。
- 模型能力限制（单段时长上限、参考素材上限、H3模式列表）从 [config/model-limits.yaml](config/model-limits.yaml) 读取，不在技能逻辑中硬编码；模型版本更新时只改YAML文件。每次技能启动输出第一行强制打印：`[脚本引擎] video-pipeline v2 | 当前适配模型版本见 config/model-limits.yaml 适配日期，若模型更新，请前往config文件更新参数`。当前日期距YAML适配日期超过60天时，输出第一行前追加：`[提醒] 模型参数已超60天未更新，请核实`。
- 启动检查：新对话开始时若当前工作区存在`workspace.md`或`workspace-*.md`，先读取文件摘要（片名、赛道、所选模型、镜头区间、已确认平台），并询问用户“继续上片还是开新片”。用户确认开新片后按阶段落盘规则新建文件；禁止静默覆盖或静默续写。

## 资料路由（按需加载）

启动阶段只读本文件和 [config/model-limits.yaml](config/model-limits.yaml)，其余参考文件按路由懒加载：命中才读、未命中禁止读，禁止一次性读完全部参考文件。

固定装载顺序：①SKILL.md → ②track-core.md → ③multi-model-prompt.md → ④common-variables.md → ⑤命中切片 → ⑥命中模板。①-④是稳定缓存前缀；两轮对话之间不要修改这四个核心文件，否则会降低Prompt Caching命中率。正常命中时输入费用通常可降10-25%，具体以当前模型计费策略为准。

- 未指定赛道时读取 [references/track-routing.md](references/track-routing.md)，将其候选与置信度结果仅作为第一步“确认赛道”的推荐依据；用户指定赛道时不读取该文件。
- 极简模式（条件短路）：总时长不超过15秒且叙事密度为低且主题为单镜头产品特写或单场景展示时，自动触发极简模式，固定叙事链压缩为3节点：【吸引注意】+【核心展示】+【行动呼吁】，跳过中间起承转合节点；分镜同步压缩为1-2镜；每个模型代码块开头标注`[极简模式]`，`[固定叙事链]`字段映射为3节点极简链。叙事密度参数：用户可用`叙事密度=低/中/高`指定，未指定时按主题自动判断（单产品展示/单一情绪为低，多事件/多转折为高）。不满足触发条件时仍走完整八节点链路。
- 节点跳过参数：用户可用`节点=口播`强制把固定叙事链压缩为【钩子】+【痛点/价值证明】+【行动呼吁】三节点，跳过起承转合；`节点=极简`等价于强制触发极简模式。口播带货、种草、广告片等非叙事类赛道默认允许`节点=口播`；叙事类赛道（旅行Vlog、个人成长Vlog、个人经历、PV/宣传片、旅行宣传片、FPV、户外纪实）仅在用户显式指定时启用，启用时输出第一行打印：`[节点=口播] 已跳过起承转合节点，按钩子+痛点/价值+行动呼吁三节点输出。`
- 人物追踪往事反差模式：用户提到“跟踪人物运镜”“带入生活往事”“往事”“切入痛点反差”“用视觉画面音效吸引观众”或类似要求时，分镜与提示词强制进入“现实动作线+生活往事闪回+痛点反差+声音驱动”结构，并在FPV里使用无人机/POV追踪人物；按 [references/video-pipeline.md](references/video-pipeline.md) 的“人物追踪往事反差模式”和 [templates/by-track/fpv.md](templates/by-track/fpv.md) 的对应模板执行。
- 固定装载清单（每次常规生成/链接复刻/极简模式必读，共4项）：① [references/track-core.md](references/track-core.md)（编译核心：固定叙事链、风格基线、B站公式、输出骨架、镜头级模板、质量红线）；② [references/multi-model-prompt.md](references/multi-model-prompt.md)（硬边界、`模型=`路由、导演台、修正注入、输出格式、编译前检查）；③ [templates/by-track/common-variables.md](templates/by-track/common-variables.md)；④ 对应赛道切片+赛道模板（见下条映射）。所有赛道都按 track-core 的参考稿结构输出选题、角色、镜头、提示词和发布信息。
- 赛道切片映射（只加载命中行，禁止读其他赛道切片）：旅行Vlog→[references/tracks/travel-vlog.md](references/tracks/travel-vlog.md)+[templates/by-track/travel-vlog.md](templates/by-track/travel-vlog.md)；个人成长Vlog→[references/tracks/personal-growth-vlog.md](references/tracks/personal-growth-vlog.md)+[templates/by-track/personal-growth-vlog.md](templates/by-track/personal-growth-vlog.md)；个人经历→[references/tracks/personal-experience.md](references/tracks/personal-experience.md)+[templates/by-track/personal-growth-vlog.md](templates/by-track/personal-growth-vlog.md)叠加[templates/by-track/personal-experience-patch.md](templates/by-track/personal-experience-patch.md)；广告片/TVC/品牌片→[references/tracks/advertising.md](references/tracks/advertising.md)+[templates/by-track/advertising.md](templates/by-track/advertising.md)+[references/advertising-reference.md](references/advertising-reference.md)；口播带货/种草→[references/tracks/live-commerce.md](references/tracks/live-commerce.md)+[templates/by-track/advertising.md](templates/by-track/advertising.md)+[references/advertising-reference.md](references/advertising-reference.md)；PV/PVC/宣传片→[references/tracks/promo.md](references/tracks/promo.md)+[templates/by-track/promo-pv-travel.md](templates/by-track/promo-pv-travel.md)；旅行宣传片→[references/tracks/travel-promo.md](references/tracks/travel-promo.md)+[templates/by-track/promo-pv-travel.md](templates/by-track/promo-pv-travel.md)叠加[templates/by-track/travel-promo-patch.md](templates/by-track/travel-promo-patch.md)；FPV→[references/tracks/fpv.md](references/tracks/fpv.md)+[templates/by-track/fpv.md](templates/by-track/fpv.md)；户外纪实→[references/tracks/outdoor-documentary.md](references/tracks/outdoor-documentary.md)+[templates/by-track/outdoor-documentary.md](templates/by-track/outdoor-documentary.md)；往事/人物追踪模式→在当前赛道切片后叠加[references/tracks/past-narrative.md](references/tracks/past-narrative.md)。
- 条件加载（命中才读）：真人主体→[references/character-card.md](references/character-card.md)；目标时长超过所选模型上限→[references/segment-split.md](references/segment-split.md)；`风格强度>20`或用户显式指定强度→[references/style-weight.md](references/style-weight.md)，其中`风格强度>0`再读[references/surreal-sci-fi-realism-reference.md](references/surreal-sci-fi-realism-reference.md)；`模型=seedance`/`seedance2.0`/`全部`→[references/model-seedance.md](references/model-seedance.md)；`模型=hailuo`/`全部`→[references/model-hailuo.md](references/model-hailuo.md)；仅当需要溯源或校准固定叙事链时→[references/local-racing-dream-reference.md](references/local-racing-dream-reference.md)。
- 提示词硬规则：所有视频生成提示词必须强制覆盖固定叙事链“现实压力锚点 -> 幻想种子 -> 微缩奇观 -> 触发物穿越 -> 主体登场 -> 动作证明 -> 收口 -> 现实回声”，并按赛道替换主体。每个模型代码块开头都要有`[固定叙事链]`字段，用本片具体内容映射八个节点；镜头列表至少一个“穿越/跃迁”镜头，且每个模型提示词都要写清现实锚点、触发物、穿越后世界规则、主体状态变化、产品或情绪落点。口播带货、种草等非奇幻赛道可以把微缩奇观替换成具象奇观，把穿越替换成场景跃迁、注意力切换、产品介入或使用方式切换，但不能省略字段；用户指定`节点=口播`或触发极简模式时，`[固定叙事链]`字段按对应压缩节点映射。
- 音画与人物硬规则：全程保持人物面部、发型、服装、配饰和关键道具连续；微表情必须跟随叙事情绪变化。音效分层递进，跟随固定叙事链节点调整音量、音色、节拍和环境密度，禁止平铺BGM。
- 链接复刻：读取 [references/video-reverse-engineering.md](references/video-reverse-engineering.md)、[references/multi-model-prompt.md](references/multi-model-prompt.md)，并使用对应赛道模板；发布包规则按 [references/platform-publishing.md](references/platform-publishing.md) 执行。
- 发布包：读取 [references/platform-publishing.md](references/platform-publishing.md)；违禁词、事实核查和质量评分仍按 [references/video-pipeline.md](references/video-pipeline.md) 执行，敏感词过滤按 [references/sensitive-words.md](references/sensitive-words.md) 执行。
- 数据复盘：读取 [references/data-feedback.md](references/data-feedback.md) 和 [references/case-study.md](references/case-study.md)。

## 快捷预设模式

用户输入`@预设词`时按 [references/presets.md](references/presets.md) 按需加载8个预设：@日常Vlog、@口播短视频、@产品广告、@剧情短片、@户外纪实、@FPV、@个人经历、@旅行宣传片。预设后可叠加覆盖参数，如`@产品广告 15秒 16:9`只覆盖时长和画幅。未指定预设时按资料路由自动判断。高级自定义参数默认隐藏，用户问"有哪些参数"时才完整输出。

## 常规执行流程

强制执行"先赛道、后主题、再参数、最后生成"的严格审批流程；每一步必须同时提供"AI推荐"和"用户自定义"两个入口，禁止AI擅自做主。

- 可选极速通道：用户显式输入`确认流=极速`时，把赛道、主题、选配参数合并为一张【极速确认单】一次输出，仍必须挂起等待用户回复参数、"确认"或"按推荐来"；未输入该参数时禁止压缩三段挂起确认流。
- **第一步·确认赛道（推荐+自定义）**：用户输入未指定赛道时，推荐2-3个匹配赛道（标星首选）并各附一句推荐理由，末尾追加：`或者，请直接输入您自定义的赛道名称。`输出后立即挂起，等待用户选择或自定义；用户已明确指定赛道时视为已确认，直接进入第二步。原赛道自动判断与置信度公式降级为推荐依据，禁止静默替用户选赛道。
- **第二步·确认主题（推荐+自定义）**：赛道确认后，用户未提供具体主题时，推荐3个候选主题并各附一句话理由，末尾追加：`或者，请直接输入您自定义的主题。`输出后立即挂起等待；用户已提供主题时视为已确认。
- **第三步·选配确认单（推荐+自定义）**：赛道和主题都确认后，禁止直接生成。必须输出【选配确认单】并立即挂起，逐项给出⭐推荐与自定义入口：
  - 目标时长：⭐默认30秒 | 1分钟 | 2分钟 | 3分钟 | 4分钟 | 或自定义时长
  - 目标画幅：⭐9:16（竖屏，适合抖音/小红书）| 备选16:9（横屏，适合B站/风景大片）| 或自定义画幅
  - 风格：列出2-3种并标星推荐（如⭐快节奏打卡、治愈文艺）| 或自定义风格
  - 主角身份：列出2-3种并标星推荐（如⭐穷游大学生、精致打工人）| 或自定义身份
  - 目标平台：⭐推荐抖音、小红书 | 备选B站、视频号 | 或自定义平台
  - 末尾固定提示：`请回复您的选择（如：画幅=16:9，风格=快节奏打卡），或者直接输入您自定义的参数。或者回复"按推荐来"，我立刻生成。`
- **第四步·生成（严格挂起后一次性执行）**：仅在收到明确的赛道选择、主题选择、参数选择或自定义输入、"确认"、"按推荐来"指令后恢复执行；恢复后一口气输出选题策划、分镜脚本、视频生成提示词、封面提示词和发布包，中间不允许再次停顿。发布包只输出选配确认单中已确认的平台（该确认等价于平台名单确认），未经确认禁止输出任何平台代码块。输出完毕立即执行阶段落盘。
- 快捷预设等价于确认赛道与预设默认参数；预设后仍须走选配确认单（预设默认值标星呈现），用户回复确认或"按推荐来"后才生成。用户已随确认单给出的`节点=`、`模型=`等参数直接生效，不再重复询问。

确认后按以下顺序一次性完整输出：

1. **选题策划**：热点词必须来自用户输入（`热点词=A,B,C`）；用户未提供时，选题开头标注`[需手动填入热点词]`并留占位，禁止虚构最近7天热点；基于用户热点词或主题本身定选题、角度、目标平台。
2. **分镜脚本**：表格，固定7列「镜号、时间码、画面（含花字）、台词、音效、时长、钩子与情绪」，严格执行黄金3秒法则与黄金节奏表；情绪目标与曲线并入“钩子与情绪”列，禁止另建10列表格。分镜脚本之后，有真人主体时紧跟输出一次[CHARACTER_CARD]（结构见 [references/character-card.md](references/character-card.md)），拆段生成时完整注入每一段。
3. **视频生成提示词（参数化编译）**：用户可用`模型=seedance|hailuo|全部`选择输出；未指定时等价`模型=seedance`，只输出豆包 Seedance 2.5，1个代码块。`模型=seedance2.0`只输出 Seedance 2.0；`模型=hailuo`只输出 MiniMax Hailuo 3；`模型=全部`才输出三套。画幅固定默认9:16，仅用户明确要求时才输出16:9。每个代码块都覆盖固定叙事链、当前风格基线、人物连续性和镜头列表中的“穿越/跃迁”字段，音效必须分层递进，禁止“科技感、高级感”类空洞词。默认时长30秒；超过所选模型单段上限时按 [references/segment-split.md](references/segment-split.md) 的段数公式自动拆段，不需要用户手动拆。
4. **封面图提示词**：一套，放在代码块里，画幅与视频一致。

**阶段落盘（第四步一次性生成输出完毕后立即强制执行）**：将本轮成果写入工作区文件；若根目录已有`workspace.md`，则创建`workspace-<片名>.md`并使用该文件。生成成果必须落盘为唯一后续上下文，禁止在后续平台补充或修改轮次中继续依赖历史对话全文。模板：

```markdown
# workspace：<片名>
## 选题策划
<!-- 主体、赛道、热点词状态、目标平台、固定叙事链、人群与转化链 -->
## 分镜脚本
<!-- 7列分镜表 -->
## CHARACTER_CARD
<!-- 有真人主体时保留；无则写"无真人主体" -->
## 提示词代码块
<!-- 按所选模型保留；不保留说明段 -->
## 封面提示词
<!-- 1套 -->
## 自查评分卡
<!-- 修正后的最终评分与镜头号/台词证据 -->
```

**第5步·发布包兜底（仅当平台名单未在选配确认单中确认时执行）**：若第四步已随确认平台输出发布包，跳过本步；仅当用户生成时未确认任何平台、事后要求追加或调整平台名单时，用户回复"剪完了"或直接提出平台需求后，输出第5步：

5. **多平台发布包（分层默认）**：只读取`workspace.md`/`workspace-<片名>.md`、[references/platform-publishing.md](references/platform-publishing.md)、[references/video-pipeline.md](references/video-pipeline.md)和 [references/sensitive-words.md](references/sensitive-words.md)，禁止携带第1-4步的历史对话全文。先生成一行`[平台优先级建议]`，再询问用户确认平台名单；用户未明确确认前，禁止输出任何平台代码块。确认后只输出用户指定平台包和最终自查评分卡，每个平台一个独立代码块，并使用紧凑字段行：`标题 / 话题 / 标签 / SEO关键词 / 封面文案 / 互动引导 / 预埋评论2条 / 最佳发布时间`。标题按“悬念+痛点+结果承诺”公式；预埋评论必须引用具体镜号、台词或画面转折；禁止在平台包里复述剧情、重复完整分镜、重复提示词或输出未确认平台。发布包全文先过敏感词库过滤。

平台筛选参数（仅在用户明确输入后生效，不自动全量输出）：
- `平台=抖音,小红书` 或 `平台=抖音 小红书`：只输出指定平台。
- `平台=主流3` / `发布包=主流3`：抖音、小红书、视频号。
- `平台=出海` / `发布包=出海`：TikTok、Instagram、Facebook、YouTube、Threads、X、Pinterest。
- `平台=全量` / `发布包=全量`：输出当前平台池全部平台。

## 链接逆向复刻

用户说"复刻这个链接：[链接]"时，默认执行逐秒对位复刻，按"处理链接→原片秒级拉片→逐秒映射→复刻提示词→复刻脚本→平台优先级建议→用户确认平台→发布包"执行；本地原片先用 [scripts/replication_frames.ps1](scripts/replication_frames.ps1) 建立每秒帧和秒桶索引。

链接复刻同样执行阶段落盘：秒级台账、逐秒映射、复刻提示词、复刻脚本先写入`workspace.md`或`workspace-<片名>.md`，第6步发布包只读取该workspace文件、平台规则和质量规则，禁止回读前5步历史对话全文。

- 原片是唯一结构基准。必须先建立原片总时长、每秒时间码、镜头/节拍块、画面证据和声音功能，再生成新片；禁止只凭标题、简介、封面、摘要或通用模板复刻。
- 秒级台账必须从 00:00 覆盖到最后 1 秒，每一秒都要有一行；画面延续时也不能写"同上"，要写清延续的主体、动作、镜头和声音状态。复刻提示词和脚本必须逐秒或按连续秒段引用原片镜号/时间码，禁止跳秒、缺段、砍段或改序。
- 默认保留原片总时长、镜序、每秒节奏、钩子位置、转场位置和情绪峰谷；用户明确要求压缩时长时，也要先给出秒级压缩对照表，不得自行砍段或改序。
- 本技能复刻定位为“文案与脚本框架复刻”：逐秒镜头复刻仅在拿到原片素材时执行。
- 拿不到可判断节奏的原片视频、完整关键帧、字幕/旁白和分段时长时，若用户仅提供链接，第一行强制打印：`[缺乏原片素材，将仅提炼结构骨架进行风格仿写，无法进行逐秒镜头复刻]`，然后仅基于标题、封面、简介等公开可获取信息提炼结构骨架做风格仿写，并标注逐秒复刻需补充原片素材；有本地原片但素材不全时，先向用户索要缺失部分再逐秒执行。
- 逆向复刻中的发布包不随前5步一次性输出；必须先输出平台优先级建议并等待用户确认平台名单，确认后只输出指定平台包和自查评分卡。

## 数据复盘

用户回传真实视频数据或要求复盘时，只做数据可支撑的归因，缺失数据标【待补充】，并把可验证结论更新到经验库。

### @复盘 反馈闭环

用户输入`@复盘 [反馈内容]`时，读取并更新 [feedback-library.md](feedback-library.md)：负面反馈映射为`[上轮修正]`并注入下一轮每段提示词；满意素材提炼为赛道化成功结构并追加记录；同赛道只保留最近5条。生成前读取当前修正词和历史偏好，命中时告知用户。

### 配置导入导出

- `导出配置`：将 [config/model-limits.yaml](config/model-limits.yaml) 完整内容输出到代码块，供用户复制保存。
- `导入配置`：用户粘贴YAML内容并说"导入配置"时，技能解析内容并说明检测到的模型和参数，经用户确认后更新配置文件。

## 交付前自查与评分卡

以六个身份在内部完成自查：编导、文案、视觉导演、爆款短视频导演、运营风控、视频质量把关人。按 [references/video-pipeline.md](references/video-pipeline.md) 的违禁词、事实核查、黄金节奏和质量评分规则修正后再交付，不输出检查过程，只输出下方评分卡；敏感词过滤按 [references/sensitive-words.md](references/sensitive-words.md) 执行。查证不到的事实标【待核实】；U Lifestyle 发布规则标【规则待核实】。

第1-4步、链接复刻和极简模式输出的结尾，必须依次附加：

评分卡判定依据必须引用具体镜头号和台词/画面/音效证据；只写“钩子较强”“信息密度较高”“视觉连贯良好”这类结论而无证据的评分无效，必须补证据后重新评分。

硬锚点按以下档位判定，禁止绕过：

- 钩子强度：9-10分=第1秒出现价格/冲突数字、强视觉冲击或可复述悬念；7-8分=前3秒有具体痛点、反常识结论或状态反差；≤6分强制重写。
- 信息密度：9-10分=每2-3秒推进一个可拍摄事件或转化信息；7-8分=核心叙事/转化功能由具体镜号承担且无明显重复；≤6分删镜重排。
- 情绪价值：9-10分=有明确情绪峰值和一句让观众可代入的台词/音效证据；7-8分=情绪变化能落到具体镜号但强度不足；≤6分重写情绪落点。
- 视觉连贯：9-10分=人物、服装、道具、光线在所有相邻镜号都可追踪；7-8分=存在1处可解释但不完美的衔接；≤6分补连续性约束。
- 风控合规：通过=敏感词过滤、事实核查和平台规则占位均完成；命中N处且未修正=不交付。
- 还原可行性：9-10分=每个镜号有对应模型提示词且时长/画幅/叙事链字段完整；7-8分=至少90%镜号可映射但存在待补充项；≤6分重编提示词。

```text
[自查评分卡]
| 维度 | 负责身份 | 得分(1-10) | 判定依据 |
|---|---|---|---|
| 钩子强度 | 爆款短视频导演 | X | 必须引用镜号+台词/画面证据 |
| 信息密度 | 编导 | X | 必须引用承担叙事/转化功能的镜号 |
| 情绪价值 | 文案 | X | 必须引用承担情绪的镜号+台词/音效证据 |
| 视觉连贯 | 视觉导演 | X | 必须引用人物、服装、道具、光线连续的镜号证据 |
| 风控合规 | 运营风控 | 通过/命中N处 | 敏感词库过滤与事实核查结果 |
| 还原可行性 | 视频质量把关人 | X | 必须引用模型提示词覆盖的起止镜号 |
```

任一维度低于7分或风控命中未修正时，先修正再交付，评分卡展示修正后的分数。

评分卡之后强制输出：

```text
【下一步行动清单】
1. 复制本轮`模型=`选中的提示词代码块到即梦（Seedance）、可灵或Sora；按镜头/时间码逐段生成。
2. 有真人主体时，每段都注入同一张[CHARACTER_CARD]。
3. 拆段生成时按workspace.md中的尾帧、运镜和衔接指导处理段间过渡。
4. 生成与剪辑完成后回复“剪完了”；第5步将只读取workspace.md，不回读历史对话。
```
