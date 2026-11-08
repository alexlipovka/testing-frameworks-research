Feature: 4. Receptionist reads Patients, never writes them

Background:
  * def ap = read('classpath:lib/ap.feature')
  * def self = id('patient-self')
  * def patient = { resourceType: 'Patient', id: '#(self)', name: [{ given: ['Changed'], family: 'Bakeoff' }] }

Scenario: rec reads a Patient by id
  * def r = call ap { who: 'rec', method: 'GET', path: '#("/fhir/Patient/" + self)' }
  * match r.verdict contains { allowedBy: ['as-receptionist-read-patients'], crashed: [], status: 200 }

Scenario: rec searches Patients
  * def r = call ap { who: 'rec', method: 'GET', path: '/fhir/Patient', params: { _id: '#(self)' } }
  * match r.verdict contains { allowedBy: ['as-receptionist-read-patients'], crashed: [], status: 200 }
  * match r.response.entry[*].resource.id == ['#(self)']

Scenario: rec reads an Appointment (receptionist-role-policy)
  * def r = call ap { who: 'rec', method: 'GET', path: '#("/fhir/Appointment/" + id("appt-match"))' }
  * match r.verdict contains { allowedBy: ['receptionist-role-policy'], crashed: [], status: 200 }

Scenario Outline: rec <method> on Patient is denied
  * def r = call ap { who: 'rec', method: '<method>', path: '<path>', body: <body> }
  * match r.verdict contains { allowedBy: [], crashed: [], status: 403 }

  Examples:
    | method | path                            | body                                                      |
    | PUT    | #("/fhir/Patient/" + self)      | '#(patient)'                                              |
    | POST   | /fhir/Patient                   | { resourceType: 'Patient', name: [{ family: 'Bakeoff' }] } |
    | PATCH  | #("/fhir/Patient/" + self)      | [{ op: 'replace', path: '/name/0/given/0', value: 'X' }]   |

Scenario: the denied writes left the Patient as it was
  * url baseUrl
  * path '/fhir/Patient', self
  * header Authorization = adminAuth
  * method get
  * status 200
  * match response.name[0].given == ['Self']
