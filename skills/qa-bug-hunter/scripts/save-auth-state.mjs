// save-auth-state.mjs
// One-time login helper. Opens a real browser; YOU log in by hand; it saves the authenticated
// browser state (cookies + localStorage) to a JSON file. No credentials ever touch this script.
//
// The resulting file works both as the Playwright MCP's --storage-state and as a storageState
// fixture in a normal `playwright test` suite.
//
// Usage (run inside the target project):
//   npm i -D @playwright/test && npx playwright install chromium      # once, if not already set up
//   BASE_URL=http://localhost:3000 OUT=qa-bug-hunt/.auth/state.json node /path/to/save-auth-state.mjs
//
// Then load it into the MCP (see references/auth-and-sessions.md):
//   "args": ["@playwright/mcp@latest", "--isolated", "--storage-state=./qa-bug-hunt/.auth/state.json"]
//
// The output lives under qa-bug-hunt/, which is already gitignored — it is a live session, so don't
// copy it elsewhere.

import { chromium } from 'playwright';
import { mkdir } from 'node:fs/promises';
import path from 'node:path';

const BASE_URL = process.env.BASE_URL ?? 'http://localhost:3000';
const OUT = process.env.OUT ?? 'qa-bug-hunt/.auth/state.json';

const browser = await chromium.launch({ headless: false });
const context = await browser.newContext();
const page = await context.newPage();
await page.goto(BASE_URL, { waitUntil: 'domcontentloaded' });

console.log(`\n>> Browser opened at ${BASE_URL}.`);
console.log('>> Log in by hand, reach a logged-in page, then press Enter here to save the session.\n');
await new Promise((resolve) => process.stdin.once('data', resolve));

await mkdir(path.dirname(OUT), { recursive: true });
await context.storageState({ path: OUT });
console.log(`\n>> Saved authenticated state to ${OUT}\n`);

await browser.close();
process.exit(0);
