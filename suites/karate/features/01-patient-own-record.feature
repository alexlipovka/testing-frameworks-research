Feature: 1. Patient reads their own record (matcho), not someone else's

Scenario: pat-self reads own Patient: allowed by patient-role-policy
  * def r = call read('classpath:lib/ap.feature') { who: 'pat-self', method: 'GET', path: '#("/fhir/Patient/" + id("patient-self"))' }
  * match r.verdict contains { allowedBy: ['patient-role-policy'], crashed: [], status: 200 }
  * match r.response.id == id('patient-self')

Scenario: pat-self reads another Patient: denied by every policy
  * def r = call read('classpath:lib/ap.feature') { who: 'pat-self', method: 'GET', path: '#("/fhir/Patient/" + id("patient-other"))' }
  * match r.verdict contains { allowedBy: [], crashed: [], status: 403 }

Scenario Outline: pat-self on <resource>: <verdict>
  * def r = call read('classpath:lib/ap.feature') { who: 'pat-self', method: 'GET', path: '#("/fhir/" + "<resource>" + "/" + id("<fixture>"))' }
  * match r.verdict contains { allowedBy: <allowedBy>, crashed: [], status: <status> }

  Examples:
    | resource    | fixture      | verdict                         | allowedBy                         | status |
    | Encounter   | enc-match    | own Encounter allows            | ['as-patient-read-own-encounter'] | 200    |
    | Encounter   | enc-mismatch | another patient's denies        | []                                | 403    |
    | Observation | enc-match    | Encounter id, wrong type denies | []                                | 403    |
