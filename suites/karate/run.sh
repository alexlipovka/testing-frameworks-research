#!/bin/sh
# Karate 2.1.4 suite. Pinned: standalone jar (sha256) on eclipse-temurin 21 JRE in Docker.
#
#   ./run.sh [karate args]   setup (callSingle), every feature, teardown (always)
#   ./run.sh teardown        close a run left open (.vars.json)
#   ./run.sh twice           case 15: two consecutive full runs, both green
set -eu
DIR=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$DIR/../.." && pwd)
JAR=.cache/karate-2.1.4.jar
SHA=1f743f4acc56526b39bd88c84bfe4491c46d5e94f4ab5a38c437c9400dbc2488
IMAGE=eclipse-temurin:21.0.8_9-jre

cd "$DIR"
if ! echo "$SHA  $JAR" | sha256sum -c --status 2>/dev/null; then
  mkdir -p .cache
  curl -sfL -o "$JAR" https://github.com/karatelabs/karate/releases/download/v2.1.4/karate-2.1.4.jar
  echo "$SHA  $JAR" | sha256sum -c --status || { echo "karate jar checksum mismatch" >&2; exit 1; }
fi

karate() {
  docker run --rm --network host -u "$(id -u):$(id -g)" -v "$REPO:/repo" -w /repo/suites/karate \
    ${AIDBOX_URL:+-e JAVA_TOOL_OPTIONS=-Daidbox.url=$AIDBOX_URL} \
    "$IMAGE" java -jar "$JAR" run --no-color --backup-reportdir=false "$@"
}
teardown() { [ ! -f .vars.json ] || karate -e teardown -o target/teardown -f '~html' fixtures/teardown.feature >/dev/null; }

case "${1:-}" in
  teardown) teardown; exit ;;
  twice) shift; "$0" "$@" && "$0" "$@"; exit ;;
esac

[ ! -f .vars.json ] || { echo 'a run is open (.vars.json): ./run.sh teardown first' >&2; exit 1; }
trap teardown EXIT
karate -t '~@ignore' -T "${THREADS:-4}" -f html,junit:xml "$@" features
