**Root cause:** AccessPolicy `as-receptionist-read-patients` was widened so that it also permits PATCH on Patient. It should be read-only for the receptionist. The most likely edit is to its request-method matcher, for example `get` changed to a pattern or or-clause that also matches `patch`. The output does not show the policy body, so the exact form of the edit is inferred.

**Evidence:**
- All 5 failures (of 94 scenarios) come from this one fault, in the two features `04-receptionist-read-not-write` and `07-bypass-attempts`.
- Three failures are `match r.allowedBy == []` on receptionist PATCH scenarios (JSON Patch, merge-patch, and the plain "rec PATCH on Patient"). The `__debug=policy` response names this policy as the one granting access.
- The other two failures are downstream: the PATCH was actually applied, so `name[0].given` is `["X"]` instead of `["Self"]`.
- The widening looks specific to PATCH. The "rec ... denied" scenarios for other methods are not among the failures, and no other policy id appears anywhere in the failures. The log shows POST and PUT to Patient mostly returning 403, but it does not label requests by user, so I can't tie individual 403s to the receptionist.
- The features covering patient self-access, practitioner consent, no-role denial, search leaks and SDC all passed, so the other policies look unaffected.

**Decisive lines:**
- `- rec PATCH on Patient is denied` (feature 04, line 27, `* match r.allowedBy == []`)
- `["as-receptionist-read-patients"]` (the actual `allowedBy`, expected `[]`)
- `* match response.name[0].given == ['Self']`, which failed with actual `["X"]`, showing the write really went through

**Confidence:** high on the policy and on the PATCH being newly allowed; medium on the exact matcher edit.

The count below is my two Read calls on the log and excludes this hand-back call.

TOOL_CALLS: 2
