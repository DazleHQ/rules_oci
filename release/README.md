# Releasing `rules_oci`

## Setup login to ghcr.io
```
export GITHUB_TOKEN=XXX
export DOCKER_CONFIG=$(pwd)
echo "{\"credHelpers\":{\"ghcr.io\":\"ghcr\"}}" > $DOCKER_CONFIG/config.json
echo -e "#\!/usr/bin/env bash\necho '{\"ServerURL\":\"ghcr.io\",\"Username\":\"Bearer\",\"Secret\":\"XXX\"}'" > docker-credential-ghcr
chmod +x docker-credential-ghcr
export PATH=$(pwd):$PATH
```


## Build the release package tar
bazel build //release:release

## Push the package to registry

```
bazel run //go/cmd/ocitool -- push-blob --ref "ghcr.io/tguidoux/rules_oci/rules:latest" --file $(pwd)/bazel-bin/release/release.tar.gz

bazel run //go/cmd/ocitool -- push-rules --ref "ghcr.io/tguidoux/rules_oci/rules:latest" --file $(pwd)/bazel-bin/release/release.tar.gz
```

## Updating Licenses and Headers

```
go install github.com/DataDog/temporalite/internal/licensecheck@latest
go install github.com/DataDog/temporalite/internal/copyright@latest
licensecheck
copyright
```
