**Root cause:** the AccessPolicy `practitioner-policy` (id as shown in the debug output) no longer enforces the Consent status check. Its rule most likely joins Consent on practitioner and patient, and the `status = 'active'` condition was removed or widened. As a result, a revoked or non-active Consent now grants access just as an active one does.

**Evidence:**
- 93 of 94 scenarios pass. The only failure is `p1 reads patient-other: revoked Consent denies`. The fixtures include `consent-p1-other-revoked`, so p1's only link to patient-other is a revoked Consent.
- `?__debug=policy` shows `practitioner-policy` as the policy allowing that request, where the suite expects no policy at all.
- The other 4 scenarios in `02-practitioner-consent.feature` still pass, and so do the no-role, receptionist, patient-own-record and search-leak features. This suggests the practitioner-to-patient matching and the operation scope are intact, and that active Consents still grant access. Only the status condition appears to have changed. This is inferred, because the log does not show the scenario bodies.

**What the output can't show:** the policy body is not in the log, so I can't tell whether the status clause was deleted outright or changed to accept other values (for example, `inactive` or `rejected` as well as `active`). The direction is an over-grant, not a new denial.

**Decisive lines:**
```
- p1 reads patient-other: revoked Consent denies
* match r.allowedBy == []
["practitioner-policy"]
```

**Confidence:** high

TOOL_CALLS: 2
