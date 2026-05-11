/* recipe_list/web/passkey_bridge.js
 * ------------------------------------------------------------------
 * Bridges the recipe-app web build's Dart code to the browser's
 * WebAuthn / Web Authentication API. The Dart side (passkey_web.dart,
 * Chunk 24) calls window.recipeAppPasskey.{register, login} and
 * receives a Promise resolving to a plain JSON object that maps
 * 1:1 onto the JSON the backend's /recipes/auth/passkey/* endpoints
 * expect/return.
 *
 * Why a plain JS bridge instead of dart:js_interop directly:
 *   - WebAuthn data uses ArrayBuffer for credential / challenge /
 *     publicKey / signature / clientDataJSON / authenticatorData /
 *     userHandle. Translating those buffers to/from Dart is fiddly
 *     and risks losing bytes through erroneous string conversions.
 *     Doing the JSON↔ArrayBuffer dance once, in JS, then handing a
 *     pure-JSON object across the JS/Dart boundary is robust.
 *   - Browsers ship `PublicKeyCredential.parseCreationOptionsFromJSON`
 *     and `parseRequestOptionsFromJSON` in a staged rollout (Chrome
 *     124+, Firefox 119+, Safari 17+). Where present, we use them —
 *     they understand the WebAuthn JSON encoding directly. Where
 *     absent, we fall back to manual base64url decoding for the
 *     fields that need it.
 *
 * Loaded BEFORE flutter_bootstrap.js so window.recipeAppPasskey is
 * always defined by the time Dart asks for it.
 *
 * Deployed as part of Chunk 23 of
 * todo/auth-session-401-recurrence-2026-05-08.md.
 */
(function () {
  'use strict';

  // ----------------------------------------------------------------
  // base64url helpers (fallback for older browsers without
  // PublicKeyCredential.*FromJSON).
  // ----------------------------------------------------------------
  function b64urlToBuffer(b64url) {
    if (typeof b64url !== 'string') {
      throw new TypeError('expected base64url string, got ' + typeof b64url);
    }
    const pad = '='.repeat((4 - (b64url.length % 4)) % 4);
    const b64 = (b64url + pad).replace(/-/g, '+').replace(/_/g, '/');
    const bin = atob(b64);
    const bytes = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    return bytes.buffer;
  }

  function bufferToB64url(buf) {
    const bytes = new Uint8Array(buf);
    let bin = '';
    for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
    return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  }

  // Manual conversion of a server-supplied creation-options JSON
  // (challenge, user.id, excludeCredentials[].id) into the
  // ArrayBuffer-shaped form `navigator.credentials.create` expects.
  function decodeCreationOptions(json) {
    const out = Object.assign({}, json);
    out.challenge = b64urlToBuffer(json.challenge);
    if (json.user && typeof json.user.id === 'string') {
      out.user = Object.assign({}, json.user, { id: b64urlToBuffer(json.user.id) });
    }
    if (Array.isArray(json.excludeCredentials)) {
      out.excludeCredentials = json.excludeCredentials.map((c) =>
        Object.assign({}, c, { id: b64urlToBuffer(c.id) }),
      );
    }
    return out;
  }

  function decodeRequestOptions(json) {
    const out = Object.assign({}, json);
    out.challenge = b64urlToBuffer(json.challenge);
    if (Array.isArray(json.allowCredentials)) {
      out.allowCredentials = json.allowCredentials.map((c) =>
        Object.assign({}, c, { id: b64urlToBuffer(c.id) }),
      );
    }
    return out;
  }

  // ----------------------------------------------------------------
  // PublicKeyCredential → JSON (registration / authentication).
  // ----------------------------------------------------------------
  function credentialToRegistrationJSON(cred) {
    // Always use manual conversion for registration - browser's toJSON() may include
    // extra fields like authenticatorData or publicKey that @simplewebauthn doesn't expect.
    const r = cred.response;
    const json = {
      id: cred.id,
      rawId: bufferToB64url(cred.rawId),
      type: cred.type,
      authenticatorAttachment: cred.authenticatorAttachment || null,
      response: {
        clientDataJSON: bufferToB64url(r.clientDataJSON),
        attestationObject: bufferToB64url(r.attestationObject),
        transports:
          typeof r.getTransports === 'function' ? r.getTransports() : ['internal'],
      },
      clientExtensionResults:
        typeof cred.getClientExtensionResults === 'function'
          ? cred.getClientExtensionResults()
          : {},
    };
    return json;
  }

  function credentialToAuthenticationJSON(cred) {
    // Always use manual conversion for authentication - browser's toJSON() may include
    // unexpected extra fields.
    const r = cred.response;
    const json = {
      id: cred.id,
      rawId: bufferToB64url(cred.rawId),
      type: cred.type,
      authenticatorAttachment: cred.authenticatorAttachment || null,
      response: {
        clientDataJSON: bufferToB64url(r.clientDataJSON),
        authenticatorData: bufferToB64url(r.authenticatorData),
        signature: bufferToB64url(r.signature),
        userHandle: r.userHandle ? bufferToB64url(r.userHandle) : null,
      },
      clientExtensionResults:
        typeof cred.getClientExtensionResults === 'function'
          ? cred.getClientExtensionResults()
          : {},
    };
    return json;
  }

  // ----------------------------------------------------------------
  // Device-info heuristics, sent up with register/complete so the
  // user can later identify a passkey row in their settings list.
  // ----------------------------------------------------------------
  function detectDeviceInfo() {
    const ua = navigator.userAgent || '';
    const platform =
      (navigator.userAgentData && navigator.userAgentData.platform) ||
      navigator.platform ||
      '';
    let osName = 'Unknown';
    if (/Mac/i.test(platform) || /Mac OS X/i.test(ua)) osName = 'macOS';
    else if (/Win/i.test(platform)) osName = 'Windows';
    else if (/Android/i.test(ua)) osName = 'Android';
    else if (/iPhone|iPad|iPod/i.test(ua)) osName = 'iOS';
    else if (/Linux/i.test(platform)) osName = 'Linux';

    let browserName = 'Unknown';
    if (/Edg\//.test(ua)) browserName = 'Edge';
    else if (/Chrome\//.test(ua) && !/Edg\//.test(ua)) browserName = 'Chrome';
    else if (/Firefox\//.test(ua)) browserName = 'Firefox';
    else if (/Safari\//.test(ua) && !/Chrome\//.test(ua)) browserName = 'Safari';

    return {
      name: browserName + ' on ' + osName,
      type: 'platform',
      os: osName,
      browser: browserName,
    };
  }

  // ----------------------------------------------------------------
  // Public API (window.recipeAppPasskey.{register,login,available}).
  // ----------------------------------------------------------------

  // Exposed for tests.
  const __internals = {
    b64urlToBuffer,
    bufferToB64url,
    decodeCreationOptions,
    decodeRequestOptions,
    credentialToRegistrationJSON,
    credentialToAuthenticationJSON,
    detectDeviceInfo,
  };

  // WebAuthn RP-ID for this app. Passkeys are bound to this host
  // (or any subdomain) and CANNOT succeed from another origin
  // such as snackhack.app — navigator.credentials.get/create will
  // throw SecurityError. Short-circuit before we hit the network.
  const PASSKEY_RP_ID = 'mahallem.ist';
  function hostMatchesRpId() {
    const h = (window.location && window.location.hostname || '').toLowerCase();
    return h === PASSKEY_RP_ID || h.endsWith('.' + PASSKEY_RP_ID);
  }

  async function register(token) {
    if (!token) throw new Error('register: missing recipes-user-token');
    if (!window.PublicKeyCredential) {
      throw new Error('WebAuthn not supported in this browser');
    }
    if (!hostMatchesRpId()) {
      throw new Error('Passkey registration is only available on recipies.mahallem.ist');
    }
    const startResp = await fetch('/recipes/auth/passkey/register/start', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-recipes-user-token': token,
      },
      body: '{}',
    });
    if (!startResp.ok) {
      const text = await startResp.text();
      throw new Error('register/start failed: ' + startResp.status + ' ' + text);
    }
    const optionsJSON = await startResp.json();

    let publicKey;
    if (typeof PublicKeyCredential.parseCreationOptionsFromJSON === 'function') {
      publicKey = PublicKeyCredential.parseCreationOptionsFromJSON(optionsJSON);
    } else {
      publicKey = decodeCreationOptions(optionsJSON);
    }

    const cred = await navigator.credentials.create({ publicKey });
    if (!cred) throw new Error('User cancelled passkey registration');

    const credJSON = credentialToRegistrationJSON(cred);
    console.log('[PASSKEY_BRIDGE] credentialToRegistrationJSON returned response keys:', Object.keys(credJSON.response));
    
    const completeBody = {
      ...credJSON,
      deviceInfo: detectDeviceInfo(),
    };
    
    console.log('[PASSKEY_BRIDGE] Final completeBody.response keys:', Object.keys(completeBody.response));

    const completeResp = await fetch('/recipes/auth/passkey/register/complete', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-recipes-user-token': token,
      },
      body: JSON.stringify(completeBody),
    });
    if (!completeResp.ok) {
      const text = await completeResp.text();
      throw new Error('register/complete failed: ' + completeResp.status + ' ' + text);
    }
    return await completeResp.json();
  }

  async function login(email) {
    if (!window.PublicKeyCredential) {
      throw new Error('WebAuthn not supported in this browser');
    }
    if (!hostMatchesRpId()) {
      throw new Error('Passkey sign-in is only available on recipies.mahallem.ist');
    }
    const startResp = await fetch('/recipes/auth/passkey/login/start', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(email ? { email } : {}),
    });
    if (!startResp.ok) {
      const text = await startResp.text();
      throw new Error('login/start failed: ' + startResp.status + ' ' + text);
    }
    const optionsJSON = await startResp.json();

    let publicKey;
    if (typeof PublicKeyCredential.parseRequestOptionsFromJSON === 'function') {
      publicKey = PublicKeyCredential.parseRequestOptionsFromJSON(optionsJSON);
    } else {
      publicKey = decodeRequestOptions(optionsJSON);
    }

    const cred = await navigator.credentials.get({
      publicKey,
      mediation: 'optional',
    });
    if (!cred) throw new Error('User cancelled passkey login');

    const completeBody = credentialToAuthenticationJSON(cred);
    const completeResp = await fetch('/recipes/auth/passkey/login/complete', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(completeBody),
    });
    if (!completeResp.ok) {
      const text = await completeResp.text();
      throw new Error('login/complete failed: ' + completeResp.status + ' ' + text);
    }
    return await completeResp.json();
  }

  async function available() {
    if (!window.PublicKeyCredential) return { supported: false };
    let platformAvailable = false;
    try {
      platformAvailable = await PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable();
    } catch {
      platformAvailable = false;
    }
    let conditionalUI = false;
    if (typeof PublicKeyCredential.isConditionalMediationAvailable === 'function') {
      try {
        conditionalUI = await PublicKeyCredential.isConditionalMediationAvailable();
      } catch {
        conditionalUI = false;
      }
    }
    return {
      supported: true,
      platformAvailable,
      conditionalUI,
    };
  }

  window.recipeAppPasskey = { register, login, available, __internals };
})();
