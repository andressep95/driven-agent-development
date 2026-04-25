CREATE TABLE IF NOT EXISTS codebase_index (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    file_path   TEXT NOT NULL,
    symbol_name TEXT,
    symbol_type TEXT,
    line_start  INTEGER,
    line_end    INTEGER,
    intent      TEXT,
    tags        TEXT,
    author      TEXT,
    email       TEXT,
    git_hash    TEXT,
    updated_at  TEXT
);

-- Full-text search over file_path, symbol_name, intent, tags
CREATE VIRTUAL TABLE IF NOT EXISTS code_search USING fts5(
    file_path,
    symbol_name,
    intent,
    tags,
    content='codebase_index',
    content_rowid='id'
);

-- Architectural decisions that don't live in code or git messages
CREATE TABLE IF NOT EXISTS decisions (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    context   TEXT,
    decision  TEXT,
    reason    TEXT,
    tags      TEXT,
    author    TEXT,
    email     TEXT,
    git_hash  TEXT,
    timestamp TEXT
);

-- Search effectiveness log: lets the agent learn which queries return useful results
CREATE TABLE IF NOT EXISTS search_log (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    query       TEXT,
    result_file TEXT,
    result_sym  TEXT,
    was_used    INTEGER DEFAULT 0,  -- 1 = agent actually read this result
    timestamp   TEXT
);
