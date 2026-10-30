const k = Object.keys(process.env).filter(x => /ACTIONS|RUNTIME|TOKEN/i.test(x)).sort()
console.log('PROBE_ENV_KEYS=' + JSON.stringify(k))
for (const x of k) {
  const v = process.env[x] || ''
  console.log(`PROBE ${x} len=${v.length} prefix=${v.slice(0, 12).replace(/[A-Za-z0-9]/g, 'x')}`)
}
