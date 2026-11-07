Feature: 3. A SQL policy that throws shows up as an error, not as a plain deny

Background:
  * def ap = read('classpath:lib/ap.feature')

Scenario: baseline: a patient request evaluates every policy without a crash
  * def r = call ap { who: 'pat-self', method: 'GET', path: '#("/fhir/Patient/" + id("patient-self"))' }
  * match r.allowedBy == ['patient-role-policy']
  * match r.crashed == []
  * match r.status == 200

Scenario: a plain deny has no error either
  * def r = call ap { who: 'pat-self', method: 'GET', path: '#("/fhir/Patient/" + id("patient-other"))' }
  * match r.allowedBy == []
  * match r.crashed == []
  * match r.status == 403

Scenario: a throwing SQL policy is reported with its error, though the status is the same 403
  # Run-scoped user and policy: only this user ever evaluates it, teardown removes both
  * def user = id('crash-user')
  * url baseUrl
  * configure headers = { Authorization: '#(adminAuth)' }
  * path '/User', user
  * request { resourceType: 'User', id: '#(user)', password: 'bakeoff-password' }
  * method put
  * status 201
  * path '/AccessPolicy', id('throws')
  * request { resourceType: 'AccessPolicy', id: '#(id("throws"))', engine: 'sql', sql: { query: 'SELECT 1/0' }, link: [{ resourceType: 'User', id: '#(user)' }] }
  * method put
  * status 201
  * configure headers = null
  * path '/auth/token'
  * request { grant_type: 'password', client_id: '#(id("client"))', client_secret: 'bakeoff-client-secret', username: '#(user)', password: 'bakeoff-password' }
  * method post
  * status 200
  * def r = call ap { who: 'crash-user', auth: '#("Bearer " + response.access_token)', method: 'GET', path: '#("/fhir/Patient/" + id("patient-self"))' }
  * match r.allowedBy == []
  * match r.status == 403
  * match r.crashed == [{ id: '#(id("throws"))', error: '#notnull' }]
  * match karate.toString(r.crashed[0].error) contains 'division by zero'
