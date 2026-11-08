Feature: 2. Practitioner sees a Patient through an active Consent (SQL); a revoked one does not count

Scenario Outline: <who> reads <patient>: <verdict>
  * def r = call read('classpath:lib/ap.feature') { who: '<who>', method: 'GET', path: '#("/fhir/Patient/" + id("<patient>"))' }
  * match r.verdict contains { allowedBy: <allowedBy>, crashed: [], status: <status> }

  Examples:
    | who | patient          | verdict                   | allowedBy               | status |
    | p1  | patient-self     | active Consent allows     | ['practitioner-policy'] | 200    |
    | p2  | patient-other    | active Consent allows     | ['practitioner-policy'] | 200    |
    | p1  | patient-other    | revoked Consent denies    | []                      | 403    |
    | p2  | patient-self     | no Consent denies         | []                      | 403    |
    | p1  | patient-unlinked | no Consent denies         | []                      | 403    |
