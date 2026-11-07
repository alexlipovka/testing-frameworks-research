Feature: 15. Rerunnable: no rows from an earlier run survive its teardown

# The other half of case 15 is `./run.sh twice`: two consecutive runs, both green.
Scenario Outline: no <table> row from another run
  Given url baseUrl
  And path '/$psql'
  And header Authorization = adminAuth
  * def query = "SELECT count(*) AS n FROM \"<table>\" WHERE id LIKE 'bakeoff-%' AND id NOT LIKE '" + runId + "-%'"
  And request { query: '#(query)' }
  When method post
  Then status 200
  And match response.status == 'success'
  And match response.result[0].data[0].n == 0

  Examples:
    | table        |
    | patient      |
    | user         |
    | client       |
    | role         |
    | consent      |
    | accesspolicy |
