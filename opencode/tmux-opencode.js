import fs   from 'fs'
import path from 'path'
import os   from 'os'

const STATE_DIR  = path.join(os.homedir(), '.config', 'opencode')
const STATE_PATH = path.join(STATE_DIR, 'statusline-state.sh')

function shortModelName(modelID) {
  return modelID.replace(/^claude-/, '').slice(0, 20)
}

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

async function getContextPct(client, providerID, modelID, totalTokens) {
  const res = await client.config.providers()
  const providers = res.data?.providers ?? []
  const provider = providers.find((p) => p.id === providerID)
  const model = provider?.models?.[modelID]
  const windowSize = model?.limit?.context
  if (!windowSize) return 0
  return Math.min(100, Math.round((totalTokens / windowSize) * 100))
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
      branch:  branch || '',
      dirty:   dirtyExit  !== '0' ? 1 : 0,
      staged:  stagedExit !== '0' ? 1 : 0,
    }
  } catch {
    return { branch: '', dirty: 0, staged: 0 }
  }
}

function writeState(state) {
  fs.mkdirSync(STATE_DIR, { recursive: true })
  const lines = [
    `MODEL="${state.model}"`,
    `BRANCH="${state.branch}"`,
    `DIRTY=${state.dirty}`,
    `STAGED=${state.staged}`,
    `CONTEXT_PCT=${state.contextPct}`,
    `COST_USD=${state.costUsd}`,
    `UPDATED_AT=${Math.floor(Date.now() / 1000)}`,
  ]
  fs.writeFileSync(STATE_PATH, lines.join('\n') + '\n', 'utf8')
}

async function updateStatus(client, $, directory, sessionID) {
  const messages = await getMessages(client, sessionID)
  if (!messages.length) return

  const latest   = messages[messages.length - 1]
  const { modelID, providerID } = latest

  const [costUsd, totalTokens, git] = await Promise.all([
    getTotalCost(messages),
    getTotalTokens(messages),
    getGitInfo($, directory),
  ])

  const contextPct = await getContextPct(
    client, providerID, modelID, totalTokens
  )

  writeState({
    model:      shortModelName(modelID),
    branch:     git.branch,
    dirty:      git.dirty,
    staged:     git.staged,
    contextPct,
    costUsd:    Math.round(costUsd * 10000) / 10000,
  })
}

export const StatuslinePlugin = async ({ client, directory, $ }) => ({
  event: async ({ event }) => {
    if (event.type !== 'session.idle') return
    const { sessionID } = event.properties
    await updateStatus(client, $, directory, sessionID).catch(() => {})
  },
})
