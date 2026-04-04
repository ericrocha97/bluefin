pipeline {
    agent any

    options {
        disableConcurrentBuilds(abortPrevious: true)
        timestamps()
    }

    triggers {
        cron('H 10 * * *')
    }

    environment {
        IMAGE_NAME = 'ericrocha/bluefin-cosmic-dx'
        DOCKERHUB_REPO = 'ericrocha/bluefin-cosmic-dx'
        VERSION_DATE = ''
        SHORT_DATE = ''
        RELEASE_TAG = ''
        BUILD_DATE = ''
        BUILD_STARTED_AT = ''
        MANIFEST_FILE = 'ci/jenkins/build/manifest.txt'
        OUTPUT_FILE = 'ci/jenkins/build/versions.env'
        TAGS_FILE = 'ci/jenkins/build/tags.txt'
        LABELS_FILE = 'ci/jenkins/build/labels.txt'
        RELEASE_BODY_FILE = 'ci/jenkins/build/release-body.md'
    }

    stages {
        stage('Build Image') {
            steps {
                sh '''#!/usr/bin/env bash
set -euo pipefail

mkdir -p ci/jenkins/build

started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
build_date="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
short_date="$(date -u +%Y%m%d)"

echo "${started_at}" > ci/jenkins/build/started_at
echo "${build_date}" > ci/jenkins/build/build_date
echo "${short_date}" > ci/jenkins/build/short_date
echo "v${short_date}" > ci/jenkins/build/release_tag

export IMAGE_NAME="$IMAGE_NAME"
export BUILD_DATE="$build_date"
export VERSION_DATE="$short_date"
export TAGS_FILE="$TAGS_FILE"
export LABELS_FILE="$LABELS_FILE"
bash ci/jenkins/scripts/generate_metadata.sh

docker build -t "$IMAGE_NAME:${short_date}" .

docker run --rm "$IMAGE_NAME:${short_date}" sh -c "rpm -qa --queryformat '%{NAME}\t%{VERSION}-%{RELEASE}\n' | sort" > "$MANIFEST_FILE"
docker run --rm "$IMAGE_NAME:${short_date}" sh -c "awk -F= '\$1==\"VERSION_ID\" {gsub(/\"/,\"\",\$2); print \$2}' /usr/lib/os-release" > ci/jenkins/build/bluefin_version

rm -f ci/jenkins/build/previous-manifest.txt
RELEASE_TAG="$(<ci/jenkins/build/release_tag)"
previous_release_tag="$(gh release list --limit 100 --json tagName --jq '.[] | .tagName' 2>/dev/null | awk -v current="$RELEASE_TAG" '$0 != current { print; exit }' || true)"
if [[ -n "$previous_release_tag" ]]; then
  previous_manifest_dir="ci/jenkins/build/previous-manifest"
  mkdir -p "$previous_manifest_dir"
  if gh release download "$previous_release_tag" --pattern "$(basename "$MANIFEST_FILE")" --dir "$previous_manifest_dir" --clobber >/dev/null 2>&1; then
    downloaded_manifest="$previous_manifest_dir/$(basename "$MANIFEST_FILE")"
    if [[ -f "$downloaded_manifest" ]]; then
      cp "$downloaded_manifest" ci/jenkins/build/previous-manifest.txt
    fi
  fi
fi

export CURRENT_MANIFEST="$MANIFEST_FILE"
if [[ -f ci/jenkins/build/previous-manifest.txt ]]; then
  export PREVIOUS_MANIFEST="ci/jenkins/build/previous-manifest.txt"
fi
export OUTPUT_FILE="$OUTPUT_FILE"
bash ci/jenkins/scripts/extract_versions.sh
'''
                script {
                    env.BUILD_STARTED_AT = readFile('ci/jenkins/build/started_at').trim()
                    env.BUILD_DATE = readFile('ci/jenkins/build/build_date').trim()
                    env.SHORT_DATE = readFile('ci/jenkins/build/short_date').trim()
                    env.RELEASE_TAG = readFile('ci/jenkins/build/release_tag').trim()
                }
            }
        }

        stage('Push Docker Hub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKERHUB_USERNAME', passwordVariable: 'DOCKERHUB_TOKEN')]) {
                    sh '''#!/usr/bin/env bash
set -euo pipefail

printf '%s' "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin

mapfile -t tags < "$TAGS_FILE"
for tag in "${tags[@]}"; do
  [[ -n "$tag" ]] || continue
  docker tag "$IMAGE_NAME:${SHORT_DATE}" "$DOCKERHUB_REPO:${tag}"
  docker push "$DOCKERHUB_REPO:${tag}"
done

docker logout
'''
                }
            }
        }

        stage('Create GitHub Release') {
            steps {
                sh '''#!/usr/bin/env bash
set -euo pipefail

bluefin_version="unknown"
if [[ -f ci/jenkins/build/bluefin_version ]]; then
  bluefin_version="$(<ci/jenkins/build/bluefin_version)"
fi

kernel_version="$(awk -F= '$1=="kernel_version" {print $2}' "$OUTPUT_FILE")"
vscode_version="$(awk -F= '$1=="vscode_version" {print $2}' "$OUTPUT_FILE")"
warp_version="$(awk -F= '$1=="warp_version" {print $2}' "$OUTPUT_FILE")"
vicinae_version="$(awk -F= '$1=="vicinae_version" {print $2}' "$OUTPUT_FILE")"
cosmic_session_version="$(awk -F= '$1=="cosmic_session_version" {print $2}' "$OUTPUT_FILE")"
changelog="$(awk '/^changelog<<EOF$/{flag=1;next}/^EOF$/{flag=0}flag' "$OUTPUT_FILE")"

export RELEASE_TAG="$RELEASE_TAG"
export IMAGE_REGISTRY="docker.io"
export IMAGE_NAME="$IMAGE_NAME"
export SHORT_DATE="$SHORT_DATE"
export BLUEFIN_VERSION="$bluefin_version"
export KERNEL_VERSION="${kernel_version:-unknown}"
export VSCODE_VERSION="${vscode_version:-unknown}"
export WARP_VERSION="${warp_version:-unknown}"
export VICINAE_VERSION="${vicinae_version:-unknown}"
export COSMIC_SESSION_VERSION="${cosmic_session_version:-unknown}"
export CHANGELOG="${changelog:-- No tracked package version changes detected.}"
export DOCKERHUB_REPO="$DOCKERHUB_REPO"
export RELEASE_BODY_FILE="$RELEASE_BODY_FILE"
export MANIFEST_FILE="$MANIFEST_FILE"
bash ci/jenkins/scripts/create_github_release.sh --render-only

if gh release view "$RELEASE_TAG" >/dev/null 2>&1; then
  gh release edit "$RELEASE_TAG" --title "$RELEASE_TAG" --notes-file "$RELEASE_BODY_FILE"
else
  gh release create "$RELEASE_TAG" --title "$RELEASE_TAG" --notes-file "$RELEASE_BODY_FILE"
fi

gh release upload "$RELEASE_TAG" "$MANIFEST_FILE" --clobber
'''
            }
        }
    }

    post {
        success {
            sh '''#!/usr/bin/env bash
set -euo pipefail

published_tags="$(paste -sd, "$TAGS_FILE")"
finished_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
started_epoch="$(date -u -d "$BUILD_STARTED_AT" +%s 2>/dev/null || printf '0')"
finished_epoch="$(date -u -d "$finished_at" +%s 2>/dev/null || printf '0')"
duration_ms="$(( (finished_epoch - started_epoch) * 1000 ))"
if (( duration_ms < 0 )); then duration_ms=0; fi

export STATUS="success"
export JOB_NAME="$JOB_NAME"
export BUILD_NUMBER="$BUILD_NUMBER"
export BUILD_URL="$BUILD_URL"
export GIT_SHA="$GIT_COMMIT"
export IMAGE_NAME="$DOCKERHUB_REPO"
export PUBLISHED_TAGS="${published_tags:-$SHORT_DATE}"
export TIMESTAMP_UTC="$finished_at"
export ERROR_SUMMARY=""
export STARTED_AT="$BUILD_STARTED_AT"
export FINISHED_AT="$finished_at"
export DURATION_MS="$duration_ms"
export RELEASE_TAG="$RELEASE_TAG"
if ! bash ci/jenkins/scripts/notify_n8n.sh; then
  echo "WARN: notify_n8n.sh failed in post-success hook (best-effort notification)." >&2
fi
'''
        }
        failure {
            sh '''#!/usr/bin/env bash
set -euo pipefail

finished_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
started_at="${BUILD_STARTED_AT:-$finished_at}"
started_epoch="$(date -u -d "$started_at" +%s 2>/dev/null || printf '0')"
finished_epoch="$(date -u -d "$finished_at" +%s 2>/dev/null || printf '0')"
duration_ms="$(( (finished_epoch - started_epoch) * 1000 ))"
if (( duration_ms < 0 )); then duration_ms=0; fi

export STATUS="failure"
export JOB_NAME="$JOB_NAME"
export BUILD_NUMBER="$BUILD_NUMBER"
export BUILD_URL="$BUILD_URL"
export GIT_SHA="${GIT_COMMIT:-unknown}"
export IMAGE_NAME="$DOCKERHUB_REPO"
export PUBLISHED_TAGS=""
export TIMESTAMP_UTC="$finished_at"
export ERROR_SUMMARY="Pipeline failed before completion."
export STARTED_AT="$started_at"
export FINISHED_AT="$finished_at"
export DURATION_MS="$duration_ms"
export RELEASE_TAG="${RELEASE_TAG:-unknown}"
if ! bash ci/jenkins/scripts/notify_n8n.sh; then
  echo "WARN: notify_n8n.sh failed in post-failure hook (best-effort notification)." >&2
fi
'''
        }
        always {
            archiveArtifacts artifacts: 'ci/jenkins/build/*', allowEmptyArchive: true
        }
    }
}
