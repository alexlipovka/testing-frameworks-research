Feature: Close the fixture run: delete every row written after the stamp

Scenario: teardown
  * def vars = karate.readAsString('file:.vars.json')
  * def run = JSON.parse(vars)
  * url baseUrl
  * path '/$psql'
  * header Authorization = adminAuth
  * request { query: '#(run.rollback.replace("{{tx_id}}", run.txId))' }
  * method post
  * status 200
  * match response.status == 'success'
  * java.nio.file.Files.delete(java.nio.file.Path.of('.vars.json'))
  * karate.log('run', run.runId, 'torn down')
