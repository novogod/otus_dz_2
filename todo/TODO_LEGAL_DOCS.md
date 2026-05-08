# Legal Documents Implementation - Chunked Task List

## Overview
Implement backend-hosted legal documentation for consent gate. 40 HTML files total:
- 10 languages: en, ru, es, fr, de, it, tr, ar, fa, ku
- 4 document types: terms, personal_data, cookies, storage
- URL format: `/recipes/legal/{lang}/{slug}.html`
- Legislation: GDPR (ES, FR, DE, IT), 152-FZ (RU), KVKK (TR), PDPL (SA), General (EN, FA, IQ)

## Chunk 1: Backend Route Setup ⏳
- [ ] Create Express route handler for `/recipes/legal/:lang/:slug.html`
- [ ] Create directory structure `/backend/legal/{lang}/` for all 10 languages
- [ ] Add route to serve `.html` files with proper Content-Type headers
- [ ] Test route returns 200 for valid language/slug combinations
- [ ] Test route returns 404 for invalid paths

## Chunk 2: English Legal Docs (en - US) ⏳
- [ ] Write `terms.html` - General ToS for US market
- [ ] Write `personal_data.html` - US consumer privacy notice
- [ ] Write `cookies.html` - Cookie policy for web users
- [ ] Write `storage.html` - Local storage policy for native app
- [ ] Verify all 4 files accessible at correct URLs

## Chunk 3: Russian Legal Docs (ru - 152-FZ) ⏳
- [ ] Write `terms.html` - Terms for Russian market
- [ ] Write `personal_data.html` - 152-FZ compliance notice (Russian language)
- [ ] Write `cookies.html` - Cookie policy (Russian language)
- [ ] Write `storage.html` - Storage policy (Russian language)
- [ ] Verify all 4 files accessible at correct URLs

## Chunk 4: Spanish Legal Docs (es - GDPR) ⏳
- [ ] Write `terms.html` - GDPR-compliant ToS (Spanish)
- [ ] Write `personal_data.html` - GDPR privacy notice (Spanish)
- [ ] Write `cookies.html` - ePrivacy cookie policy (Spanish)
- [ ] Write `storage.html` - Storage policy (Spanish)
- [ ] Verify all 4 files accessible at correct URLs

## Chunk 5: French Legal Docs (fr - GDPR) ⏳
- [ ] Write `terms.html` - GDPR-compliant ToS (French)
- [ ] Write `personal_data.html` - GDPR privacy notice (French)
- [ ] Write `cookies.html` - ePrivacy cookie policy (French)
- [ ] Write `storage.html` - Storage policy (French)
- [ ] Verify all 4 files accessible at correct URLs

## Chunk 6: German Legal Docs (de - GDPR) ⏳
- [ ] Write `terms.html` - GDPR-compliant ToS (German)
- [ ] Write `personal_data.html` - GDPR privacy notice (German)
- [ ] Write `cookies.html` - ePrivacy cookie policy (German)
- [ ] Write `storage.html` - Storage policy (German)
- [ ] Verify all 4 files accessible at correct URLs

## Chunk 7: Italian Legal Docs (it - GDPR) ⏳
- [ ] Write `terms.html` - GDPR-compliant ToS (Italian)
- [ ] Write `personal_data.html` - GDPR privacy notice (Italian)
- [ ] Write `cookies.html` - ePrivacy cookie policy (Italian)
- [ ] Write `storage.html` - Storage policy (Italian)
- [ ] Verify all 4 files accessible at correct URLs

## Chunk 8: Turkish Legal Docs (tr - KVKK) ⏳
- [ ] Write `terms.html` - KVKK-compliant ToS (Turkish)
- [ ] Write `personal_data.html` - KVKK personal data notice (Turkish)
- [ ] Write `cookies.html` - Cookie policy (Turkish)
- [ ] Write `storage.html` - Storage policy (Turkish)
- [ ] Verify all 4 files accessible at correct URLs

## Chunk 9: Arabic Legal Docs (ar - PDPL) ⏳
- [ ] Write `terms.html` - PDPL-compliant ToS (Arabic)
- [ ] Write `personal_data.html` - PDPL personal data notice (Arabic)
- [ ] Write `cookies.html` - Cookie policy (Arabic)
- [ ] Write `storage.html` - Storage policy (Arabic)
- [ ] Verify all 4 files accessible at correct URLs

## Chunk 10: Persian Legal Docs (fa - General) ⏳
- [ ] Write `terms.html` - General ToS (Persian)
- [ ] Write `personal_data.html` - Privacy notice (Persian)
- [ ] Write `cookies.html` - Cookie policy (Persian)
- [ ] Write `storage.html` - Storage policy (Persian)
- [ ] Verify all 4 files accessible at correct URLs

## Chunk 11: Kurdish Legal Docs (ku - General) ⏳
- [ ] Write `terms.html` - General ToS (Kurdish)
- [ ] Write `personal_data.html` - Privacy notice (Kurdish)
- [ ] Write `cookies.html` - Cookie policy (Kurdish)
- [ ] Write `storage.html` - Storage policy (Kurdish)
- [ ] Verify all 4 files accessible at correct URLs

## Chunk 12: End-to-End Testing ⏳
- [ ] Test consent modal displays checkboxes with correct country/legislation labels
- [ ] Click each legal doc link and verify browser opens correct HTML
- [ ] Verify all 40 files are accessible
- [ ] Test with multiple language selections
- [ ] Test on web platform (cookies path) and verify persistence
- [ ] Deploy to live environment

---

**Total Files to Create**: 40 HTML documents
**Backend Changes**: 1 route handler + directory structure
**Estimated Effort**: 12 focused chunks
