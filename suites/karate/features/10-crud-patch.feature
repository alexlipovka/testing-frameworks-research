Feature: 10. FHIR CRUD and JSON Patch (admin)

Background:
  * url baseUrl
  * configure headers = { Authorization: '#(adminAuth)' }
  * def pid = id('crud')

Scenario: create, read, update, patch, delete a Patient
  Given path '/fhir/Patient', pid
  And request { resourceType: 'Patient', id: '#(pid)', name: [{ given: ['Crud'], family: 'Bakeoff' }] }
  When method put
  Then status 201
  And match response.meta.versionId == '#string'
  * def v1 = response.meta.versionId

  Given path '/fhir/Patient', pid
  When method get
  Then status 200
  And match response contains { id: '#(pid)', name: [{ given: ['Crud'], family: 'Bakeoff' }] }

  Given path '/fhir/Patient', pid
  And request { resourceType: 'Patient', id: '#(pid)', gender: 'female', name: [{ given: ['Crud'], family: 'Bakeoff' }] }
  When method put
  Then status 200
  And match response.gender == 'female'
  And match response.meta.versionId != v1

  Given path '/fhir/Patient', pid
  And header Content-Type = 'application/json-patch+json'
  And request [{ op: 'replace', path: '/name/0/given/0', value: 'Patched' }, { op: 'add', path: '/birthDate', value: '2000-01-01' }]
  When method patch
  Then status 200
  And match response.name[0].given == ['Patched']
  And match response.birthDate == '2000-01-01'
  And match response.gender == 'female'

  Given path '/fhir/Patient', pid
  When method delete
  Then status 200

  Given path '/fhir/Patient', pid
  When method get
  Then status 410

Scenario: a JSON Patch whose test op fails changes nothing
  Given path '/fhir/Patient', id('patient-unlinked')
  And header Content-Type = 'application/json-patch+json'
  And request [{ op: 'test', path: '/name/0/given/0', value: 'Nope' }, { op: 'replace', path: '/name/0/given/0', value: 'X' }]
  When method patch
  Then assert responseStatus >= 400 && responseStatus < 500
  Given path '/fhir/Patient', id('patient-unlinked')
  When method get
  Then match response.name[0].given == ['Unlinked']
