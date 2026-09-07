# Capstone Project: Mutual Fund Analytics

## Day 1: Data Ingestion Complete

### Data Quality Summary
- **AMFI Code Validation:** Verified that the 6-digit identification codes match cleanly across the fund definitions and transaction tables.
- **SIP Data Trailing Gaps:** Noted an expected anomaly in `sip_industry_history.csv` where the first 12 months (the year 2022) have `NaN` values for `yoy_growth_pct` because there is no 2021 data to compare them against.

---

## Day 2: Cleaned Data + SQLite DB Loaded

### What this covers
Cleans all 9 raw mutual-fund datasets, models them into a SQLite star schema (`bluestock_mf.db`), and provides analytical queries plus a full data dictionary.

### Structure
```
data/raw/            9 original source CSVs (from Day 1)
data/processed/      10 cleaned CSVs (9 cleaned sources + generated dim_date.csv)
sql/schema.sql        Star schema DDL (CREATE TABLE statements, PK/FK)
sql/queries.sql        10 analytical queries (+ 1 bonus)
data_dictionary.md    Full column-level documentation
bluestock_mf.db        SQLite database (loaded, row counts verified)
```

### Cleaning applied
- `nav_history.csv` — parsed dates, sorted by amfi_code + date, reindexed each fund to a continuous daily calendar and forward-filled NAV across weekends/holidays (18,320 values filled), removed duplicates, validated NAV > 0.
- `investor_transactions.csv` — standardised `transaction_type` to SIP/Lumpsum/Redemption, validated amount > 0, fixed date formats, checked KYC status enum values.
- `scheme_performance.csv` — validated all return values are numeric, flagged anomalies (none found), checked expense_ratio range (0.1%–2.5%).
- Also cleaned the 6 supporting files: `fund_master`, `amc_aum_history`, `benchmark_history`, `category_inflows`, `portfolio_holdings`, `sip_industry_history`.

### Star schema
Dimensions: `dim_fund`, `dim_date`, `dim_amc`
Facts: `fact_nav`, `fact_transactions`, `fact_performance`, `fact_aum`, `fact_benchmark`, `fact_category_inflow`, `fact_holdings`, `fact_sip_industry`

See `data_dictionary.md` for full column definitions and business meaning of every field.

### Verification
Every table was loaded via `df.to_sql()` (SQLAlchemy) and the loaded row count was checked against the source CSV row count — all 11 tables matched exactly.

| Table | Rows |
|---|---|
| dim_fund | 40 |
| dim_date | 1,610 |
| dim_amc | 10 |
| fact_nav | 64,320 |
| fact_transactions | 32,778 |
| fact_performance | 40 |
| fact_aum | 90 |
| fact_benchmark | 8,050 |
| fact_category_inflow | 144 |
| fact_holdings | 322 |
| fact_sip_industry | 48 |
