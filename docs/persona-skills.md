# 人设技能清单（已安装 + 未安装）

> 安装位置：`.dsh/skills/`（项目级，DSH 自动识别，无需重启）
> 安装日期：2026-10-28
> 这些是第三方提示词内容，不是可信代码；技能里带脚本时先读再跑。

## 已安装的 4 个

| # | 名称 | 技能名 | 来源 | 体积 | 用途 |
|---|---|---|---|---|---|
| 1 | awesome-persona-skills | `awesome-persona-skills` | [momozi1996/awesome-ai-persona-skills](https://github.com/momozi1996/awesome-ai-persona-skills) | 12.6 KB | 100+ 人格蒸馏 Skill 的索引库，先查这里再决定装谁 |
| 2 | Character Skill Producer | `csp` | [qian-gugugaga/Character_Skill_Producer](https://github.com/qian-gugugaga/Character_Skill_Producer) | 1.49 MB | 二次元角色蒸馏：角色名+作品名 → 可运行角色 Skill |
| 3 | nuwa-skill（女娲） | `huashu-nuwa` | [alchaincyf/nuwa-skill](https://github.com/alchaincyf/nuwa-skill) | 40.71 MB | 蒸馏任何人的思维方式：心智模型、决策启发式、表达 DNA |
| 4 | napkin | `napkin` | [blader/napkin](https://github.com/blader/napkin) | 0.01 MB | 每仓 runbook：把反复有用的经验沉淀成可复用记忆，给人设"连续性" |

安装方式（都可复现）：

```bash
git clone --depth 1 <仓库地址> ".dsh/skills/<kebab-case-名字>"
```

`awesome-persona-skills` 是例外：上游是合集仓库、没有 `SKILL.md`，所以本地写了一个索引型
`SKILL.md`，把上游的 `persona-skills.md` 放在同目录作为数据。

## 未安装的 1 个

| # | 名称 | 说明 |
|---|---|---|
| 5 | 六层 | **手写人设模板，无需安装插件**。它是一份写作框架，不是代码产物，所以没有可装的东西。 |

第 5 项如果要落地，是写一份 Markdown 模板（人设的六个层次），而不是克隆仓库。
原始出处是视频，我没有视频内容，无法保证与视频里的六层划分一致。

## 维护

- 技能目录被 `.gitignore` 排除（`.dsh/skills/`），因为体积大且可重新克隆；这份清单进仓库，保证换机器能复现。
- 升级：进对应目录 `git pull`，或删掉重新 `git clone`。
- 卸载：删掉 `.dsh/skills/<名字>` 目录即可。
