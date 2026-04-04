# Jenkins + n8n Operations Guide

This guide documents the operational setup for the Jenkins pipeline in `Jenkinsfile`, including Docker Hub publishing, GitHub release creation, n8n event ingestion, Postgres persistence, and email notifications.

## Architecture

- Jenkins builds and tags the image, then pushes tags to Docker Hub.
- Jenkins generates and updates GitHub Releases with release notes and package manifest artifacts.
- Jenkins posts a build event payload to n8n via `ci/jenkins/scripts/notify_n8n.sh`.
- n8n validates the payload, upserts it into Postgres, and sends an email alert.

## Required Jenkins Credentials

Configure these credentials in Jenkins before running the pipeline:

1. `dockerhub-creds` (Username with password)
   - Used in `Push Docker Hub` stage.
   - Username: Docker Hub account or org robot user.
   - Password: Docker Hub access token.
2. `WEBHOOK_URL` (Secret text or environment injected by your Jenkins config)
   - URL for n8n Webhook Trigger endpoint.
   - Required by `ci/jenkins/scripts/notify_n8n.sh` when `DRY_RUN` is not `true`.
3. `GITHUB_TOKEN` (Secret text, recommended)
   - Required for `gh release` commands in the release stage unless `gh` auth is already preconfigured on the Jenkins agent.
   - Scope must allow creating/editing releases and uploading artifacts.

## n8n Setup

1. Import workflow blueprint:
   - File: `n8n/blueprints/jenkins-build-events-workflow.json`
2. Configure Postgres credential in n8n:
   - Assign it to the `Postgres Upsert` node.
3. Configure email transport in n8n:
   - Assign SMTP credential to the `Send Email` node.
   - Set `N8N_ALERT_EMAIL_TO` if you want a non-default recipient.
4. Activate the workflow after credential binding.
5. Set or expose webhook endpoint to Jenkins as `WEBHOOK_URL`.
   - For the provided blueprint, the endpoint shape is `/webhook/jenkins-build-events`.
   - Minimum payload fields expected by validation are `job_name`, `build_number`, and `status`.

## Postgres Setup

Create schema/table/indexes before enabling pipeline notifications.

```bash
psql "$POSTGRES_DSN" -f n8n/sql/001_ci_pipeline_runs.sql
```

Expected object:

- `ci_pipeline_runs` table with unique key `(job_name, build_number)`.

## Email Notification Behavior

- Triggered after successful DB upsert in n8n.
- Subject format: `[CI] <job_name> #<build_number> <status>`.
- Body includes job name, build number, status, URL, and published tags.

## Smoke Test Checklist

Run this checklist after initial setup or infra changes:

1. Validate local scripts and fixtures:
   - `bash ci/jenkins/tests/run-all.sh`
2. Validate shell scripts:
    - `shellcheck ci/jenkins/scripts/*.sh ci/jenkins/tests/*.sh`
3. Validate Justfile syntax:
    - `just --list`
4. Verify GitHub CLI auth on the Jenkins runtime user:
   - `gh auth status`
5. Trigger a Jenkins build manually.
6. Confirm Docker Hub tags are published (`stable`, date tags).
7. Confirm GitHub Release was created/updated and manifest uploaded.
8. Confirm n8n execution succeeded for webhook request.
9. Confirm Postgres row upserted in `ci_pipeline_runs`.
10. Confirm email alert was received.

## Operations Notes

- For dry runs of webhook payload generation, set `DRY_RUN=true` when invoking `ci/jenkins/scripts/notify_n8n.sh`.
- If release creation fails, verify `gh` auth and repository permissions for the Jenkins runtime user.
- If n8n rejects payloads, inspect required fields in the `Validate Payload` node.
