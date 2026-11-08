**Root cause:** AccessPolicy `receptionist-role-policy` was broadened so that it now matches Patient requests for the receptionist role, including reads and writes. The most likely change is that its resource/URI constraint was widened or removed. At baseline it evidently did not match Patient at all, because the tests expected Patient reads to be allowed only by `as-receptionist-read-patients` and Patient writes to match nothing. It still allows Appointment, as before.

**What the output shows**
- `rec` read and search on Patient now report `allowedBy` as `["receptionist-role-policy","as-receptionist-read-patients"]`.
- `rec` PUT, POST and PATCH on Patient now report `["receptionist-role-policy"]` instead of `[]`.
- The writes really succeeded and were not just mis-reported by `__debug=policy`:
  - Line 186: PUT returned 200.
  - Line 227: POST /fhir/Patient returned 201.
  - Lines 228 and 504: PATCH returned 200.
- `as-receptionist-read-patients` is unchanged. It is still listed for reads and is not credited for any write.

**The other failures are knock-on effects of the same change**
- `07 none of the attempts changed the Patient`: `given` is now `X`, because the receptionist's PATCH landed.
- `14 every Bakeoff Patient on the server is this run's`: the stray server-assigned id `01a1b818-d2d4-...` is most likely the Patient created by the receptionist's POST.
- `08-matrix` (rec) and `06 rec searches Patients` fail on the same `allowedBy` mismatch.

**What the output cannot settle:** whether the policy now allows all resources for `rec` or only added Patient. No failing assertion shows it matching anything beyond Patient and its existing Appointment access. The log has no user labels on requests, so I can't confirm which other requests were made by `rec`. DELETE by `rec` is not visibly exercised.

**Decisive lines**
- `["read: want [\"as-receptionist-read-patients\"], got [\"receptionist-role-policy\",\"as-receptionist-read-patients\"] status 200","search: want [\"as-receptionist-read-patients\"], got [\"receptionist-role-policy\",\"as-receptionist-read-patients\"] status 200","update: want [], got [\"receptionist-role-policy\"] status 200"]`
- `- rec POST on Patient is denied` followed by `["receptionist-role-policy"]` (expected `[]`)
- `22:19:57.022 [virtual-57] INFO  karate.http - 2 < 201 POST http://localhost:8280/fhir/Patient (13 ms)`

**Confidence:** high on the policy id and that it now grants Patient read and write to the receptionist; medium on the exact edit.

The count below is my 2 Read calls and excludes this hand-off.

TOOL_CALLS: 2
