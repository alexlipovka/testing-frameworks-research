function fn() {
  var baseUrl = karate.properties['aidbox.url'] || 'http://localhost:8280';
  var adminAuth = 'Basic ' + Java.type('java.util.Base64').getEncoder()
    .encodeToString(new java.lang.String('root:secret').getBytes());
  if (karate.env == 'teardown') return { baseUrl: baseUrl, adminAuth: adminAuth };
  // Once per JVM: every scenario, on any thread, shares one run
  var run = karate.callSingle('classpath:fixtures/setup.feature', { baseUrl: baseUrl, adminAuth: adminAuth });
  karate.configure('url', baseUrl);
  return {
    baseUrl: baseUrl,
    adminAuth: adminAuth,
    runId: run.runId,
    tokens: run.tokens,
    id: function (name) { return run.runId + '-' + name; },
    bearer: function (who) { return 'Bearer ' + run.tokens[who]; }
  };
}
