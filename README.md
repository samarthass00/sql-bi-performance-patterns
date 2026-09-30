# SQL Patterns for BI Data Loads

> **Representative portfolio project.** Written independently with tiny synthetic fixtures. No client code or data.

Four SQL patterns that sit underneath most Power BI and Tableau reporting: incremental loading, slowly changing dimensions, source-to-target reconciliation, and window-function calculations. Each has an executable **DuckDB** version covered by `pytest`, and a **SQL Server / Azure SQL (T-SQL)** version for reference.

| # | Pattern | Why BI teams need it | DuckDB (tested) | T-SQL (reference) |
|---|---|---|---|---|
| 1 | Watermark incremental load + `MERGE` | Refresh only changed rows, so loads stay short as history grows | [`duckdb/01_incremental_merge.sql`](duckdb/01_incremental_merge.sql) | [`tsql/01_incremental_merge.sql`](tsql/01_incremental_merge.sql) |
| 2 | SCD Type 2 dimension | Report "as it was" (for example, the segment a customer was in when they ordered) | [`duckdb/02_scd_type2.sql`](duckdb/02_scd_type2.sql) | [`tsql/02_scd_type2.sql`](tsql/02_scd_type2.sql) |
| 3 | Reconciliation by business date | Prove report totals match the source before sign-off | [`duckdb/03_reconciliation.sql`](duckdb/03_reconciliation.sql) | [`tsql/03_reconciliation.sql`](tsql/03_reconciliation.sql) |
| 4 | Window functions: running total, moving average, top-N, gaps and islands | Common measures that are cheaper to pre-compute in SQL than in DAX | [`duckdb/04_window_functions.sql`](duckdb/04_window_functions.sql) | [`tsql/04_window_functions.sql`](tsql/04_window_functions.sql) |

## What the tests prove

- **Incremental MERGE:** updates changed rows, inserts new ones, ignores rows older than the watermark, keeps only the latest duplicate, advances the watermark, and is idempotent when re-run.
- **SCD2:** a changed customer gets a closed row and a new current row, unchanged customers are untouched, new customers are inserted, each customer has exactly one current row, and surrogate keys stay unique.
- **Reconciliation:** returns only the dates where counts or amounts differ, with the difference.
- **Window functions:** running totals, top-2 per customer, and streak lengths match hand-calculated values.

## Quick start

```bash
git clone https://github.com/samarthass00/sql-bi-performance-patterns.git
cd sql-bi-performance-patterns
pip install -r requirements.txt
pytest -q
```

## Performance notes (SQL Server / Azure SQL)

- Index the watermark column (`modified_at`) with `INCLUDE` columns so the incremental filter seeks instead of scanning. An example is in `tsql/01_incremental_merge.sql`.
- Use `MERGE ... WITH (HOLDLOCK)`, or split it into separate `UPDATE` and `INSERT` statements, to avoid race conditions under concurrent loads.
- Push window calculations into SQL views or tables when a DAX iterator over a large fact table is the bottleneck. In Power BI, keep query folding intact so these views are filtered at the source.

## Limitations

- The T-SQL files are hand-translated and not executed in CI (CI has no SQL Server). Validate them on a dev database before use.
- Deletes, soft deletes, and late-arriving dimension members are out of scope.

## License

MIT — see [LICENSE](LICENSE).
