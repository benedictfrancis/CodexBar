import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';

const model = vm.createContext({});
vm.runInContext(fs.readFileSync(new URL('./Usage.js', import.meta.url), 'utf8'), model);
test('quota is clamped, missing quota stays unknown', () => {
    assert.equal(model.remaining({usedPercent: 28}), 72);
    assert.equal(model.remaining({usedPercent: 150}), 0);
    assert.equal(model.remaining({usedPercent: -5}), 100);
    for (const value of [null, {}, {usedPercent: null}, {usedPercent: '12'}, {usedPercent: Infinity}])
        assert.equal(model.remaining(value), null);
});
test('partial provider failures preserve healthy rows without leaking raw errors or identity', () => {
    const rows = model.rows(JSON.stringify([
        {provider: 'codex', usage: {primary: {usedPercent: 28, windowMinutes: 300}, identity: {accountEmail: 'private@example.com'}}},
        {provider: 'claude', error: {message: 'secret upstream response'}}
    ]));
    assert.equal(model.summary(rows), 'CX 72%  ·  CL —');
    assert.equal(rows[0].windows[0].label, '5 hour');
    assert.ok(rows[1].error);
    assert.ok(!JSON.stringify(rows).includes('secret'));
    assert.ok(!JSON.stringify(rows).includes('private'));
});
test('malformed and unrecognized responses cannot replace the last good snapshot', () => {
    for (const value of ['', '[]', '{}', 'null', '[null]', 'oops'])
        assert.throws(() => model.rows(value));
});
test('reset countdown handles invalid and elapsed timestamps', () => {
    const now = Date.parse('2026-01-01T00:00:00Z');
    assert.equal(model.resetLabel('bad', now), 'Reset time unavailable');
    assert.equal(model.resetLabel('2025-12-31T23:00:00Z', now), 'Reset due · refresh to update');
    assert.equal(model.resetLabel('2026-01-01T01:30:00Z', now), 'Resets in 1h 30m');
});
test('account selection is scoped to a single provider and arguments never use a shell', () => {
    const command = model.command({provider: 'both', allAccounts: true, accountIndex: 2});
    assert.ok(!command.includes('--all-accounts'));
    assert.ok(!command.includes('--account-index'));
    assert.ok(!model.command({provider: 'enabled'}).includes('--provider'));
    const single = model.command({provider: 'codex', allAccounts: true, source: 'oauth', executable: '/a path/codexbar'});
    assert.ok(single.includes('--all-accounts'));
    assert.ok(single.includes('/a path/codexbar'));
    assert.ok(single.includes('oauth'));
    assert.ok(!model.command({accountIndex: '2;bad'}).includes('--account-index'));
});
test('identity is opt-in and stays within its provider row', () => {
    const input = JSON.stringify([{provider: 'codex', usage: {identity: {accountEmail: 'one@example.com', loginMethod: 'pro'}}},
        {provider: 'claude', usage: {}}]);
    assert.equal(model.rows(input)[0].accountLabel, '');
    assert.equal(model.rows(input, true)[0].accountLabel, 'one@example.com');
    assert.equal(model.rows(input, true)[1].accountLabel, '');
    assert.equal(model.rows(input, true)[1].plan, '');
});
