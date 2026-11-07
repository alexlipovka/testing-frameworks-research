Feature: 14. run_id isolation: this run sees and acts as only its own fixtures

Background:
  * url baseUrl
  * def ap = read('classpath:lib/ap.feature')

Scenario Outline: the <who> token belongs to this run's user
  * def r = call ap { who: '<who>', method: 'GET', path: '#("/fhir/Patient/" + id("patient-self"))' }
  * match r.debug.body.request.user.id == id('<who>')
  * match r.debug.body.request.client.id == id('client')

  Examples:
    | who      |
    | pat-self |
    | p1       |
    | p2       |
    | rec      |
    | norole   |

Scenario: every Bakeoff Patient on the server is this run's
  Given path '/fhir/Patient'
  And header Authorization = adminAuth
  And params { family: 'Bakeoff', _count: 1000 }
  When method get
  Then status 200
  And match each response.entry[*].resource.id == '#regex ' + runId + '-.+'
  And match response.entry[*].resource.id contains ['#(id("patient-self"))', '#(id("patient-other"))', '#(id("patient-unlinked"))']

Scenario: the run_id is fresh and well formed
  * match runId == '#regex bakeoff-[0-9a-f]{8}'
