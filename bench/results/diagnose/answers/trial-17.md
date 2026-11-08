**Root cause:** AccessPolicy `receptionist-role-policy` was over-broadened, so the receptionist role now gets allowed on requests it should be denied.

**What most likely changed:** The policy's request constraints were removed or widened, probably in its matcher, so that it effectively matches on the receptionist role alone or nearly so. The output does not show the policy body or the diff, so this is inferred from the failures:
- All 4 failures (of 93 tests) are `rec` requests with expected deny, and each was granted by this one policy. No other role or policy appears.
- The wrongly allowed requests span write methods and resource types: PUT `Patient`, PATCH `Patient` (merge-patch), GET search on `Observation`, and GET read on `Encounter`.
- A change limited to one method or one resource type would not explain this spread. Both the method restriction (the PUT and PATCH grants) and the resource or URI restriction (the `Observation` and `Encounter` grants) appear to be gone. One edit that dropped or loosened the matcher would do both.
- The failures are grants rather than denials, and the 89 passing tests include no visible regression in access that should be allowed. This fits a loosened policy, not a broken one.

**Limit:** The log only shows failing tests, so I can't tell which other `rec` deny cases still passed, or exactly which matcher field was edited.

**Decisive lines:**
- `AssertionError: expected deny, granted by ['receptionist-role-policy']`
- `FAILED tests/test_04_receptionist.tavern.yaml::rec cannot write Patient`
- `FAILED tests/test_06_search_leak.tavern.yaml::out-of-scope search is denied[rec-fhir/Observation]`

**Confidence:** high on the policy id and the direction of the change (over-permissive). Medium on the exact nature of the edit.

The count below covers the single Read and excludes this handback.

TOOL_CALLS: 1
