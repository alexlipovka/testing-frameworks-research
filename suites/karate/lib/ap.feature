@ignore
Feature: Ask Aidbox for its policy decision, then send the real request

# Args: who (identity name or 'admin'), method, path; optional body, params, auth (overrides who).
# Returns: allowedBy (ids of policies that granted), crashed (policies with an error),
#          status and response of the real request.
Scenario:
  * def params = karate.get('params', {})
  * def body = karate.get('body', null)
  * def auth = karate.get('auth') || (who == 'admin' ? adminAuth : bearer(who))
  * def send =
    """
    function(extra) {
      var q = karate.merge(params, extra);
      var qs = Object.keys(q).map(k => [].concat(q[k]).map(v => k + '=' + encodeURIComponent(v)).join('&')).join('&');
      var r = karate.http(baseUrl + path + (qs ? '?' + qs : '')).header('Authorization', auth);
      // A JSON array body on PATCH is a JSON Patch; an object is a merge-patch
      if (method == 'PATCH') r.contentType(Array.isArray(body) ? 'application/json-patch+json' : 'application/merge-patch+json');
      return body == null ? r.invoke(method) : r.invoke(method, body);
    }
    """
  * def debug = send({ __debug: 'policy' })
  * if (debug.status != 200 || !debug.body.policies) karate.fail('no policy dump for ' + method + ' ' + path + ': ' + debug.status + ' ' + JSON.stringify(debug.body))
  * def allowedBy = karate.filter(debug.body.policies, p => p['eval-result'] === true).map(p => p['policy-id'])
  * def crashed = karate.filter(debug.body.policies, p => !!p.error).map(p => ({ id: p['policy-id'], error: p.error }))
  * def real = send({})
  * def status = real.status
  * def response = real.body
  # Carries identity and request so that a failed match prints the whole decision.
  * def verdict = ({ who: who, request: method + ' ' + path, allowedBy: allowedBy, crashed: crashed, status: status })
