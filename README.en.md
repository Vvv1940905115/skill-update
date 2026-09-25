# video-pipeline

[简体中文](README.md) | English

A one-stop short-video script engine covering the full workflow from topic planning, storyboards, video-generation prompts, and cover-image prompts to multi-platform publishing packages and data-driven retrospectives.

**Positioning**: [Script Engine] — outputs scripts, storyboards, prompts, and publishing packages only. It does not produce video files; video generation is done manually by the user in tools such as Jimeng, Kling, or Sora.

---

## Full Workflow Overview

```
Trigger (normal generation / quick preset / link replication / @投放数据 / @复盘)
    |
    v
Startup check: continue/new workspace; reads SKILL.md + model-limits.yaml; lazily loads slices on demand
    |
    v
Confirmation flow: recommend track -> pause; confirm topic -> pause; option sheet (model/platform) -> pause
    |                                                                     |
    +--- user replies "按推荐来" or parameters; output steps 1-4 + confirmed platform packages ---+
    |
    v
Stage persistence to workspace.md
    |
    v
User generates video manually; if platforms were not confirmed or need changes, use Step 5 fallback
    |
    v  after publishing
Post-publish calibration: @投放数据 with real data -> invalidate self-score -> diagnose -> update tuning library -> prefer real-data records in the same track next round
```

---

## User Workflow

| Phase | User action | Skill action |
|---|---|---|
| 1. Request | Enter a topic, track, link, or preset | Check workspace, lazily load rules, start confirmation |
| 2. Track | Choose a recommendation or enter a custom track | Recommend candidates, then pause |
| 3. Topic | Choose a recommendation or enter a custom topic | Recommend candidates, then pause |
| 4. Options | Reply "按推荐来" or customize duration/aspect/style/model/platform | Output the option sheet, then pause |
| 5. Generate | Confirm and wait for the full delivery | Output topic, storyboard, selected-model prompts, cover, scorecard, and confirmed platform packages |
| 6. Production | Copy prompts into Jimeng/Kling/Sora and finish editing | Never calls a video-generation API and never outputs a video file |
| 7. Platform fallback | Say "剪完了" or name platforms if they were not confirmed or need changes | Recommend priorities first; after confirmation, output only the chosen platform packages |
| 8. Post-publish | Reply `@投放数据 播放量=... 完播率=...` | Invalidate the AI self-score, diagnose with real data, and update the tuning library |

To reduce confirmation rounds, enter `确认流=极速`: track, topic, and option parameters are combined into one sheet, but generation still waits for user confirmation.

## 1. Loading Logic (Startup Phase)

At startup only `SKILL.md` and `config/model-limits.yaml` are read; all other files load lazily on demand. Fixed loading order:

```
SKILL.md -> track-core.md -> multi-model-prompt.md -> common-variables.md -> matched slices -> matched templates
```

The first four files form a stable cache prefix. Do not modify them between conversation turns to maximize Prompt Caching hit rate (input cost typically drops 10-25%).

Track slice mapping (load only on match):

| Track | Slice + Template |
|---|---|
| Travel Vlog | tracks/travel-vlog.md + templates/travel-vlog.md |
| Personal Growth Vlog | tracks/personal-growth-vlog.md + templates/personal-growth-vlog.md |
| Personal Experience | tracks/personal-experience.md + growth template + experience-patch |
| Advertising / TVC | tracks/advertising.md + templates/advertising.md + advertising-reference.md |
| Live Commerce / Seeding | tracks/live-commerce.md + templates/advertising.md + advertising-reference.md |
| PV / PVC / Promo | tracks/promo.md + templates/promo-pv-travel.md |
| Travel Promo | tracks/travel-promo.md + promo template + travel-promo-patch |
| FPV | tracks/fpv.md + templates/fpv.md |
| Outdoor Documentary | tracks/outdoor-documentary.md + templates/outdoor-documentary.md |
| Past-Event / Character Tracking | append tracks/past-narrative.md after the current track slice |

Conditional loading (load only on match):

| Trigger | File |
|---|---|
| No track specified | track-routing.md |
| Real human subject | character-card.md |
| Duration exceeds model segment limit | segment-split.md |
| Style intensity > 20 or explicitly specified | style-weight.md (plus surreal reference when > 0) |
| `模型=seedance` or `全部` | model-seedance.md |
| `模型=hailuo` or `全部` | model-hailuo.md |

---

## 2. Four-Step Confirmation Flow and Topic Planning

**Trigger**: `Make a [type/track], topic is [XXX]`. The type can be omitted; the skill uses [references/track-routing.md](references/track-routing.md) to rank candidate tracks for recommendation only. It never silently substitutes a user's choice.

The confirmation order is fixed:

1. **Step A: Confirm track.** When no track is specified, output 2-3 candidates with a starred first choice, one-line reasons, and a custom-track prompt; then pause.
2. **Step B: Confirm topic.** After the track is confirmed, output three candidate topics with a starred recommendation and a custom-topic prompt; then pause.
3. **Step C: Option sheet.** Output duration, aspect ratio, style, protagonist identity, generation model, and target platforms. Every item has a recommendation and custom entry; then pause. The model defaults to Seedance 2.5; `模型=全部` explicitly requests all three.
4. **Step D: Generate.** Resume only after the user replies with parameters, says "确认", or says "按推荐来"; then output the following Steps 1-4 in one pass. Once target platforms in the option sheet are confirmed, their platform packages are output with this generation. The generation model also follows the confirmed option sheet and cannot be switched without confirmation.

**Output**:

1. One main topic + one alternative, each with: topic name, entry angle, one-line hook, launch priority (1-3 priority platforms), format suggestion (talking head / documentary / mashup / drama), and hot-topic relevance.
2. Hot-topic keywords must come from user input (`热点词=A,B,C`); if not provided, the topic starts with a `[需手动填入热点词]` placeholder. Fabricating trends is forbidden.
3. When tracks overlap, print an overlap warning and candidates for user confirmation; silent routing is forbidden.

Launch priorities only influence the platform recommendation in Step 5; they never replace user confirmation.

## 3. Step 2: Storyboard

Fixed 7-column table: `Shot # | Timecode | Visual (incl. captions) | Dialogue | SFX | Duration | Hook & Emotion`.

**Golden 3-second rule**: second 1 delivers visual impact or suspense; seconds 2-3 hit the pain point or a counterintuitive claim. If the opening cannot retain viewers, the script is rewritten, not patched.

**Golden rhythm table**:

| Time range | Beat task | Emotion target |
|---|---|---|
| 0-3s | Hook | Curiosity / anxiety / tension |
| 3-10s | Pain-point amplification or setup | Anxiety / resonance / anticipation |
| 10-25s | Turning point or core conflict (emotional peak) | Tension / exhilaration |
| 25-40s | Solution or emotional payoff | Exhilaration / relief |
| Final 5s | Punchline close + strong CTA | Resonance / anticipation |

For durations other than 40 seconds, compress or extend the same beat structure; the 0-3s hook, the peak section, and the final 5s close are always required.

Shot counts: 4-6 shots for 15s, 5-8 for 30s, 8-12 for 60s; timecodes must be continuous with no gaps or overlaps; three consecutive shots with the same emotion are forbidden.

For real human subjects, a `[CHARACTER_CARD]` (gender, age range, hairstyle, facial-feature lock, wardrobe, accessories, key props) follows the storyboard once and is fully injected into every segment during multi-segment generation, together with a character-consistency fallback strategy.

## 4. Step 3: Video-Generation Prompts (Parameterized Compilation)

Output is controlled by the `模型=` parameter:

| Parameter | Output |
|---|---|
| (default) / `模型=seedance` | Doubao Seedance 2.5, one code block |
| `模型=seedance2.0` | Doubao Seedance 2.0, one code block |
| `模型=hailuo` | MiniMax Hailuo 3, one code block |
| `模型=全部` | All three, three code blocks |

Aspect ratio is fixed at 9:16 by default; 16:9 is output only on explicit request.

**Fixed narrative chain** (mandatory for every piece; each model code block must start with a `[Fixed Narrative Chain]` line mapping every node):

```
Reality pressure anchor -> Fantasy seed -> Miniature spectacle -> Trigger crossing -> Subject entrance -> Action proof -> Close -> Reality echo
```

Non-fantasy tracks (live commerce, seeding) replace node content but never remove nodes; `节点=口播` compresses to [Hook + Pain-point/Value proof + CTA]; minimal mode (<= 15s + low density + single scene) compresses to [Grab attention + Core showcase + CTA].

**Director's-desk mode**: write only observable actions, filmable environments, and motivated camera moves. Empty words such as "techy", "premium", or "cinematic" are forbidden.

**Over-length splitting**: segments = CEILING(target duration / model segment limit); always use the current value in `config/model-limits.yaml`. Each segment uses a sliding window with three context fields: `[Story outline]` + `[Previous segment end state]` + `[Current segment goal]`, never the full history of previous segments.

## 5. Step 4: Cover-Image Prompt

One set, aspect ratio matching the video. Prioritize transformation, reversal, peak moments, product-vs-pain-point contrast, or destination awe shots.

## 6. Stage Persistence

At the end of Steps 1-4, results are written to `workspace.md` (or `workspace-<title>.md` if that exists), containing: topic planning, the 7-column storyboard, CHARACTER_CARD (if any), prompt code blocks for the selected model only, cover prompt, and the self-check scorecard.

Step 5 reads only the workspace file + rule files and is forbidden from carrying the full conversation history of Steps 1-4, sharply reducing multi-turn token consumption.

## 7. Platform Package Fallback (Tiered Defaults)

**Trigger**: the platform list was not confirmed in Step C, or the user later says `剪完了` to add or adjust platforms. Execute "recommend first, confirm second, output third":

1. Output one line `[Platform priority suggestion]` (e.g., recommend Douyin + Xiaohongshu as primary, Bilibili / WeChat Channels as secondary; add TikTok / YouTube for overseas).
2. Ask the user to confirm the platform list (default suggestion: mainstream three: Douyin, Xiaohongshu, WeChat Channels).
3. Code blocks are generated only after the user explicitly replies with a platform list or a command. Without confirmation, no platform package may be output, and never all platforms at once.

Platform commands:

| Command | Output |
|---|---|
| `平台=主流3` | Douyin, Xiaohongshu, WeChat Channels |
| `平台=出海` | TikTok, Instagram, Facebook, YouTube, Threads, X, Pinterest |
| `平台=全量` | All 14 platforms |
| `平台=抖音,B站` | Only the specified platforms |

Each platform gets one independent code block using a compact field line: `Title / Topics / Tags / SEO keywords / Cover copy / CTA / 2 seeded comments / Best posting time`. Titles follow the "suspense + pain point + promised result" formula; seeded comments must cite specific shot numbers or lines; plot recap, storyboard repetition, or prompt repetition is forbidden. The full package passes the sensitive-word filter first.

**Final output** = confirmed platform packages + `[Self-check scorecard]` (hook score, information-density score, emotional-value score, etc.; every judgment must cite specific shot numbers and line evidence).

---

## 8. Quick Presets (8)

| Preset | Track | Duration | Aspect | Style intensity |
|---|---|---|---|---|
| `@日常Vlog` | Travel Vlog | 30s | 9:16 | 20 |
| `@口播短视频` | Live commerce | 30s | 9:16 | 0 |
| `@产品广告` | Advertising | 30s | 9:16 | 50 |
| `@剧情短片` | PV / Promo | 30s | 9:16 | 70 |
| `@户外纪实` | Outdoor documentary | 30s | 9:16 | 0 |
| `@fpv` | FPV | 15s | 9:16 | 30 |
| `@个人经历` | Personal experience | 45s | 9:16 | 0 |
| `@旅行宣传片` | Travel promo | 60s | 16:9 | 10 |

Presets accept override parameters: `@产品广告 15s 16:9 模型=hailuo` overrides only the given values and keeps the rest of the preset defaults.

When the user explicitly enters `确认流=极速`, track, topic, and option parameters are combined into one 【rapid confirmation sheet】. The skill still pauses for parameters, "确认", or "按推荐来" before generating.

---

## 9. Link Reverse Replication (6 Steps)

**Trigger**: `Replicate this link: [link]`. Only structure, rhythm, shot order, per-second pacing, lighting, emotion, and interaction logic are replicated; characters, lines, brands, and proprietary content are never copied.

1. **Link processing & material grading**: Grade A (original file / frame-by-frame link) full replication; Grade B (complete keyframes + subtitles + duration) replicable with gaps marked [to be filled]; Grade C (link/title/description/cover only) enters【viral-structure reverse engineering】, outputs a five-dimension skeleton table for opening hook, emotional curve, narrative pacing, core viral point, and ending CTA, then rebuilds a new script with an entirely new topic, lines, and visuals after confirmation. Local footage first runs `scripts/replication_frames.ps1` to build per-second frame indexes.
2. **Per-second shot ledger**: from 00:00 to the last second, one row per second; skipped seconds, missing seconds, or "same as above" entries are forbidden; then merge into shot/beat-block tables.
3. **Second-by-second mapping**: every source second maps to exactly one new-film second, preserving shot order, pacing, hook position, transition positions, and emotional peaks; when compressing duration, a second-level compression mapping table is output first.
4. **Replication prompts**: output via the same `模型=` routing as normal generation, written strictly from the mapping table, auto-split when over the model limit.
5. **Replication script**: fixed 9 columns (new second / timecode / source second / source shot / visual / dialogue / SFX / duration / hook & emotion).
6. **Platform confirmation & publishing package**: same tiered-default flow as Step 5; output only after the user confirms platforms.

Without original footage, every skeleton judgment is marked【inferred】. The skill uses only link metadata and user-provided context and never claims to have watched the source video. After the user supplies original footage or complete keyframes + subtitles, it can switch to per-second replication.

Replication also uses stage persistence: Steps 1-5 results are written to the workspace; Step 6 reads only the workspace + rule files.

---

## 10. Post-Publish Calibration and Data Retrospective

**Trigger**: `@投放数据 播放量=5000 完播率=25% 点赞=300 评论=20`. The skill suspends normal generation and enters calibration mode. Data is user-provided; missing data is marked [to be filled].

Post-publish anchors:

| Metric | Hard anchor |
|---|---|
| Completion rate | Below 15% means the first-3-second hook failed; rewrite seconds 1-3 next time |
| Like rate | Above 3% means emotional resonance or value proof worked; preserve that structure |
| Comment rate | Above 1% means the interaction CTA worked; preserve comment and closing-question hooks |
| 3-second retention | Calibrated only when user-provided; otherwise mark [3-second retention missing] |

Every calibration outputs `① Data diagnosis`, `② Scorecard correction`, and `③ Tuning-library write-back`. Real metrics invalidate the prior AI self-check. The tuning library keeps the latest five records per track; a repeated pitfall becomes a hard ban after two occurrences. Later generation for the same track first searches real-data records in `feedback-library.md`.

`@复盘` remains for subjective feedback and successful-structure capture; `@投放数据` is for quantified post-publish calibration.

Normal retrospective metrics:

| Metric | Standard |
|---|---|
| 3-second retention | Below 30% means the hook failed; rewrite the opening next time |
| Engagement rate | Below 3% means insufficient resonance; strengthen resonance / controversy / questions |
| Completion rate | Compared against same-platform, same-track history |
| Biggest drop-off window | Written as a concrete timecode, e.g., 00:07-00:12 |

Conclusions go into `feedback-library.md` (only the latest 5 per track) and `case-study.md`. The same problem recurring twice escalates to a hard ban. In the next generation, every prompt segment automatically injects a `[上轮修正]` line before `[约束]`, removed only when the user says `@复盘 满意`.

---

## 11. Helper Scripts

**Sensitive-word scan** (manual pre-publish check):

```powershell
powershell -File scripts\scan_sensitive_words.ps1 -Path <file-to-scan.md>
```

Hits print `[SENSITIVE_HIT]` with per-line details; a clean pass prints `[SENSITIVE_SCAN] PASS`. The word list lives in `references/sensitive-words.md`; use `-ListPath` to supply a custom list.

**Replication frame extraction**: `scripts/replication_frames.ps1` uses ffprobe to read total duration, extract one frame per second, and generate `per_second_index.csv` plus 10-second contact sheets.

**Stale-model reminder**: when the current date is more than 60 days after the adaptation date in `config/model-limits.yaml`, the first output line adds `[提醒] 模型参数已超60天未更新，请核实`.

---

## 12. Model Capability Limits (config/model-limits.yaml)

| Model | Segment limit | Reference-asset limit | Features |
|---|---|---|---|
| Seedance 2.5 | 30s | 50 | Time blocks, edit instructions |
| Seedance 2.0 | 10s | 10 | No time blocks |
| Hailuo 3 | 10s | — | Timecodes required; image = identity, video = motion, audio = rhythm |

When models update, only this YAML file changes; skill logic stays untouched.
Generation always uses the current YAML values; this table is a human-readable summary.

---

## 13. Platform Pool (14)

Domestic: Douyin, Kuaishou, Xiaohongshu, WeChat Channels, Weibo, Bilibili

Overseas: TikTok, Instagram, Facebook, YouTube, Threads, X, Pinterest, U Lifestyle

---

## 14. Token Optimization Record

| Optimization | Effect |
|---|---|
| Template example slicing | Five track templates drop from about 30KB to about 10KB; only the selected model slice loads |
| On-demand track slices | No longer reads all 8+ reference files at startup |
| `模型=` parameterization | 4-8K tokens saved per turn |
| Stage persistence cuts history | Step 5 never carries Steps 1-4 conversation |
| Storyboard 10 -> 7 columns | Roughly 30% fewer table tokens |
| Fixed loading order | Prompt Caching hits; input cost down 10-25% |
| Tiered publishing defaults | Eliminates the all-13-platform worst case |
| Sliding-window splitting | Each segment carries 3 context fields, not full history |
