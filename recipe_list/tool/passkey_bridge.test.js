/**
 * tool/passkey_bridge.test.js — Chunk 23 regression test for
 * web/passkey_bridge.js. Runs under `node --test`. We don't need
 * a real browser: the IIFE only requires `window`, `atob`, `btoa`,
 * and the parts that touch `navigator.credentials.create / get` /
 * `PublicKeyCredential` we mock per case.
 *
 * Coverage:
 *   - base64url ↔ ArrayBuffer round-trip
 *   - decodeCreationOptions converts challenge / user.id /
 *     excludeCredentials[].id to ArrayBuffers
 *   - decodeRequestOptions converts challenge / allowCredentials[].id
 *   - credentialToRegistrationJSON / credentialToAuthenticationJSON
 *     fall through to manual encoding when toJSON() is missing,
 *     and prefer toJSON() when present
 *   - register() POSTs to /recipes/auth/passkey/register/{start,complete}
 *     with the bearer token
 *   - login() POSTs to /recipes/auth/passkey/login/{start,complete}
 *
 * `index.html` is asserted to load `passkey_bridge.js` before
 * `flutter_bootstrap.js` (script-tag order matters).
 */

import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const BRIDGE_PATH = path.resolve(__dirname, '..', 'web', 'passkey_bridge.js');
const INDEX_PATH = path.resolve(__dirname, '..', 'web', 'index.html');
const BRIDGE_SRC = fs.readFileSync(BRIDGE_PATH, 'utf8');

function loadBridge({ withPublicKeyCredential = true, fetchImpl, navCreds } = {}) {
  // Build a sandbox that mimics just enough of the browser for the
  // IIFE in passkey_bridge.js. Note: the IIFE needs a top-level
  // `window` reference; node's vm gives us that via the contextified
  // object. atob/btoa are globals in Node 18+ and we forward them.
  const fakeWindow = {};
  const sandbox = {
    window: fakeWindow,
    atob: globalThis.atob,
    btoa: globalThis.btoa,
    fetch: fetchImpl,
    navigator: {
      credentials: navCreds,
      userAgent: 'Mozilla/5.0 (Test) Chrome/124',
      platform: 'MacIntel',
    },
  };
  if (withPublicKeyCredential) {
    sandbox.PublicKeyCredential = function () {};
    fakeWindow.PublicKeyCredential = sandbox.PublicKeyCredential;
  }
  vm.createContext(sandbox);
  vm.runInContext(BRIDGE_SRC, sandbox);
  return { window: fakeWindow, sandbox };
}

// ----------------------------------------------------------------
// Helpers
// ----------------------------------------------------------------

test('window.recipeAppPasskey exposes register/login/available', () => {
  const { window } = loadBridge();
  assert.equal(typeof window.recipeAppPasskey.register, 'function');
  assert.equal(typeof window.recipeAppPasskey.login, 'function');
  assert.equal(typeof window.recipeAppPasskey.available, 'function');
});

test('b64url round-trip', () => {
  const { window } = loadBridge();
  const { b64urlToBuffer, bufferToB64url } = window.recipeAppPasskey.__internals;
  const original = 'Hello-World_+/=';
  // Encode via Buffer to a known base64url value, decode through
  // bridge, re-encode, and assert equality.
  const b64url = Buffer.from(original).toString('base64url');
  const buf = b64urlToBuffer(b64url);
  assert.equal(Buffer.from(buf).toString('utf8'), original);
  assert.equal(bufferToB64url(buf), b64url);
});

test('decodeCreationOptions converts challenge / user.id / excludeCredentials[].id', () => {
  const { window } = loadBridge();
  const { decodeCreationOptions } = window.recipeAppPasskey.__internals;
  const json = {
    challenge: Buffer.from('chal').toString('base64url'),
    rp: { name: 'Otus', id: 'mahallem.ist' },
    user: { id: Buffer.from('uid').toString('base64url'), name: 'a@b', displayName: 'a' },
    pubKeyCredParams: [{ type: 'public-key', alg: -7 }],
    excludeCredentials: [{ id: Buffer.from('cid').toString('base64url'), type: 'public-key' }],
  };
  const decoded = decodeCreationOptions(json);
  // Cross-realm: the sandbox's ArrayBuffer is a different constructor
  // from the host's, so `instanceof ArrayBuffer` does not match. Duck
  // type via byteLength + Buffer.from.
  assert.equal(typeof decoded.challenge.byteLength, 'number');
  assert.equal(Buffer.from(decoded.challenge).toString('utf8'), 'chal');
  assert.equal(typeof decoded.user.id.byteLength, 'number');
  assert.equal(Buffer.from(decoded.user.id).toString('utf8'), 'uid');
  assert.equal(typeof decoded.excludeCredentials[0].id.byteLength, 'number');
  assert.equal(Buffer.from(decoded.excludeCredentials[0].id).toString('utf8'), 'cid');
});

test('decodeRequestOptions converts challenge / allowCredentials[].id', () => {
  const { window } = loadBridge();
  const { decodeRequestOptions } = window.recipeAppPasskey.__internals;
  const json = {
    challenge: Buffer.from('chal').toString('base64url'),
    allowCredentials: [
      { id: Buffer.from('cid1').toString('base64url'), type: 'public-key' },
      { id: Buffer.from('cid2').toString('base64url'), type: 'public-key' },
    ],
  };
  const decoded = decodeRequestOptions(json);
  assert.equal(typeof decoded.challenge.byteLength, 'number');
  assert.equal(decoded.allowCredentials.length, 2);
  assert.equal(Buffer.from(decoded.allowCredentials[1].id).toString('utf8'), 'cid2');
});

test('credentialToRegistrationJSON: prefers toJSON(), else manual', () => {
  const { window } = loadBridge();
  const { credentialToRegistrationJSON } = window.recipeAppPasskey.__internals;

  // toJSON() path
  const credToJSON = {
    id: 'X',
    rawId: new ArrayBuffer(0),
    type: 'public-key',
    response: { clientDataJSON: new ArrayBuffer(0), attestationObject: new ArrayBuffer(0) },
    toJSON() {
      return { id: 'X', __used_toJSON: true };
    },
  };
  assert.equal(credentialToRegistrationJSON(credToJSON).__used_toJSON, true);

  // Manual path
  const enc = new TextEncoder();
  const cred = {
    id: 'idstr',
    rawId: enc.encode('rawId').buffer,
    type: 'public-key',
    response: {
      clientDataJSON: enc.encode('cdj').buffer,
      attestationObject: enc.encode('attest').buffer,
      getTransports: () => ['internal', 'hybrid'],
    },
    getClientExtensionResults: () => ({ foo: 1 }),
  };
  const out = credentialToRegistrationJSON(cred);
  assert.equal(out.id, 'idstr');
  assert.equal(out.type, 'public-key');
  assert.equal(out.rawId, Buffer.from('rawId').toString('base64url'));
  assert.equal(out.response.clientDataJSON, Buffer.from('cdj').toString('base64url'));
  assert.equal(out.response.attestationObject, Buffer.from('attest').toString('base64url'));
  assert.deepEqual(out.response.transports, ['internal', 'hybrid']);
  assert.deepEqual(out.clientExtensionResults, { foo: 1 });
});

test('credentialToAuthenticationJSON: manual path encodes signature/userHandle', () => {
  const { window } = loadBridge();
  const { credentialToAuthenticationJSON } = window.recipeAppPasskey.__internals;
  const enc = new TextEncoder();
  const cred = {
    id: 'idstr',
    rawId: enc.encode('rawId').buffer,
    type: 'public-key',
    response: {
      clientDataJSON: enc.encode('cdj').buffer,
      authenticatorData: enc.encode('authdata').buffer,
      signature: enc.encode('sig').buffer,
      userHandle: enc.encode('uh').buffer,
    },
  };
  const out = credentialToAuthenticationJSON(cred);
  assert.equal(out.response.signature, Buffer.from('sig').toString('base64url'));
  assert.equal(out.response.userHandle, Buffer.from('uh').toString('base64url'));
});

test('register() POSTs start + complete with bearer', async () => {
  const calls = [];
  const fetchImpl = async (url, init) => {
    calls.push({ url, init });
    if (url.endsWith('/register/start')) {
      return {
        ok: true,
        status: 200,
        json: async () => ({
          challenge: Buffer.from('chal').toString('base64url'),
          rp: { name: 'Otus', id: 'mahallem.ist' },
          user: { id: Buffer.from('uid').toString('base64url'), name: 'a@b', displayName: 'a' },
          pubKeyCredParams: [{ type: 'public-key', alg: -7 }],
          excludeCredentials: [],
        }),
        text: async () => '',
      };
    }
    if (url.endsWith('/register/complete')) {
      return {
        ok: true,
        status: 200,
        json: async () => ({ success: true, credential: { id: 'C', deviceName: 'D' } }),
        text: async () => '',
      };
    }
    throw new Error('unexpected url ' + url);
  };
  const enc = new TextEncoder();
  const navCreds = {
    create: async (_opts) => ({
      id: 'idstr',
      rawId: enc.encode('rawId').buffer,
      type: 'public-key',
      response: {
        clientDataJSON: enc.encode('cdj').buffer,
        attestationObject: enc.encode('attest').buffer,
        getTransports: () => ['internal'],
      },
      getClientExtensionResults: () => ({}),
    }),
  };
  const { window } = loadBridge({ fetchImpl, navCreds });
  const result = await window.recipeAppPasskey.register('TOKEN-XYZ');
  assert.equal(result.success, true);
  assert.equal(calls.length, 2);
  assert.match(calls[0].url, /\/recipes\/auth\/passkey\/register\/start$/);
  assert.equal(calls[0].init.headers['x-recipes-user-token'], 'TOKEN-XYZ');
  assert.match(calls[1].url, /\/recipes\/auth\/passkey\/register\/complete$/);
  assert.equal(calls[1].init.headers['x-recipes-user-token'], 'TOKEN-XYZ');
  const completeBody = JSON.parse(calls[1].init.body);
  assert.equal(completeBody.id, 'idstr');
  assert.ok(completeBody.deviceInfo, 'deviceInfo must be sent');
});

test('login() POSTs start + complete, no bearer', async () => {
  const calls = [];
  const fetchImpl = async (url, init) => {
    calls.push({ url, init });
    if (url.endsWith('/login/start')) {
      return {
        ok: true,
        status: 200,
        json: async () => ({
          challenge: Buffer.from('chal').toString('base64url'),
          allowCredentials: [],
          rpId: 'mahallem.ist',
        }),
        text: async () => '',
      };
    }
    if (url.endsWith('/login/complete')) {
      return {
        ok: true,
        status: 200,
        json: async () => ({
          success: true,
          token: 'NEW-TOKEN',
          user: { id: 'u1', email: 'a@b', fullName: 'A B', isAdmin: false },
        }),
        text: async () => '',
      };
    }
    throw new Error('unexpected url ' + url);
  };
  const enc = new TextEncoder();
  const navCreds = {
    get: async (_opts) => ({
      id: 'idstr',
      rawId: enc.encode('rawId').buffer,
      type: 'public-key',
      response: {
        clientDataJSON: enc.encode('cdj').buffer,
        authenticatorData: enc.encode('authdata').buffer,
        signature: enc.encode('sig').buffer,
        userHandle: enc.encode('uh').buffer,
      },
    }),
  };
  const { window } = loadBridge({ fetchImpl, navCreds });
  const result = await window.recipeAppPasskey.login('a@b');
  assert.equal(result.success, true);
  assert.equal(result.token, 'NEW-TOKEN');
  assert.equal(calls.length, 2);
  assert.equal(calls[0].init.headers['x-recipes-user-token'], undefined);
  assert.equal(JSON.parse(calls[0].init.body).email, 'a@b');
});

test('register() throws when WebAuthn unsupported', async () => {
  const { window } = loadBridge({ withPublicKeyCredential: false });
  await assert.rejects(() => window.recipeAppPasskey.register('TOKEN'), /not supported/i);
});

test('register() throws when token missing', async () => {
  const { window } = loadBridge();
  await assert.rejects(() => window.recipeAppPasskey.register(), /missing recipes-user-token/);
});

test('index.html loads passkey_bridge.js BEFORE flutter_bootstrap.js', () => {
  const html = fs.readFileSync(INDEX_PATH, 'utf8');
  // Match the actual <script src="..."> tags, not the loose tokens
  // (the page mentions both filenames in comments earlier).
  const bridgeIdx = html.indexOf('<script src="passkey_bridge.js"');
  const flutterIdx = html.indexOf('<script src="flutter_bootstrap.js"');
  assert.ok(bridgeIdx > 0, 'passkey_bridge.js <script> tag must be in index.html');
  assert.ok(flutterIdx > 0, 'flutter_bootstrap.js <script> tag must be in index.html');
  assert.ok(
    bridgeIdx < flutterIdx,
    'passkey_bridge.js must appear before flutter_bootstrap.js in index.html',
  );
});
