Feature: 13. Transaction Bundle semantics (admin)

Background:
  * url baseUrl
  * configure headers = { Authorization: '#(adminAuth)' }
  * def tx = function(entries) { return { resourceType: 'Bundle', type: 'transaction', entry: entries } }
  * def patientId = id('tx-patient')

Scenario: urn:uuid references are resolved and every entry commits
  * def bundle =
    """
    tx([
      { fullUrl: 'urn:uuid:5f1b7e5a-0000-4000-8000-000000000001',
        resource: { resourceType: 'Patient', name: [{ family: 'BakeoffTx', given: ['Tx'] }] },
        request: { method: 'POST', url: 'Patient' } },
      { resource: { resourceType: 'Observation', status: 'final', code: { text: 'tx' },
                    subject: { reference: 'urn:uuid:5f1b7e5a-0000-4000-8000-000000000001' } },
        request: { method: 'POST', url: 'Observation' } }
    ])
    """
  Given path '/fhir'
  And request bundle
  When method post
  Then status 200
  And match response.type == 'transaction-response'
  And match response.entry[*].response.status == ['#regex 201.*', '#regex 201.*']
  # location is [base/]Type/id/_history/vid
  * def ref = function(loc) { return loc.match(/(Patient|Observation)\/[^\/]+/)[0] }
  * def newPatient = ref(response.entry[0].response.location)
  Given path '/fhir/' + ref(response.entry[1].response.location)
  When method get
  Then status 200
  And match response.subject.reference == newPatient

Scenario: one failing entry rolls back the whole transaction
  * def bundle =
    """
    tx([
      { resource: { resourceType: 'Patient', id: patientId, name: [{ family: 'Bakeoff' }] },
        request: { method: 'PUT', url: 'Patient/' + patientId } },
      { resource: { resourceType: 'Patient', birthDate: 42 },
        request: { method: 'POST', url: 'Patient' } }
    ])
    """
  Given path '/fhir'
  And request bundle
  When method post
  Then assert responseStatus >= 400
  And match response.resourceType == 'OperationOutcome'
  Given path '/fhir/Patient', patientId
  When method get
  Then status 404

Scenario: a conditional create inside a transaction does not duplicate
  * def entry = { resource: { resourceType: 'Patient', identifier: [{ system: 'urn:bakeoff', value: '#(patientId)' }] }, request: { method: 'POST', url: 'Patient', ifNoneExist: '#("identifier=urn:bakeoff|" + patientId)' } }
  Given path '/fhir'
  And request tx([entry])
  When method post
  Then status 200
  Given path '/fhir'
  And request tx([entry])
  When method post
  Then status 200
  And match response.entry[0].response.status == '#regex 200.*'
  Given path '/fhir/Patient'
  And param identifier = 'urn:bakeoff|' + patientId
  When method get
  Then match response.total == 1
