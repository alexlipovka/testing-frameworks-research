**Root cause:** AccessPolicy `practitioner-policy` most likely lost the consent-status check, `c.resource->>'status' = 'active'`, from its SQL matcher.

With that check gone, any Consent naming the practitioner as an actor grants access, including a non-active one. `practitioner1` can now read `bakeoff-d276bb1d-patient-other`, which the suite expects to be denied with 403. The request returns 200 instead.

**Evidence:**
- In the `__debug=policy` trace, `practitioner-policy` is the only policy with `eval-result: true`.
- Its first `and` branch passes. Its SQL branch only checks patient id and actor id, and it returned true for `patient-other`.
- Both sibling practitioner policies, `as-practitioner-search-consented-patients` and `as-practitioner-sdc-consented-patient`, join the same consent/actor tables but include `c.resource->>'status' = 'active'`. `practitioner-policy` is the outlier.
- The only failing file is `cases/02-practitioner-consent.hurl`, on the two `patient-other` assertions. The other 17 files pass, including the p1/p2 matrices and the role, search and bypass cases. That fits a narrow loosening, not a broad allow, a role change or a broken actor match.

The log does not show the baseline policy or the Consent fixture's status. That the removed clause was the status filter, and that `patient-other`'s consent is non-active, is inferred from the sibling policies and the test's expected denial.

**Decisive lines (line 13 is one very long line, so these are excerpts):**
1. Log line 13: `{"eval-result":true,"query":["SELECT true\nFROM consent c\nJOIN jsonb_array_elements(c.resource#>'{provision,actor}') AS actor ON true\nWHERE c.resource#>>'{patient,id}' = ?\n  AND actor#>>'{reference,id}' = ?\nLIMIT 1\n","bakeoff-d276bb1d-patient-other","practitioner1"]}],"id":"practitioner-policy"`
2. Log line 21: `actual:   string <practitioner-policy>` (for the assertion that no policy evaluates true)
3. Log line 48: `28 | HTTP 403` / `actual value is <200>`

**Confidence:** high for the policy id, and medium-high for the specific change (status filter removed).

The count below covers the one file read and excludes this handback call.

TOOL_CALLS: 1
