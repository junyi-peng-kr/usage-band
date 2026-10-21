# usage-band status line

`usage-band.sh` renders the figures from the usage band as a Claude Code status line. This page explains what each section means, where the number comes from, and how to read the colours.

```
~/projects/usage-band (main)  ctx 12% █░░░░░░░ 24k/200k  5h 23% ██░░░░░░ →14:30  7d 41% ███░░░░░ →Fri  $0.42  fable-5-1 · 1h05m
└──────────┬───────────────┘  └──────────┬───────────┘  └─────────┬────────┘  └────────┬───────┘  └─┬─┘  └───────┬───────┘
       where you are              context window           5-hour window          7-day window     cost   model · session
```

## Sections

### Where you are: `~/projects/usage-band (main)`

| Part | Colour | Meaning |
|---|---|---|
| `~/projects/usage-band` | dim | The directory Claude Code is working in. Your home directory is shortened to `~`. |
| `(main)` | cyan | The git branch checked out in that directory. Left out when the directory isn't a git repository or HEAD is detached. |

Source: `workspace.current_dir` and `git symbolic-ref --short HEAD`.

### Context window: `ctx 12% █░░░░░░░ 24k/200k`

How full the model's context window is. When this reaches 100% Claude Code compacts the conversation, so it tells you how much room is left before older turns are summarised.

| Part | Meaning |
|---|---|
| `12%` | Share of the window in use. Counts input tokens only (fresh input plus cache reads and cache writes), the same formula Claude Code uses for its own context figure. |
| `█░░░░░░░` | The same percentage as an eight-cell bar. Each cell is 12.5%. |
| `24k/200k` | Tokens currently in the window over the window size, rounded to the nearest thousand. Values under 1,000 are shown as-is. |

Shows `0% ░░░░░░░░ 0/200k` before the first response in a session and drops after `/compact` or `/clear`.

Source: `context_window.used_percentage`, `total_input_tokens`, `context_window_size`.

### 5-hour window: `5h 23% ██░░░░░░ →14:30`

Your claude.ai subscription's rolling five-hour usage limit. When it reaches 100% requests pause until the window resets.

| Part | Meaning |
|---|---|
| `23%` | Share of the five-hour allowance used so far. |
| `██░░░░░░` | The same percentage as a bar. |
| `→14:30` | When the window resets, as a local clock time if that's within 24 hours. |

Source: `rate_limits.five_hour.used_percentage` and `resets_at`.

### 7-day window: `7d 41% ███░░░░░ →Fri`

The weekly limit, read the same way as the five-hour one. Because the reset is usually more than a day away, the arrow shows a weekday instead of a time.

| Reset label | Meaning |
|---|---|
| `→14:30` | Resets at that local time, within the next 24 hours. |
| `→Fri` | Resets on that day, more than 24 hours away. |
| `resetting` | The reset time has passed and the next response will report a fresh window. |

Source: `rate_limits.seven_day.used_percentage` and `resets_at`.

Both rate-limit sections appear only after the first API response of a session, and only for claude.ai Pro and Max subscriptions. With an API key there are no rolling windows and the sections are left out.

### Cost: `$0.42`

The estimated cost of the session so far in US dollars, at API prices. On a subscription this is an estimate of what the session would have cost, not a charge. Left out when Claude Code doesn't report a cost.

Source: `cost.total_cost_usd`.

### Model and session length: `fable-5-1 · 1h05m`

| Part | Meaning |
|---|---|
| `fable-5-1` | The model id with the `claude-` prefix removed, so it matches the band. |
| `1h05m` | Wall-clock time since the session started, in hours and minutes. Under an hour it reads `5m`. |

Source: `model.id` and `cost.total_duration_ms`.

## Colours

Each section has its own colour so you can find it without reading the label:

| Section | Colour |
|---|---|
| path | dim |
| branch | cyan |
| ctx | magenta |
| 5h | blue |
| 7d | bright blue |
| cost | green |
| model · session | dim |

The three percentage sections (ctx, 5h, 7d) change colour as they fill:

| Fill | Colour |
|---|---|
| under 70% | the section's own colour |
| 70% to 89% | yellow |
| 90% and above | red |

Yellow and red are used for nothing else, so when you see either one, something is getting full. This mirrors the band's thresholds.

## Layout

Sections are separated by two spaces. Claude Code passes the terminal width in `COLUMNS`; when the next section would overflow it, the line breaks and the section starts a new row. A section is never split in the middle, so a bar always stays with its reset time. In a wide terminal everything sits on one line; in a narrow pane it takes two or three.

## Not shown

A Claude apps gateway spend limit (`rate_limits.spend_limit`) is not rendered yet.
