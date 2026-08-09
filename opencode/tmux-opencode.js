import fs   from 'fs'
import path from 'path'
import os   from 'os'

const STATE_DIR  = path.join(os.homedir(), '.config', 'opencode', 'plugins', 'tmux-opencode')
const STATE_PATH = path.join(STATE_DIR, 'statusline-state.sh')

// Cache session titles received via session.updated events so they are
// available immediately on the next session.idle write without an extra
// API call.
const sessionTitles = new Map()

// ---------------------------------------------------------------------------
// Model display name
// ---------------------------------------------------------------------------

function formatModelDisplay(modelID, modelApiName) {
  // Prefer the API's human-readable name when it differs from the raw ID
  if (modelApiName && modelApiName !== modelID) {
    const parts = modelApiName.split(' ')
    const providerWords = ['Claude', 'GPT', 'Gemini', 'Llama', 'Mistral', 'Qwen', 'Grok']
    // "Claude Sonnet 4.6" → "Sonnet 4.6"
    if (parts.length > 1 && providerWords.includes(parts[0])) {
      return parts.slice(1).join(' ')
    }
    return modelApiName
  }

  // Fall back to compact ID manipulation:
  //   "claude-sonnet-4-6@default" → "sonnet4.6"
  //   "claude-opus-4@default"     → "opus4"
  //   "gpt-4-turbo@latest"        → "4-turbo"
  return modelID
    .replace(/@[^@]+$/, '')                                          // strip @qualifier
    .replace(/^(claude|gpt|gemini|llama|mistral|qwen|grok)-/i, '')  // strip provider prefix
    .replace(/-(\d+)-(\d+)$/, '$1.$2')                              // -4-6 → 4.6
    .replace(/-(\d+)$/, '$1')                                        // -4  → 4
}

// ---------------------------------------------------------------------------
// API helpers
// ---------------------------------------------------------------------------

async function getMessages(client, sessionID) {
  const res = await client.session.messages({ path: { id: sessionID } })
  return (res.data ?? [])
    .filter((m) => m.info.role === 'assistant')
    .map((m) => m.info)
}

async function getTotalCost(messages) {
  return messages.reduce((sum, m) => sum + (m.cost ?? 0), 0)
}

async function getTotalTokens(messages) {
  return messages.reduce((sum, m) => {
    const t = m.tokens ?? {}
    const c = t.cache ?? {}
    return (
      sum + (t.input ?? 0) + (t.output ?? 0) +
      (c.read ?? 0) + (c.write ?? 0)
    )
  }, 0)
}

// Returns { contextPct, modelDisplay } — single providers() call covers both
async function getModelInfo(client, providerID, modelID, totalTokens) {
  const res = await client.config.providers()
  const providers = res.data?.providers ?? []
  const provider  = providers.find((p) => p.id === providerID)
  const model     = provider?.models?.[modelID]
  const windowSize = model?.limit?.context

  const contextPct = !windowSize
    ? 0
    : Math.min(100, Math.round((totalTokens / windowSize) * 100))

  const modelDisplay = formatModelDisplay(modelID, model?.name)

  return { contextPct, modelDisplay }
}

async function getSessionInfo(client, sessionID) {
  try {
    const res = await client.session.get({ path: { id: sessionID } })
    return { title: res.data?.title ?? '' }
  } catch {
    return { title: '' }
  }
}

async function getGitInfo($, directory) {
  try {
    const branch = (
      await $`git -C ${directory} symbolic-ref --short HEAD 2>/dev/null`.text()
    ).trim()
    const dirtyExit = (
      await $`git -C ${directory} diff --quiet 2>/dev/null; echo $?`.text()
    ).trim()
    const stagedExit = (
      await $`git -C ${directory} diff --cached --quiet 2>/dev/null; echo $?`.text()
    ).trim()
    return {
      branch: branch || '',
      dirty:  dirtyExit  !== '0' ? 1 : 0,
      staged: stagedExit !== '0' ? 1 : 0,
    }
  } catch {
    return { branch: '', dirty: 0, staged: 0 }
  }
}

// ---------------------------------------------------------------------------
// State file
// ---------------------------------------------------------------------------

function writeState(state) {
  fs.mkdirSync(STATE_DIR, { recursive: true })
  const lines = [
    `MODEL="${state.model}"`,
    `MODEL_DISPLAY="${state.modelDisplay}"`,
    `SESSION_TITLE="${state.sessionTitle}"`,
    `BRANCH="${state.branch}"`,
    `DIRTY=${state.dirty}`,
    `STAGED=${state.staged}`,
    `CONTEXT_PCT=${state.contextPct}`,
    `COST_USD=${state.costUsd}`,
    `UPDATED_AT=${Math.floor(Date.now() / 1000)}`,
  ]
  fs.writeFileSync(STATE_PATH, lines.join('\n') + '\n', 'utf8')
}

// ---------------------------------------------------------------------------
// Full state update (triggered by session.idle)
// ---------------------------------------------------------------------------

async function updateStatus(client, $, directory, sessionID) {
  const messages = await getMessages(client, sessionID)
  if (!messages.length) return

  const latest              = messages[messages.length - 1]
  const { modelID, providerID } = latest

  const [costUsd, totalTokens, git, sessionInfo] = await Promise.all([
    getTotalCost(messages),
    getTotalTokens(messages),
    getGitInfo($, directory),
    getSessionInfo(client, sessionID),
  ])

  // session.updated cache takes priority; fall back to API fetch
  const sessionTitle = sessionTitles.get(sessionID) ?? sessionInfo.title

  const { contextPct, modelDisplay } = await getModelInfo(
    client, providerID, modelID, totalTokens
  )

  writeState({
    model:        modelID.replace(/^claude-/, '').slice(0, 20),  // kept for compat
    modelDisplay,
    sessionTitle,
    branch:       git.branch,
    dirty:        git.dirty,
    staged:       git.staged,
    contextPct,
    costUsd:      Math.round(costUsd * 10000) / 10000,
  })
}

// ---------------------------------------------------------------------------
// Plugin export
// ---------------------------------------------------------------------------

export const StatuslinePlugin = async ({ client, directory, $ }) => ({
  event: async ({ event }) => {
    // Keep session title cache current so session plugin stays accurate
    // across session switches without waiting for an idle event.
    if (event.type === 'session.updated') {
      const { id, title } = event.properties?.info ?? {}
      if (id && title) sessionTitles.set(id, title)
      return
    }

    if (event.type !== 'session.idle') return
    const { sessionID } = event.properties
    await updateStatus(client, $, directory, sessionID).catch(() => {})
  },
})
