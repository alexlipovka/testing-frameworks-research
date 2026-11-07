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
