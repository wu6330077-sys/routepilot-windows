'use strict';

const fs = require('fs');
const vm = require('vm');

const pacPath = process.argv[2];
const configPath = process.argv[3];
if (!pacPath || !configPath) {
  throw new Error('Usage: node Test-RoutingPac.js <pac-path> <config-path>');
}

const config = JSON.parse(fs.readFileSync(configPath, 'utf8').replace(/^\uFEFF/, ''));
const primary = `PROXY ${config.primaryProxy.host}:${config.primaryProxy.port}`;
const bulk = `PROXY ${config.bulkProxy.host}:${config.bulkProxy.port}`;
const defaultRoute = config.defaultDirectFallback ? `${primary}; DIRECT` : primary;

const sandbox = {
  dnsDomainIs(host, suffix) { return host.endsWith(suffix); },
  isPlainHostName(host) { return !host.includes('.'); }
};
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(pacPath, 'utf8').replace(/^\uFEFF/, ''), sandbox);

const cases = [];
for (const domain of config.protectedDomains) {
  cases.push([domain, primary]);
  cases.push([`sub.${domain}`, primary]);
}
for (const domain of config.bulkDomains) {
  cases.push([domain, bulk]);
  cases.push([`cdn.${domain}`, bulk]);
}
cases.push(['ordinary.example.org', defaultRoute]);
cases.push(['localhost', 'DIRECT']);
cases.push(['127.0.0.1', 'DIRECT']);
cases.push(['10.20.30.40', 'DIRECT']);
cases.push(['172.31.1.1', 'DIRECT']);
cases.push(['192.168.1.1', 'DIRECT']);

for (const [host, expected] of cases) {
  const actual = sandbox.FindProxyForURL(`https://${host}/`, host);
  if (actual !== expected) {
    throw new Error(`${host}: expected ${expected}, got ${actual}`);
  }
}

process.stdout.write(`pac_tests=${cases.length}\nstatus=ok\n`);
