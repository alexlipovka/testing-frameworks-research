Feature: 11. Invalid resources are rejected with an OperationOutcome (admin)

Background:
  * url baseUrl
  * configure headers = { Authorization: '#(adminAuth)' }

Scenario Outline: <case>
  Given path '/fhir/<type>'
  And request <body>
  When method post
  Then status 422
  And match response.resourceType == 'OperationOutcome'
  And match response.issue == '#[_ > 0]'
  And match each response.issue contains { severity: '#? _ == "error" || _ == "fatal"', code: '#string' }

  Examples:
    | case                         | type        | body                                                                      |
    | unknown element              | Patient     | { resourceType: 'Patient', favouriteColour: 'blue' }                       |
    | wrong type for birthDate     | Patient     | { resourceType: 'Patient', birthDate: 42 }                                |
    | missing required status      | Observation | { resourceType: 'Observation', code: { text: 'x' } }                       |
