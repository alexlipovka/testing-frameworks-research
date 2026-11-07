Feature: 6. Searches return nothing outside the caller's scope

Background:
  * def ap = read('classpath:lib/ap.feature')
  * def self = 'Patient/' + id('patient-self')
  * def other = 'Patient/' + id('patient-other')

Scenario Outline: pat-self searches own Observations as <subject>: allowed, own data only
  * def r = call ap { who: 'pat-self', method: 'GET', path: '/fhir/Observation', params: { subject: '<subject>' } }
  * match r.allowedBy == ['as-patient-search-own-observations']
  * match r.status == 200
  * def ids = karate.map(r.response.entry, e => e.resource.id)
  * match ids contains id('obs-match')
  * match ids !contains id('obs-mismatch')
  * match each r.response.entry[*].resource.subject.reference == self

  Examples:
    | subject                     |
    | #(self)                     |
    | #(id("patient-self"))       |

Scenario Outline: pat-self search <case>: denied
  * def r = call ap { who: 'pat-self', method: 'GET', path: '/fhir/Observation', params: <params> }
  * match r.allowedBy == []
  * match r.crashed == []
  * match r.status == 403

  Examples:
    | case                         | params                                                    |
    | for another Patient          | { subject: '#(other)' }                                   |
    | with no subject              | {}                                                        |
    | with a second subject        | { subject: ['#(self)', '#(other)'] }                      |
    | with _include                | { subject: '#(self)', _include: 'Observation:subject' }   |
    | with _revinclude             | { subject: '#(self)', _revinclude: 'Provenance:target' }  |

Scenario: p1 searches Patient by a consented _id: allowed, that Patient only
  * def r = call ap { who: 'p1', method: 'GET', path: '/fhir/Patient', params: { _id: '#(id("patient-self"))' } }
  * match r.allowedBy == ['as-practitioner-search-consented-patients']
  * match r.status == 200
  * match r.response.entry[*].resource.id == ['#(id("patient-self"))']

Scenario Outline: p1 searches Patient <case>: denied
  * def r = call ap { who: 'p1', method: 'GET', path: '/fhir/Patient', params: <params> }
  * match r.allowedBy == []
  * match r.status == 403

  Examples:
    | case                                | params                                                                   |
    | with one unconsented id among them  | { _id: '#(id("patient-self") + "," + id("patient-other"))' }             |
    | with only a revoked Consent         | { _id: '#(id("patient-other"))' }                                        |
    | with no _id                         | {}                                                                       |
    | with _revinclude                    | { _id: '#(id("patient-self"))', _revinclude: 'Observation:subject' }     |

Scenario Outline: rec searches Patient with <param>: denied, includes skip policy checks
  * def r = call ap { who: 'rec', method: 'GET', path: '/fhir/Patient', params: { _id: '#(id("patient-self"))', <param>: '<value>' } }
  * match r.allowedBy == []
  * match r.status == 403

  Examples:
    | param       | value                 |
    | _revinclude | Observation:subject   |
    | _include    | Patient:general-practitioner |

Scenario: rec searches Patients: only Patients come back
  * def r = call ap { who: 'rec', method: 'GET', path: '/fhir/Patient', params: { _id: '#(id("patient-self") + "," + id("patient-other"))' } }
  * match r.allowedBy == ['as-receptionist-read-patients']
  * match r.status == 200
  * match each r.response.entry[*].resource.resourceType == 'Patient'
  * match r.response.entry[*].resource.id contains only ['#(id("patient-self"))', '#(id("patient-other"))']
