# usage-band

A mod for the Claude desktop app and Claude Code that draws a one-line usage band above the prompt, like the CLI status line: context-window fill, the 5-hour and 7-day rate-limit windows with their reset times, session cost, the current model and how long the session has been running. Each figure has a small text progress bar that turns yellow past 70% and red past 90%.

The band refreshes after every turn. `/usage-band` toggles it; the Hide button on the band does the same.

## Install

**Claude desktop app:** click **+** next to the prompt box → **Plugins** → **Add marketplace**, enter `junyi-peng-kr/usage-band`, then **Add plugin** → `usage-band`.

**Claude Code in a terminal:**

```
/plugin install usage-band --marketplace junyi-peng-kr/usage-band
```

or from a shell: `claude plugin install usage-band --marketplace junyi-peng-kr/usage-band`. Installed at the user scope, it also loads in the desktop app's local Code sessions.

**While developing:** `claude --plugin-dir /path/to/usage-band`, or set `CLAUDE_CODE_PLUGIN_DIRS=/path/to/usage-band` for sessions the desktop app starts.

## How it works

`hooks/register.tsx` reads `$.session.usage()` and `$.session.model()` on `session.start` and `turn.complete`, keeps a snapshot in `$.state`, and renders it in a `ui.render` hook on the `AbovePrompt` component. No network, no files, no model calls.

## Status line

`statusline/usage-band.sh` draws the same figures as a CLI status line, for terminals and sessions where the band isn't available. It is independent of the plugin: install it by pointing `statusLine` in `~/.claude/settings.json` at the script.

```json
"statusLine": {
  "type": "command",
  "command": "bash /path/to/usage-band/statusline/usage-band.sh"
}
```

```
~/projects/usage-band (main)  ctx 12% █░░░░░░░ 24k/200k  5h 23% ██░░░░░░ →14:30  7d 41% ███░░░░░ →Fri  $0.42  fable-5-1 · 1h05m
```

Each section has its own colour so it can be found without reading the label: path dim, branch cyan, context magenta, 5h blue, 7d bright blue, cost green. A figure turns yellow past 70% and red past 90%, so those two colours only ever mean "getting full". Sections the session hasn't reported yet (rate limits before the first response, cost outside a billed session) are left out.

Needs `jq`. Tests: `bash statusline/test.sh`.
