Feature: 7. Policy bypass attempts: transaction Bundle, JSON Patch, merge-patch

Background:
  * def ap = read('classpath:lib/ap.feature')
  * def self = id('patient-self')
  * def other = id('patient-other')

Scenario Outline: <who> wraps <what> in a transaction Bundle: denied
  * def bundle = { resourceType: 'Bundle', type: 'transaction', entry: [<entry>] }
  * def r = call ap { who: '<who>', method: 'POST', path: '/fhir', body: '#(bundle)' }
  * match r.allowedBy == []
  * match r.crashed == []
  * match r.status == 403

  Examples:
    | who      | what                        | entry                                                                                                   |
    | pat-self | a read of another Patient   | { request: { method: 'GET', url: '#("Patient/" + other)' } }                                            |
    | pat-self | a read of their own Patient | { request: { method: 'GET', url: '#("Patient/" + self)' } }                                             |
    | rec      | a Patient update            | { resource: { resourceType: 'Patient', id: '#(self)', active: false }, request: { method: 'PUT', url: '#("Patient/" + self)' } } |
    | p1       | a read of a revoked Patient | { request: { method: 'GET', url: '#("Patient/" + other)' } }                                            |

Scenario Outline: <who> patches a Patient with <kind>: denied
  * def r = call ap { who: '<who>', method: 'PATCH', path: '#("/fhir/Patient/" + self)', body: <body> }
  * match r.allowedBy == []
  * match r.crashed == []
  * match r.status == 403

  Examples:
    | who      | kind        | body                                                       |
    | rec      | JSON Patch  | [{ op: 'replace', path: '/name/0/given/0', value: 'X' }]   |
    | pat-self | JSON Patch  | [{ op: 'add', path: '/active', value: false }]             |
    | rec      | merge-patch | { active: false }                                          |

Scenario: none of the attempts changed the Patient
  * url baseUrl
  * path '/fhir/Patient', self
  * header Authorization = adminAuth
  * method get
  * status 200
  * match response.name[0].given == ['Self']
  * match response.active == '#notpresent'
