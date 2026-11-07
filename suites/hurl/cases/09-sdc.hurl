# 9. SDC $populate / $extract per role: consented practitioner only, forged answer, QR subject ownership.

# $populate: p1 for patient-self (active Consent) is allowed.
POST {{url}}/fhir/Questionnaire/glucose/$populate
Authorization: Bearer {{p1_token}}
{"resourceType": "Parameters", "parameter": [
  {"name": "subject", "valueReference": {"reference": "Patient/{{run_id}}-patient-self"}},
  {"name": "context", "part": [{"name": "name", "valueString": "Patient"},
                               {"name": "content", "resource": {"resourceType": "Patient", "id": "{{run_id}}-patient-self"}}]},
  {"name": "context", "part": [{"name": "name", "valueString": "Author"},
                               {"name": "content", "resource": {"resourceType": "Practitioner", "id": "practitioner1"}}]}]}
HTTP 200
[Asserts]
jsonpath "$.parameter[?(@.name == 'response')].resource.resourceType" == "QuestionnaireResponse"

POST {{url}}/fhir/Questionnaire/glucose/$populate?__debug=policy
Authorization: Bearer {{p1_token}}
{"resourceType": "Parameters", "parameter": [
  {"name": "subject", "valueReference": {"reference": "Patient/{{run_id}}-patient-self"}}]}
HTTP 200
[Asserts]
jsonpath "$.policies[?(@['eval-result'] == true)].id" == "as-practitioner-sdc-consented-patient"

# Same call for patient-other: revoked Consent.
POST {{url}}/fhir/Questionnaire/glucose/$populate
Authorization: Bearer {{p1_token}}
{"resourceType": "Parameters", "parameter": [
  {"name": "subject", "valueReference": {"reference": "Patient/{{run_id}}-patient-other"}}]}
HTTP 403

POST {{url}}/fhir/Questionnaire/glucose/$populate?__debug=policy
Authorization: Bearer {{p1_token}}
{"resourceType": "Parameters", "parameter": [
  {"name": "subject", "valueReference": {"reference": "Patient/{{run_id}}-patient-other"}}]}
HTTP 200
[Asserts]
jsonpath "$.policies[?(@['eval-result'] == true)]" not exists

POST {{url}}/fhir/Questionnaire/glucose/$populate
Authorization: Bearer {{pat_self_token}}
{"resourceType": "Parameters", "parameter": [
  {"name": "subject", "valueReference": {"reference": "Patient/{{run_id}}-patient-self"}}]}
HTTP 403

POST {{url}}/fhir/Questionnaire/glucose/$populate
Authorization: Bearer {{rec_token}}
{"resourceType": "Parameters", "parameter": [
  {"name": "subject", "valueReference": {"reference": "Patient/{{run_id}}-patient-self"}}]}
HTTP 403

# $extract: honest QR for patient-self passes the policy.
POST {{url}}/fhir/Questionnaire/glucose/$extract
Authorization: Bearer {{p1_token}}
{"resourceType": "Parameters", "parameter": [{"name": "questionnaire_response", "resource": {
  "resourceType": "QuestionnaireResponse", "questionnaire": "glucose", "status": "completed",
  "subject": {"reference": "Patient/{{run_id}}-patient-self"},
  "item": [{"linkId": "patientId", "answer": [{"valueString": "{{run_id}}-patient-self"}]},
           {"linkId": "glucose-level", "answer": [{"valueDecimal": 5.5}]},
           {"linkId": "dateTime", "answer": [{"valueDateTime": "2030-01-01T09:00:00Z"}]}]}}]}
HTTP *
[Asserts]
# shortcut: asserts the policy let it through, not the mapping's output; a real extract needs
# fhir-emr's full launch context (Patient, Author, ProvenanceBundle, ...). Upgrade if case 9 must cover the write.
status != 403

POST {{url}}/fhir/Questionnaire/glucose/$extract?__debug=policy
Authorization: Bearer {{p1_token}}
{"resourceType": "Parameters", "parameter": [{"name": "questionnaire_response", "resource": {
  "resourceType": "QuestionnaireResponse", "questionnaire": "glucose", "status": "completed",
  "subject": {"reference": "Patient/{{run_id}}-patient-self"},
  "item": [{"linkId": "patientId", "answer": [{"valueString": "{{run_id}}-patient-self"}]}]}}]}
HTTP 200
[Asserts]
jsonpath "$.policies[?(@['eval-result'] == true)].id" == "as-practitioner-sdc-consented-patient"

# Forged hidden answer: subject is consented, patientId points elsewhere.
POST {{url}}/fhir/Questionnaire/glucose/$extract
Authorization: Bearer {{p1_token}}
{"resourceType": "Parameters", "parameter": [{"name": "questionnaire_response", "resource": {
  "resourceType": "QuestionnaireResponse", "questionnaire": "glucose", "status": "completed",
  "subject": {"reference": "Patient/{{run_id}}-patient-self"},
  "item": [{"linkId": "patientId", "answer": [{"valueString": "{{run_id}}-patient-other"}]},
           {"linkId": "glucose-level", "answer": [{"valueDecimal": 5.5}]}]}}]}
HTTP 403

POST {{url}}/fhir/Questionnaire/glucose/$extract?__debug=policy
Authorization: Bearer {{p1_token}}
{"resourceType": "Parameters", "parameter": [{"name": "questionnaire_response", "resource": {
  "resourceType": "QuestionnaireResponse", "questionnaire": "glucose", "status": "completed",
  "subject": {"reference": "Patient/{{run_id}}-patient-self"},
  "item": [{"linkId": "patientId", "answer": [{"valueString": "{{run_id}}-patient-other"}]}]}}]}
HTTP 200
[Asserts]
jsonpath "$.policies[?(@['eval-result'] == true)]" not exists

# QR subject p1 has no active Consent for.
POST {{url}}/fhir/Questionnaire/glucose/$extract
Authorization: Bearer {{p1_token}}
{"resourceType": "Parameters", "parameter": [{"name": "questionnaire_response", "resource": {
  "resourceType": "QuestionnaireResponse", "questionnaire": "glucose", "status": "completed",
  "subject": {"reference": "Patient/{{run_id}}-patient-other"},
  "item": [{"linkId": "patientId", "answer": [{"valueString": "{{run_id}}-patient-other"}]}]}}]}
HTTP 403

# Same QR from p2, who does hold that Consent: ownership follows the practitioner.
POST {{url}}/fhir/Questionnaire/glucose/$extract?__debug=policy
Authorization: Bearer {{p2_token}}
{"resourceType": "Parameters", "parameter": [{"name": "questionnaire_response", "resource": {
  "resourceType": "QuestionnaireResponse", "questionnaire": "glucose", "status": "completed",
  "subject": {"reference": "Patient/{{run_id}}-patient-other"},
  "item": [{"linkId": "patientId", "answer": [{"valueString": "{{run_id}}-patient-other"}]}]}}]}
HTTP 200
[Asserts]
jsonpath "$.policies[?(@['eval-result'] == true)].id" == "as-practitioner-sdc-consented-patient"

POST {{url}}/fhir/Questionnaire/glucose/$extract
Authorization: Bearer {{rec_token}}
{"resourceType": "Parameters", "parameter": [{"name": "questionnaire_response", "resource": {
  "resourceType": "QuestionnaireResponse", "questionnaire": "glucose", "status": "completed",
  "subject": {"reference": "Patient/{{run_id}}-patient-self"},
  "item": [{"linkId": "patientId", "answer": [{"valueString": "{{run_id}}-patient-self"}]}]}}]}
HTTP 403
