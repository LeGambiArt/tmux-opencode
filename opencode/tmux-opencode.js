import fs   from 'fs'
import path from 'path'
import os   from 'os'

const STATE_DIR  = path.join(os.homedir(), '.config', 'opencode', 'plugins', 'tmux-opencode')
const STATE_PATH = path.join(STATE_DIR, 'statusline-state.sh')

// Cache session titles received via session.updated events so they are
// available immediately on the next write without an extra API call.
const sessionTitles = new Map()

// Mutex: prevents concurrent updateStatus calls when many events arrive
// at once (e.g. streaming tool calls). While one update is running, new
// events are dropped immediately — no queuing, no pile-up.
let updating = false

// Track the session ID last written to the state file so the session
// poller can detect when the user switches to a different session.
// OpenCode fires no "session.focused" event, so polling is the only way.
let lastWrittenSessionID = null

async function safeUpdate(client, $, directory, sessionID) {
  if (updating || !sessionID) return
  updating = true
  try { await updateStatus(client, $, directory, sessionID) } catch {}
  finally { updating = false }
}

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

// Returns the tokens currently occupying the context window.
// Each API call sends the full conversation history as input, so the
// most recent COMPLETED assistant message's input-side tokens represent
// the current context window usage.
//
// We walk backwards rather than always using the last message because the
// newest message may still be streaming — its token counts are not committed
// until the response completes, so reading it would yield 0 and temporarily
// drop the displayed percentage to 0% mid-conversation.
function getContextTokens(messages) {
  if (!messages.length) return 0
  for (let i = messages.length - 1; i >= 0; i--) {
    const t = messages[i].tokens ?? {}
    const c = t.cache ?? {}
    const total = (t.input ?? 0) + (c.read ?? 0) + (c.write ?? 0)
    if (total > 0) return total
  }
  return 0
}

// Returns { contextPct, modelDisplay } — single providers() call covers both
async function getModelInfo(client, providerID, modelID, contextTokens) {
  const res = await client.config.providers()
  const providers = res.data?.providers ?? []
  const provider  = providers.find((p) => p.id === providerID)
  const model     = provider?.models?.[modelID]
  const windowSize = model?.limit?.context

  const contextPct = !windowSize
    ? 0
    : Math.min(100, Math.round((contextTokens / windowSize) * 100))

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
  lastWrittenSessionID = state._sessionID ?? lastWrittenSessionID
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
// Full state update — called by safeUpdate on any event with a session ID
// ---------------------------------------------------------------------------

async function updateStatus(client, $, directory, sessionID) {
  // Fetch messages, git state, and session info in parallel up front.
  // git and session info are always needed regardless of message count.
  const [messages, git, sessionInfo] = await Promise.all([
    getMessages(client, sessionID),
    getGitInfo($, directory),
    getSessionInfo(client, sessionID),
  ])

  // session.updated cache takes priority; fall back to API fetch
  const sessionTitle = sessionTitles.get(sessionID) ?? sessionInfo.title

  if (!messages.length) {
    // New or empty session: write what we know, reset cost and context.
    // This ensures switching to a fresh session clears stale values
    // from the previous session immediately.
    writeState({
      _sessionID:   sessionID,
      model:        '',
      modelDisplay: 'opencode',
      sessionTitle,
      branch:       git.branch,
      dirty:        git.dirty,
      staged:       git.staged,
      contextPct:   0,
      costUsd:      0,
    })
    return
  }

  const latest = messages[messages.length - 1]
  const { modelID, providerID } = latest

  const [costUsd, contextTokens] = await Promise.all([
    getTotalCost(messages),
    Promise.resolve(getContextTokens(messages)),
  ])

  const { contextPct, modelDisplay } = await getModelInfo(
    client, providerID, modelID, contextTokens
  )

  writeState({
    _sessionID:   sessionID,
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
// Session poller — detects switches when no event fires
// ---------------------------------------------------------------------------
// OpenCode has no "session.focused" event, so we poll session.list() every
// few seconds and trigger an update whenever the most-recently-updated
// session differs from the one currently shown in the state file.

async function pollActiveSessions(client, $, directory) {
  try {
    const res = await client.session.list()
    const sessions = (res.data ?? [])
      .sort((a, b) => (b.time?.updated ?? 0) - (a.time?.updated ?? 0))
    if (!sessions.length) return
    const mostRecent = sessions[0]
    if (mostRecent.id !== lastWrittenSessionID)
      await safeUpdate(client, $, directory, mostRecent.id)
  } catch {}
}

// ---------------------------------------------------------------------------
// Plugin export
// ---------------------------------------------------------------------------

export const StatuslinePlugin = async ({ client, directory, $ }) => {
  // Poll every 3 s to catch session switches (no event is fired for those).
  setInterval(() => pollActiveSessions(client, $, directory), 3000)

  return { event: async ({ event }) => {
    // Keep session title cache current from session.updated events so the
    // session name is available immediately on any subsequent write.
    if (event.type === 'session.updated') {
      const { id, title } = event.properties?.info ?? {}
      if (id && title) sessionTitles.set(id, title)
    }

    // Extract session ID from any event type.
    // Different events surface it in different locations:
    //   session.idle    → event.properties.sessionID
    //   session.updated → event.properties.info.id
    //   others          → one of the above, or null (skipped)
    const sessionID = event.properties?.sessionID
                   ?? event.properties?.info?.id
                   ?? null

    if (!sessionID) return

    // Trigger a state write for any event that carries a session ID.
    // safeUpdate drops concurrent calls via mutex so rapid event bursts
    // (tool calls, streaming chunks, etc.) never pile up.
    await safeUpdate(client, $, directory, sessionID)
  } }
}
