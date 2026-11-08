**Root cause:** the receptionist's AccessPolicy was most likely widened so that it now allows PATCH on Patient. It should be read-only, so the likely change is `patch` added to its allowed request methods, or the method constraint loosened or removed. The output never shows a policy id, so I can only identify it by role, from the test name `04-receptionist-read-not-write`.

**What the output supports:**
- `04-receptionist-read-not-write` and `07-bypass` both fail the same way: `PATCH /fhir/Patient/{{run_id}}-patient-self` expected 403 and got 200. `07-bypass` doesn't show which identity it uses, but the same PATCH failing suggests the same over-permissive rule.
- `14-run-isolation` looks like a knock-on effect, not a separate fault. The search for `family:exact=Bakeoff` returns 2 patients instead of 3, and only `patient-self` is missing. That fits the wrongly allowed PATCH having actually been applied and changed that patient's family name, so it no longer matches. It is also consistent with the single-change premise.
- The change is not a global allow-all. `05-norole-denied`, `06-search-leak`, `01-patient-own-record` and `02-practitioner-consent` all still pass.

**What the output cannot show:** Hurl stops a file at its first failed request, so any write checks after that PATCH in file 04 may not have run. PATCH is the only method proven to be over-allowed; POST, PUT or DELETE may or may not be affected.

**Decisive lines:**
- `--> cases/04-receptionist-read-not-write.hurl:47:6`
- `47 | HTTP 403` with `^^^ actual value is <200>` (on `PATCH {{url}}/fhir/Patient/{{run_id}}-patient-self`)
- `actual:   list <[bakeoff-5d10ffcb-patient-other,bakeoff-5d10ffcb-patient-unlinked]>`

**Confidence:** medium. The receptionist policy and PATCH being newly allowed are well supported, but the policy id and the exact edit are inferred.

The count below excludes this final handback call.

TOOL_CALLS: 1
