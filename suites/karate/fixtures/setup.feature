@ignore
Feature: Open a fixture run (shared contract: sut/fixtures/README.md)

Scenario: setup
  * if (java.nio.file.Files.exists(java.nio.file.Path.of('.vars.json'))) karate.fail('a run is open (.vars.json): ./run.sh teardown first')
  * def raw = karate.readAsString('file:../../sut/fixtures/fixtures.json')
  * def runId = 'bakeoff-' + java.util.UUID.randomUUID().toString().substring(0, 8)
  * def fx = JSON.parse(raw.split('{{run_id}}').join(runId))
  * def sql =
    """
    function(q) {
      var r = karate.http(baseUrl + '/$psql').header('Authorization', adminAuth).post({ query: q });
      if (r.status != 200 || r.body.status != 'success') karate.fail('$psql failed: ' + q + ' -> ' + JSON.stringify(r.body));
      return r.body.result[0].data;
    }
    """
  * sql(fx.sql.install)
  * def txId = sql(fx.sql.stamp)[0].last_value
  # Before the first write, so a setup that dies halfway can still be torn down
  * java.nio.file.Files.writeString(java.nio.file.Path.of('.vars.json'), JSON.stringify({ runId: runId, txId: txId, rollback: fx.sql.rollback }))

  * def put =
    """
    function(s) {
      var r = karate.http(baseUrl + s.path).header('Authorization', adminAuth).invoke(s.method, s.body);
      if (r.status >= 300) karate.fail('setup ' + s.method + ' ' + s.path + ' -> ' + r.status + ' ' + JSON.stringify(r.body));
    }
    """
  * karate.forEach(fx.setup, put)

  * def tokens = {}
  * def login =
    """
    function(i) {
      var r = karate.http(baseUrl + '/auth/token').post({ grant_type: 'password', client_id: fx.secrets.client_id,
        client_secret: fx.secrets.client_secret, username: i.user, password: fx.secrets.user_password });
      if (r.status != 200) karate.fail('token ' + i.name + ' -> ' + r.status);
      tokens[i.name] = r.body.access_token;
    }
    """
  * karate.forEach(fx.identities, login)
  * karate.log('run', runId, 'open, tx', txId)
