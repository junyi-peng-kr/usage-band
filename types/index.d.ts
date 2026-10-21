export type Limit = { kind: string; percent: number; resetsAt?: string }

export type Snapshot = {
  ctxPercent: number
  ctxTokens: number
  ctxWindow: number
  limits: Limit[]
  usd: number | null
  model: string
  startedAt: number
  takenAt: number
}

declare module 'claude-code' {
  interface PluginState {
    'usage-band': { snapshot: Snapshot | null; isHidden: boolean }
  }
}
