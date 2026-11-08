# Writes one out/<identity>.hurl per table row. Hurl has no parameterization and a
# predicate can't be switched by a variable, so each cell's asserts are generated.
function cell(op, policy) {
  url = "{{url}}/fhir/" path[op]
  sep = index(path[op], "?") ? "&" : "?"
  print method[op] " " url sep "__debug=policy\nAuthorization: Bearer {{" token "}}" body[op] "\nHTTP 200\n[Asserts]" > file
  if (policy == "-") print "jsonpath \"$.policies[?(@['eval-result'] == true)].id\" not exists" > file
  else print "jsonpath \"$.policies[?(@['eval-result'] == true)].id\" == \"" policy "\"" > file
  print "jsonpath \"$.policies[?(search(@.error, '.'))].error\" not exists\n" > file
  print method[op] " " url "\nAuthorization: Bearer {{" token "}}" body[op] "\nHTTP " (policy == "-" ? 403 : 200) "\n" > file
}
BEGIN {
  n = split("read_patient search_patient update_patient read_encounter", ops, " ")
  self = "{{run_id}}-patient-self"
  method["read_patient"] = "GET"; path["read_patient"] = "Patient/" self
  method["search_patient"] = "GET"; path["search_patient"] = "Patient?_id=" self
  method["update_patient"] = "PUT"; path["update_patient"] = "Patient/" self
  body["update_patient"] = "\n{\"resourceType\": \"Patient\", \"id\": \"" self "\", \"name\": [{\"given\": [\"Self\"], \"family\": \"Bakeoff\"}]}"
  method["read_encounter"] = "GET"; path["read_encounter"] = "Encounter/{{run_id}}-enc-match"
}
/^[^#]/ {
  file = out "/" $1 ".hurl"; token = $2
  for (i = 1; i <= n; i++) cell(ops[i], $(i + 2))
  close(file)
}
