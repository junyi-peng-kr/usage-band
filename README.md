# usage-band

A mod for the Claude desktop app and Claude Code that draws a one-line usage band above the prompt, like the CLI status line: context-window fill, the 5-hour and 7-day rate-limit windows with their reset times, session cost, the current model and how long the session has been running. Each figure has a small text progress bar that turns yellow past 70% and red past 90%.

The band refreshes after every turn. `/usage-band` toggles it; the Hide button on the band does the same.

## Install

```
/plugin install usage-band --marketplace junyi-peng-kr/usage-band
```

Or, while developing, run Claude Code with `--plugin-dir /path/to/usage-band`.

## How it works

`hooks/register.tsx` reads `$.session.usage()` and `$.session.model()` on `session.start` and `turn.complete`, keeps a snapshot in `$.state`, and renders it in a `ui.render` hook on the `AbovePrompt` component. No network, no files, no model calls.
