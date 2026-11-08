Feature: 5. An identity with no role is denied everywhere

Scenario Outline: norole <method> <path>: denied by every policy
  * def r = call read('classpath:lib/ap.feature') { who: 'norole', method: '<method>', path: '<path>', params: <params>, body: <body> }
  * match r.verdict contains { allowedBy: [], crashed: [], status: 403 }

  Examples:
    | method | path                                          | params                                             | body                                                  |
    | GET    | #("/fhir/Patient/" + id("patient-self"))      | {}                                                 | null                                                  |
    | GET    | /fhir/Patient                                 | {}                                                 | null                                                  |
    | GET    | /fhir/Patient                                 | { _id: '#(id("patient-self"))' }                   | null                                                  |
    | GET    | /fhir/Observation                             | { subject: '#("Patient/" + id("patient-self"))' }  | null                                                  |
    | GET    | #("/fhir/Encounter/" + id("enc-match"))       | {}                                                 | null                                                  |
    | GET    | #("/fhir/Appointment/" + id("appt-match"))    | {}                                                 | null                                                  |
    | POST   | /fhir/Appointment                             | {}                                                 | { resourceType: 'Appointment', status: 'proposed', participant: [{ status: 'needs-action', actor: { reference: 'Practitioner/practitioner1' } }] } |
    | PUT    | #("/fhir/Patient/" + id("patient-self"))      | {}                                                 | { resourceType: 'Patient', id: '#(id("patient-self"))' } |
    | POST   | /fhir/Questionnaire/glucose/$populate         | {}                                                 | { resourceType: 'Parameters', parameter: [{ name: 'subject', valueReference: { reference: '#("Patient/" + id("patient-self"))' } }] } |
