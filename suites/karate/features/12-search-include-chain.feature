Feature: 12. Search: _include, _revinclude, chaining (admin)

Background:
  * url baseUrl
  * configure headers = { Authorization: '#(adminAuth)' }
  * def resources = function(type) { return karate.filter(response.entry, e => e.resource.resourceType == type).map(e => e.resource.id) }

Scenario: _include pulls the Encounter's subject into the Bundle
  Given path '/fhir/Encounter'
  And params { _id: '#(id("enc-match"))', _include: 'Encounter:subject' }
  When method get
  Then status 200
  And match resources('Encounter') == ['#(id("enc-match"))']
  And match resources('Patient') == ['#(id("patient-self"))']
  And match response.entry[?(@.resource.resourceType == 'Patient')].search.mode == ['include']

Scenario: _revinclude pulls the Patient's Observations, and only theirs
  Given path '/fhir/Patient'
  And params { _id: '#(id("patient-self"))', _revinclude: 'Observation:subject' }
  When method get
  Then status 200
  And match resources('Patient') == ['#(id("patient-self"))']
  And match resources('Observation') == ['#(id("obs-match"))']

Scenario: chained search on subject:Patient._id
  Given path '/fhir/Observation'
  And param subject:Patient._id = id('patient-other')
  When method get
  Then status 200
  And match resources('Observation') == ['#(id("obs-mismatch"))']

Scenario: chained search on a Patient name
  Given path '/fhir/Encounter'
  And params { 'subject:Patient.name': 'Other', _id: '#(id("enc-match") + "," + id("enc-mismatch"))' }
  When method get
  Then status 200
  And match resources('Encounter') == ['#(id("enc-mismatch"))']
