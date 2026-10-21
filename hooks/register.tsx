import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register, ThemeKey } from 'claude-code'

import type { Limit, Snapshot } from '../types'

const snapshot = atom({ plugin: 'usage-band', key: 'snapshot' } as const, null)
const isHidden = atom({ plugin: 'usage-band', key: 'isHidden' } as const, false)

const WARN = 70
const BAD = 90

function tone(percent: number): ThemeKey {
  if (percent >= BAD) return 'error'
  if (percent >= WARN) return 'warning'
  return 'success'
}

function bar(percent: number, width = 8): string {
  const filled = Math.round((Math.min(100, Math.max(0, percent)) / 100) * width)
  return '█'.repeat(filled) + '░'.repeat(width - filled)
}

function k(n: number): string {
  return n >= 1000 ? `${Math.round(n / 1000)}k` : `${n}`
}

function windowLabel(kind: string): string {
  if (kind === 'five_hour') return '5h'
  if (kind === 'seven_day') return '7d'
  if (kind === 'spend_limit') return 'spend'
  return kind
}

function resetLabel(resetsAt: string | undefined, now: number): string {
  if (!resetsAt) return ''
  const at = new Date(resetsAt)
  if (Number.isNaN(at.getTime())) return ''
  const ms = at.getTime() - now
  if (ms <= 0) return 'resetting'
  const hours = ms / 3_600_000
  if (hours < 24) {
    const hh = String(at.getHours()).padStart(2, '0')
    const mm = String(at.getMinutes()).padStart(2, '0')
    return `→${hh}:${mm}`
  }
  const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
  return `→${days[at.getDay()]}`
}

function elapsed(startedAt: number, now: number): string {
  const min = Math.max(0, Math.floor((now - startedAt) / 60_000))
  const h = Math.floor(min / 60)
  const m = min % 60
  return h > 0 ? `${h}h${String(m).padStart(2, '0')}m` : `${m}m`
}

function shortModel(model: string): string {
  return model.replace(/^claude-/, '')
}

async function refresh($: EngineInterface) {
  try {
    await refreshOrThrow($)
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err)
    await update($, snapshot, () => ({
      error: message,
      ctxPercent: 0, ctxTokens: 0, ctxWindow: 0, limits: [], usd: null, model: '', startedAt: 0, takenAt: 0,
    }))
  }
}

async function refreshOrThrow($: EngineInterface) {
  const [usage, model, now] = await Promise.all([
    $.session.usage(),
    $.session.model(),
    $.clock.now(),
  ])
  const limits: Limit[] = usage.rateLimits.map(l => ({
    kind: l.kind,
    percent: l.percentUsed,
    resetsAt: l.resetsAt,
  }))
  const next: Snapshot = {
    ctxPercent: usage.context.percent ?? 0,
    ctxTokens: usage.context.tokens ?? 0,
    ctxWindow: usage.context.window,
    limits,
    usd: usage.cost ? usage.cost.usd : null,
    model,
    startedAt: usage.startedAt,
    takenAt: now,
  }
  await update($, snapshot, () => next)
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    $.command.register({
      name: 'usage-band',
      description: 'Show or hide the usage band above the prompt',
    })
    await refresh($)
    return next(e)
  })

  on('command.run', { command: 'usage-band' }, async ($, e) => {
    const hidden = await read($, isHidden)
    await update($, isHidden, () => !hidden)
    if (hidden) await refresh($)
    return { text: hidden ? 'Usage band shown.' : 'Usage band hidden. Run /usage-band again to show it.' }
  })

  on('turn.complete', async ($, e, next) => {
    await refresh($)
    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const snap = await read($, snapshot)
    // The terminal has statusline/usage-band.sh; the band is for the desktop app.
    if (e.surface !== 'desktop' || e.props.hasSurvey || snap === null || (await read($, isHidden))) {
      return next(e)
    }

    const { Box, Button, Text } = $.ui.resolve(e)
    const now = snap.takenAt

    if (snap.error) {
      return (
        <Box key="usage-band" flexDirection="row" gap={2}>
          <Text mono color="error">usage-band: {snap.error}</Text>
          <Button key="hide" label="Hide" onPress={() => update($, isHidden, () => true)} />
        </Box>
      )
    }

    return (
      <Box key="usage-band" flexDirection="row" flexWrap="wrap" gap={2} alignItems="center">
        <Text mono dimColor>
          ctx <Text color={tone(snap.ctxPercent)}>{snap.ctxPercent}% {bar(snap.ctxPercent)}</Text>{' '}
          {k(snap.ctxTokens)}/{k(snap.ctxWindow)}
        </Text>
        {snap.limits.map(l => (
          <Text key={l.kind} mono dimColor>
            {windowLabel(l.kind)}{' '}
            <Text color={tone(l.percent)}>{l.percent}% {bar(l.percent)}</Text>{' '}
            {resetLabel(l.resetsAt, now)}
          </Text>
        ))}
        {snap.usd !== null && (
          <Text mono dimColor>
            cost <Text color="text">${snap.usd.toFixed(2)}</Text>
          </Text>
        )}
        <Text mono dimColor>
          {shortModel(snap.model)} · {elapsed(snap.startedAt, now)}
        </Text>
        <Button key="hide" label="Hide" onPress={() => update($, isHidden, () => true)} />
      </Box>
    )
  })
}
