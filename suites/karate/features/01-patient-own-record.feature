Feature: 1. Patient reads their own record (matcho), not someone else's

Scenario: pat-self reads own Patient: allowed by patient-role-policy
  * def r = call read('classpath:lib/ap.feature') { who: 'pat-self', method: 'GET', path: '#("/fhir/Patient/" + id("patient-self"))' }
  * match r.allowedBy == ['patient-role-policy']
  * match r.crashed == []
  * match r.status == 200
  * match r.response.id == id('patient-self')

Scenario: pat-self reads another Patient: denied by every policy
  * def r = call read('classpath:lib/ap.feature') { who: 'pat-self', method: 'GET', path: '#("/fhir/Patient/" + id("patient-other"))' }
  * match r.allowedBy == []
  * match r.crashed == []
  * match r.status == 403

Scenario Outline: pat-self reads <path>: <verdict>
  * def r = call read('classpath:lib/ap.feature') { who: 'pat-self', method: 'GET', path: '#("<path>".replace("{run}", runId))' }
  * match r.allowedBy == <allowedBy>
  * match r.crashed == []
  * match r.status == <status>

  Examples:
    | path                                | verdict                                  | allowedBy                         | status |
    | /fhir/Encounter/{run}-enc-match     | own Encounter, allowed                   | ['as-patient-read-own-encounter'] | 200    |
    | /fhir/Encounter/{run}-enc-mismatch  | another Patient's Encounter, denied      | []                                | 403    |
    | /fhir/Observation/{run}-enc-match   | an Encounter id under another type, denied | []                              | 403    |
