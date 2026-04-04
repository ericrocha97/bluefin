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

if [[ -f /usr/share/bluefin-cosmic-dx/manifest.txt ]]; then
  cp /usr/share/bluefin-cosmic-dx/manifest.txt "$MANIFEST_FILE"
else
  : > "$MANIFEST_FILE"
fi

export CURRENT_MANIFEST="$MANIFEST_FILE"
if [[ -f ci/jenkins/build/previous-manifest.txt ]]; then
  export PREVIOUS_MANIFEST="ci/jenkins/build/previous-manifest.txt"
fi
export OUTPUT_FILE="$OUTPUT_FILE"
bash ci/jenkins/scripts/extract_versions.sh

docker build -t "$IMAGE_NAME:${short_date}" .
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
                sh '''#!/usr/bin/env bash
set -euo pipefail

mapfile -t tags < "$TAGS_FILE"
for tag in "${tags[@]}"; do
  [[ -n "$tag" ]] || continue
  docker tag "$IMAGE_NAME:${SHORT_DATE}" "$DOCKERHUB_REPO:${tag}"
  docker push "$DOCKERHUB_REPO:${tag}"
done
'''
            }
        }

        stage('Create GitHub Release') {
            steps {
                sh '''#!/usr/bin/env bash
set -euo pipefail

bluefin_version="unknown"
if [[ -f /usr/lib/os-release ]]; then
  bluefin_version="$(awk -F= '$1==\"VERSION_ID\" {gsub(/\"/,\"\",$2); print $2}' /usr/lib/os-release)"
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
bash ci/jenkins/scripts/create_github_release.sh
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
bash ci/jenkins/scripts/notify_n8n.sh
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
bash ci/jenkins/scripts/notify_n8n.sh
'''
        }
        always {
            archiveArtifacts artifacts: 'ci/jenkins/build/*', allowEmptyArchive: true
        }
    }
}
