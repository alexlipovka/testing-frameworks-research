Feature: 9. SDC $populate / $extract under each role

# Allowed calls assert the policy gate only: without fhir-emr's launch context the mapping output means nothing.
Background:
  * def ap = read('classpath:lib/ap.feature')
  * def gate = 'as-practitioner-sdc-consented-patient'
  * def populate =
    """
    function(patient) {
      return { resourceType: 'Parameters', parameter: [
        { name: 'subject', valueReference: { reference: 'Patient/' + id(patient) } } ] };
    }
    """
  * def extract =
    """
    function(subject, answer) {
      return { resourceType: 'Parameters', parameter: [{ name: 'questionnaire_response', resource: {
        resourceType: 'QuestionnaireResponse', questionnaire: 'glucose', status: 'completed',
        subject: { reference: 'Patient/' + id(subject) },
        item: [{ linkId: 'patientId', answer: [{ valueString: id(answer) }] }] } }] };
    }
    """

Scenario Outline: <who> $populate for <patient>: <verdict>
  * def r = call ap { who: '<who>', method: 'POST', path: '/fhir/Questionnaire/glucose/$populate', body: '#(populate("<patient>"))' }
  * match r.allowedBy == <allowedBy>
  * match r.crashed == []
  * match r.status <op> 403

  Examples:
    | who      | patient       | verdict                | allowedBy | op |
    | p1       | patient-self  | consented, allowed     | ['#(gate)'] | != |
    | p2       | patient-other | consented, allowed     | ['#(gate)'] | != |
    | p1       | patient-other | revoked, denied        | []        | == |
    | p2       | patient-self  | no Consent, denied     | []        | == |
    | pat-self | patient-self  | not a practitioner     | []        | == |
    | rec      | patient-self  | not a practitioner     | []        | == |
    | norole   | patient-self  | no role                | []        | == |

Scenario Outline: <who> $extract, QR subject <subject>, patientId <answer>: <verdict>
  * def r = call ap { who: '<who>', method: 'POST', path: '/fhir/Questionnaire/glucose/$extract', body: '#(extract("<subject>", "<answer>"))' }
  * match r.allowedBy == <allowedBy>
  * match r.crashed == []
  * match r.status <op> 403

  Examples:
    | who      | subject       | answer        | verdict                                   | allowedBy | op |
    | p1       | patient-self  | patient-self  | consented, allowed                        | ['#(gate)'] | != |
    | p1       | patient-self  | patient-other | forged answer, denied                     | []        | == |
    | p1       | patient-other | patient-other | QR for a revoked Patient, denied          | []        | == |
    | p2       | patient-self  | patient-self  | QR for someone else's Patient, denied     | []        | == |
    | p2       | patient-other | patient-self  | forged answer to a consented QR, denied   | []        | == |
    | pat-self | patient-self  | patient-self  | patient writes own QR, denied             | []        | == |
    | rec      | patient-self  | patient-self  | not a practitioner                        | []        | == |
    | norole   | patient-self  | patient-self  | no role                                   | []        | == |
