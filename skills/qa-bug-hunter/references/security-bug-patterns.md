# Security — high-yield bug classes

Defensive QA on the user's own code: find security defects and confirm them with the smallest
possible probe, against **local/staging only — never production**. Crafted inputs here are harmless
probes — assert that escaping/rejection happens, never demonstrate actual exploitation. Two security
classes live elsewhere: **authorization/IDOR** and **SQL injection** are in
`backend-bug-patterns.md`. Same format as the other catalogs: failure shape → what to inspect or
grep → how to confirm.

## XSS (cross-site scripting)
- Failure: user input rendered into HTML unescaped — reflected (from the request) or stored (from
  the DB).
- Inspect: `innerHTML`, `dangerouslySetInnerHTML`, `v-html`, `|safe`, `mark_safe`, `html.raw`,
  template autoescape disabled, sanitizer allowlists.
- Confirm: unit test feeding `<script>x</script>` or `" onmouseover=` through the render/sanitize
  function; assert the output is escaped/stripped.

## CSRF
- Failure: state-changing endpoint accepts requests without CSRF protection; or a GET mutates state
  (CSRF-able by an `<img>` tag).
- Inspect: CSRF middleware exemptions (`csrf_exempt`, ignore lists), `SameSite=None` cookies,
  routes where GET creates/updates/deletes.
- Confirm: test posting to the endpoint without the token; assert it's rejected. A passing
  (accepted) request is the failing repro.

## SSRF (server-side request forgery)
- Failure: a user-controlled URL is fetched server-side and can reach internal hosts or cloud
  metadata.
- Inspect: `fetch`/`requests.get`/`http.Get` whose URL derives from request input; whether redirects
  are followed; blocklist-instead-of-allowlist validation.
- Confirm: unit test passing `http://127.0.0.1`, `http://169.254.169.254`, `file:///` to the URL
  validator; assert each is rejected.

## Path traversal
- Failure: `../` in a user-supplied filename escapes the intended directory.
- Inspect: path joins with request input (`os.path.join(base, name)`, string concat), file-serving
  endpoints, archive extraction.
- Confirm: test with `../../etc/passwd`-style input; assert the resolved path stays inside the base
  directory (or the request is rejected).

## Mass assignment / over-binding
- Failure: a request body is bound wholesale to a model, letting a caller set fields they shouldn't
  (`is_admin`, `price`, `owner_id`).
- Inspect: `**params` / `Object.assign(entity, req.body)` / ORM `update(**data)`, serializers
  without an explicit field allowlist.
- Confirm: test sending the normal payload plus one privileged field; assert the privileged field is
  ignored.

## Insecure deserialization
- Failure: untrusted data fed to a code-executing deserializer.
- Inspect: `pickle.loads`, `yaml.load` without `SafeLoader`, `Marshal.load`, `unserialize`,
  `ObjectInputStream` on external input.
- Confirm: usually by inspection (the call + the untrusted source is the evidence); where a test
  helps, assert the safe loader rejects a crafted-but-harmless tag.

## Open redirects
- Failure: a redirect target taken from a query parameter without validation
  (`redirect(request.args["next"])`).
- Inspect: every redirect whose target derives from the request.
- Confirm: test with `next=https://evil.example`; assert it's rejected or normalized to a local path.

## Secrets in code & logs
- Failure: API keys/tokens/passwords committed to the repo, or written to logs.
- Inspect: grep for `AKIA`, `-----BEGIN`, `api_key`, `secret`, `password` assignments with literal
  values; log statements that serialize request headers, auth payloads, or full request bodies.
- Confirm: a committed secret is Confirmed **by inspection** — the evidence is the exact location
  (redact the value itself to `***` everywhere, per the report rules). For logging: unit test that
  captures log output around an authenticated call and asserts no token text appears.

## Weak / misused crypto
- Failure: fast hashes (MD5/SHA-1) for passwords, ECB mode, static IV or salt, homegrown crypto,
  non-constant-time comparison of secrets.
- Inspect: `hashlib.md5`/`sha1` near passwords, `AES/ECB`, hardcoded IV/salt constants, `==` on
  HMACs/tokens.
- Confirm: mostly by inspection; a targeted test can demonstrate the property (e.g. two equal
  plaintext blocks → equal ciphertext blocks under ECB).

## Confirmation & severity notes
- Some classes (committed secret, ECB, unsafe deserializer call) are **Confirmed by inspection** —
  the defect is the artifact itself, not a behavior; cite the exact location as evidence.
- Behavior classes (XSS, SSRF, traversal, mass assignment, open redirect, CSRF) get the standard
  smallest-failing-test treatment in the project's own framework.
- Severity follows the normal rubric: confirmed XSS/SSRF/traversal is typically Critical or High
  (data exposure) — give the usual impact × reach rationale, don't auto-max everything.
