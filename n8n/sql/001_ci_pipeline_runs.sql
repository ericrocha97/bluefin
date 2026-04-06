CREATE TABLE IF NOT EXISTS ci_pipeline_runs (
    id BIGSERIAL PRIMARY KEY,
    job_name TEXT NOT NULL,
    build_number BIGINT NOT NULL,
    status TEXT NOT NULL,
    build_url TEXT,
    git_sha TEXT,
    image_name TEXT,
    release_tag TEXT,
    started_at TIMESTAMPTZ,
    finished_at TIMESTAMPTZ,
    duration_ms BIGINT,
    published_tags jsonb NOT NULL DEFAULT '[]'::jsonb,
    payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (job_name, build_number)
);

CREATE INDEX IF NOT EXISTS idx_ci_pipeline_runs_created_at
    ON ci_pipeline_runs (created_at);

CREATE INDEX IF NOT EXISTS idx_ci_pipeline_runs_status
    ON ci_pipeline_runs (status);
