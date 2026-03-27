---
name: postgres
description: >
  Query and manage a PostgreSQL database. Use this skill when asked to run
  queries, inspect schemas or tables, insert/update/delete data, or debug
  database issues. Connection details are read from PG_* environment variables.
---

# PostgreSQL

Interact with a PostgreSQL database using `psql`. This skill mirrors the
capabilities of the `mcp-postgres-server` MCP tool: connecting to a database,
listing schemas and tables, describing table structure, running SELECT queries,
and executing INSERT/UPDATE/DELETE statements.

## Connection

Connection details come from environment variables. Set these in your shell
before starting a session (e.g. in `~/.zshenv` or a project `.env`):

| Variable      | Default     | Description       |
|---------------|-------------|-------------------|
| `PG_HOST`     | `localhost` | Database host     |
| `PG_PORT`     | `5432`      | Database port     |
| `PG_USER`     | *(required)*| Database user     |
| `PG_PASSWORD` | *(required)*| Database password |
| `PG_DATABASE` | *(required)*| Database name     |

Build a reusable connection string for use in commands below:

```bash
PSQL="PGPASSWORD=\"$PG_PASSWORD\" psql -h \"${PG_HOST:-localhost}\" -p \"${PG_PORT:-5432}\" -U \"$PG_USER\" -d \"$PG_DATABASE\""
```

Or use a one-off connection:

```bash
PGPASSWORD="$PG_PASSWORD" psql -h "${PG_HOST:-localhost}" -p "${PG_PORT:-5432}" -U "$PG_USER" -d "$PG_DATABASE" -c "<SQL>"
```

## Capabilities

### connect_db — verify / establish connection

```bash
PGPASSWORD="$PG_PASSWORD" psql -h "$PG_HOST" -p "${PG_PORT:-5432}" -U "$PG_USER" -d "$PG_DATABASE" -c "\conninfo"
```

If different credentials are needed, override the env vars inline:
```bash
PGPASSWORD="<pw>" psql -h "<host>" -p <port> -U "<user>" -d "<db>" -c "\conninfo"
```

### list_schemas — list all schemas

```bash
PGPASSWORD="$PG_PASSWORD" psql -h "${PG_HOST:-localhost}" -p "${PG_PORT:-5432}" -U "$PG_USER" -d "$PG_DATABASE" \
  -c "SELECT schema_name FROM information_schema.schemata ORDER BY schema_name;"
```

### list_tables — list tables in a schema (default: public)

```bash
PGPASSWORD="$PG_PASSWORD" psql -h "${PG_HOST:-localhost}" -p "${PG_PORT:-5432}" -U "$PG_USER" -d "$PG_DATABASE" \
  -c "\dt <schema>.*"
# or for the default public schema:
  -c "\dt"
```

### describe_table — get table structure

```bash
PGPASSWORD="$PG_PASSWORD" psql -h "${PG_HOST:-localhost}" -p "${PG_PORT:-5432}" -U "$PG_USER" -d "$PG_DATABASE" \
  -c "\d <schema>.<table>"
# or for the public schema:
  -c "\d <table>"
```

### query — execute a SELECT query

```bash
PGPASSWORD="$PG_PASSWORD" psql -h "${PG_HOST:-localhost}" -p "${PG_PORT:-5432}" -U "$PG_USER" -d "$PG_DATABASE" \
  -c "SELECT ... FROM ... WHERE ... LIMIT 100;"
```

For large result sets always add a `LIMIT`. Use `\x auto` for expanded output:

```bash
PGPASSWORD="$PG_PASSWORD" psql -h "${PG_HOST:-localhost}" -p "${PG_PORT:-5432}" -U "$PG_USER" -d "$PG_DATABASE" \
  -c "\x auto" -c "SELECT ...;"
```

### execute — INSERT, UPDATE, or DELETE

Wrap mutations in a transaction so you can inspect before committing:

```bash
PGPASSWORD="$PG_PASSWORD" psql -h "${PG_HOST:-localhost}" -p "${PG_PORT:-5432}" -U "$PG_USER" -d "$PG_DATABASE" <<'SQL'
BEGIN;
INSERT INTO ...;
-- or UPDATE / DELETE
SELECT * FROM ... LIMIT 10; -- verify result
ROLLBACK; -- change to COMMIT when satisfied
SQL
```

## Guidelines

- Never hard-code credentials; always use `PG_*` env vars.
- Default to `ROLLBACK` on mutations until the user confirms the result looks correct.
- Add `LIMIT` to all exploratory SELECTs.
- Use parameterised queries (`$1`, `$2` placeholders with `-v` or heredoc) when user-supplied values are involved to avoid injection.
