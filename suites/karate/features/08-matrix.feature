Feature: 8. Identity × operation matrix: every cell asserts the deciding policy

# Each cell names the policy that must grant it; '-' means every policy must deny.
Background:
  * def self = id('patient-self')
  * def ops =
    """
    {
      read:   { method: 'GET',  path: '/fhir/Patient/' + self },
      search: { method: 'GET',  path: '/fhir/Patient', params: { _id: self } },
      update: { method: 'PUT',  path: '/fhir/Patient/' + self,
                body: { resourceType: 'Patient', id: self, name: [{ given: ['Self'], family: 'Bakeoff' }] } },
      book:   { method: 'POST', path: '/fhir/Appointment',
                body: { resourceType: 'Appointment', status: 'proposed', participant: [
                  { status: 'needs-action', actor: { reference: 'Patient/' + self } } ] } }
    }
    """

Scenario Outline: <who>
  * def cells = { read: '<read>', search: '<search>', update: '<update>', book: '<book>' }
  * def check =
    """
    function(op) {
      var r = karate.call('classpath:lib/ap.feature', karate.merge(ops[op], { who: '<who>' }));
      var want = cells[op] == '-' ? [] : [cells[op]];
      var ok = JSON.stringify(r.allowedBy) == JSON.stringify(want) && r.crashed.length == 0
        && (want.length ? r.status < 300 : r.status == 403);
      return ok ? null : op + ': want ' + JSON.stringify(want) + ', got ' + JSON.stringify(r.allowedBy)
        + ' status ' + r.status + (r.crashed.length ? ' crashed ' + JSON.stringify(r.crashed) : '');
    }
    """
  * def wrong = karate.filter(Object.keys(cells).map(check), x => x != null)
  * match wrong == []

  Examples:
    | who      | read                          | search                                    | update | book                     |
    | pat-self | patient-role-policy           | -                                         | -      | -                        |
    | p1       | practitioner-policy           | as-practitioner-search-consented-patients | -      | -                        |
    | p2       | -                             | -                                         | -      | -                        |
    | rec      | as-receptionist-read-patients | as-receptionist-read-patients             | -      | receptionist-role-policy |
    | norole   | -                             | -                                         | -      | -                        |
