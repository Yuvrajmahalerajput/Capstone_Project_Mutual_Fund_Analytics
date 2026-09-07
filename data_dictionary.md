# Bluestock Mutual Fund Analytics — Data Dictionary

**Database:** `bluestock_mf.db` (SQLite)
**Schema type:** Star schema — 3 dimension tables, 8 fact tables
**Last built:** 2026-09-07
**Source files:** 9 raw CSVs in `data/raw/`, cleaned into 10 CSVs in `data/processed/`

---

## 1. Overview

| Layer | Table | Grain | Row Count |
|---|---|---|---|
| Dimension | `dim_fund` | 1 row per scheme (amfi_code) | 40 |
| Dimension | `dim_date` | 1 row per calendar day | 1,610 |
| Dimension | `dim_amc` | 1 row per fund house / AMC | 10 |
| Fact (core) | `fact_nav` | 1 row per (fund, day) NAV | 64,320 |
| Fact (core) | `fact_transactions` | 1 row per investor transaction | 32,778 |
| Fact (core) | `fact_performance` | 1 row per fund performance snapshot | 40 |
| Fact (core) | `fact_aum` | 1 row per (AMC, reporting date) | 90 |
| Fact (extended) | `fact_benchmark` | 1 row per (index, day) close | 8,050 |
| Fact (extended) | `fact_category_inflow` | 1 row per (category, month) | 144 |
| Fact (extended) | `fact_holdings` | 1 row per (fund, stock, portfolio date) | 322 |
| Fact (extended) | `fact_sip_industry` | 1 row per month | 48 |

The task brief asked for `dim_fund`, `dim_date`, `fact_nav`, `fact_transactions`,
`fact_performance`, `fact_aum`. Since the upload also included AMC AUM history,
benchmark index history, category inflows, portfolio holdings and industry SIP
history, these were modeled as four additional "extended" fact tables (plus
`dim_amc`) so no source data goes unused. All extended tables key off the same
`dim_date`, and `fact_holdings`/`fact_benchmark` also key off `dim_fund`.

---

## 2. Dimension Tables

### 2.1 `dim_fund`
Source: `fund_master.csv` → `data/processed/fund_master_clean.csv`

| Column | Type | Business Definition |
|---|---|---|
| `amfi_code` | INTEGER (PK) | Unique AMFI scheme code identifying the fund |
| `fund_house` | TEXT | Asset Management Company (AMC) name |
| `scheme_name` | TEXT | Full scheme name incl. plan/option |
| `category` | TEXT | Broad asset class: Equity / Debt |
| `sub_category` | TEXT | SEBI sub-category, e.g. Large Cap, Liquid |
| `plan` | TEXT | Regular or Direct plan |
| `launch_date` | TEXT (ISO date) | Date the scheme was launched |
| `benchmark` | TEXT | Benchmark index the scheme is measured against |
| `expense_ratio_pct` | REAL | Annual expense ratio, percent of AUM |
| `exit_load_pct` | REAL | Exit load percentage on early redemption |
| `min_sip_amount` | INTEGER | Minimum SIP instalment amount (INR) |
| `min_lumpsum_amount` | INTEGER | Minimum lumpsum investment amount (INR) |
| `fund_manager` | TEXT | Name of the fund manager |
| `risk_category` | TEXT | Qualitative risk bucket (e.g. Moderate) |
| `sebi_category_code` | TEXT | SEBI scheme category code |
| `expense_ratio_flag` | INTEGER (0/1) | 1 if expense_ratio_pct is outside the plausible 0.1%–2.5% band |

### 2.2 `dim_date`
Source: generated (not from a raw file) — covers the full date range spanned
by all fact sources (2022-01-01 to 2026-05-31).

| Column | Type | Business Definition |
|---|---|---|
| `date_key` | INTEGER (PK) | Date surrogate key, format YYYYMMDD |
| `full_date` | TEXT (ISO date) | Calendar date |
| `year` | INTEGER | Calendar year |
| `quarter` | INTEGER | Calendar quarter (1–4) |
| `month` | INTEGER | Calendar month (1–12) |
| `month_name` | TEXT | Full month name |
| `month_key` | TEXT | YYYY-MM, used for monthly rollups/joins from monthly-grain sources |
| `day` | INTEGER | Day of month |
| `day_of_week` | INTEGER | 0=Monday … 6=Sunday |
| `day_name` | TEXT | Full weekday name |
| `is_weekend` | INTEGER (0/1) | 1 if Saturday/Sunday |
| `is_month_end` | INTEGER (0/1) | 1 if last calendar day of the month |

### 2.3 `dim_amc` (extended)
Source: derived from `amc_aum_history.csv` fund-house list.

| Column | Type | Business Definition |
|---|---|---|
| `amc_id` | INTEGER (PK, autoincrement) | Surrogate key for the AMC |
| `fund_house` | TEXT (unique) | Asset Management Company name |

---

## 3. Fact Tables

### 3.1 `fact_nav`
Source: `nav_history.csv` → `data/processed/nav_history_clean.csv`

| Column | Type | Business Definition |
|---|---|---|
| `nav_id` | INTEGER (PK, autoincrement) | Surrogate key |
| `amfi_code` | INTEGER (FK → dim_fund) | Scheme identifier |
| `date_key` | INTEGER (FK → dim_date) | Date of the NAV observation |
| `nav` | REAL, > 0 | Net Asset Value (INR per unit) on that date |

**Cleaning applied:** parsed dates, sorted by (amfi_code, date), reindexed each
fund to a continuous daily calendar and forward-filled NAV across
weekends/non-trading days (18,320 values filled), removed duplicate
(amfi_code, date) rows, validated `nav > 0`.

### 3.2 `fact_transactions`
Source: `investor_transactions.csv` → `data/processed/investor_transactions_clean.csv`

| Column | Type | Business Definition |
|---|---|---|
| `transaction_id` | INTEGER (PK, autoincrement) | Surrogate key |
| `investor_id` | TEXT | Unique investor identifier |
| `amfi_code` | INTEGER (FK → dim_fund) | Scheme the transaction relates to |
| `date_key` | INTEGER (FK → dim_date) | Transaction date |
| `transaction_type` | TEXT, enum | `SIP`, `Lumpsum`, or `Redemption` |
| `amount_inr` | REAL, > 0 | Transaction amount in INR |
| `state` | TEXT | Investor's state (India) |
| `city` | TEXT | Investor's city |
| `city_tier` | TEXT, enum | `T30` (top 30 cities) or `B30` (beyond top 30) |
| `age_group` | TEXT, enum | 18-25 / 26-35 / 36-45 / 46-55 / 56+ |
| `gender` | TEXT, enum | Male / Female |
| `annual_income_lakh` | REAL | Self-reported annual income (INR lakh) |
| `payment_mode` | TEXT | UPI / Cheque / Mandate / Net Banking |
| `kyc_status` | TEXT, enum | `Verified`, `Pending`, or `Rejected` |

**Cleaning applied:** standardised `transaction_type` to the SIP/Lumpsum/Redemption
enum, parsed and reformatted dates to ISO, validated `amount_inr > 0`,
validated `kyc_status` against the allowed enum, dropped fully duplicate rows.

### 3.3 `fact_performance`
Source: `scheme_performance.csv` → `data/processed/scheme_performance_clean.csv`

| Column | Type | Business Definition |
|---|---|---|
| `performance_id` | INTEGER (PK, autoincrement) | Surrogate key |
| `amfi_code` | INTEGER (FK → dim_fund, unique) | Scheme identifier |
| `return_1yr_pct` | REAL | Trailing 1-year return (%) |
| `return_3yr_pct` | REAL | Trailing 3-year annualised return (%) |
| `return_5yr_pct` | REAL | Trailing 5-year annualised return (%) |
| `benchmark_3yr_pct` | REAL | Benchmark's 3-year annualised return (%) |
| `alpha` | REAL | Jensen's alpha vs. benchmark |
| `beta` | REAL | Beta vs. benchmark |
| `sharpe_ratio` | REAL | Risk-adjusted return (Sharpe ratio) |
| `sortino_ratio` | REAL | Downside-risk-adjusted return (Sortino ratio) |
| `std_dev_ann_pct` | REAL | Annualised standard deviation of returns (%) |
| `max_drawdown_pct` | REAL | Maximum peak-to-trough drawdown (%), ≤ 0 |
| `aum_crore` | REAL | Assets under management (INR crore) |
| `expense_ratio_pct` | REAL | Annual expense ratio (%) |
| `morningstar_rating` | INTEGER, 1–5 | Morningstar star rating |
| `risk_grade` | TEXT | Qualitative risk grade |
| `anomaly_flags` | TEXT | Semicolon-separated list of failed sanity checks (blank if none) |
| `is_anomalous` | INTEGER (0/1) | 1 if any anomaly_flags present |

**Cleaning applied:** coerced all metric columns to numeric, dropped rows that
failed numeric coercion, checked `expense_ratio_pct` against the 0.1%–2.5% band,
flagged (not dropped) rows failing plausibility checks (|return| > 100%, beta
outside 0–3, sharpe outside -5–10, negative std_dev, positive max_drawdown,
non-positive AUM) — anomaly detail also written to
`scheme_performance_anomalies.csv`.

### 3.4 `fact_aum`
Source: `amc_aum_history.csv` → `data/processed/amc_aum_history_clean.csv`

| Column | Type | Business Definition |
|---|---|---|
| `aum_id` | INTEGER (PK, autoincrement) | Surrogate key |
| `amc_id` | INTEGER (FK → dim_amc) | AMC identifier |
| `date_key` | INTEGER (FK → dim_date) | AUM reporting date (semi-annual) |
| `aum_lakh_crore` | REAL | Total AMC AUM, in lakh crore INR |
| `aum_crore` | REAL, > 0 | Total AMC AUM, in crore INR |
| `num_schemes` | INTEGER, > 0 | Number of schemes managed by the AMC on that date |

**Cleaning applied:** parsed dates, validated `aum_crore > 0` and
`num_schemes > 0`, dropped duplicate (date, fund_house) rows.

### 3.5 `fact_benchmark` (extended)
Source: `benchmark_history.csv` → `data/processed/benchmark_history_clean.csv`

| Column | Type | Business Definition |
|---|---|---|
| `benchmark_id` | INTEGER (PK, autoincrement) | Surrogate key |
| `index_name` | TEXT | Market index name (e.g. NIFTY50) |
| `date_key` | INTEGER (FK → dim_date) | Trading date |
| `close_value` | REAL, > 0 | Index closing value |

### 3.6 `fact_category_inflow` (extended)
Source: `category_inflows.csv` → `data/processed/category_inflows_clean.csv`

| Column | Type | Business Definition |
|---|---|---|
| `category_inflow_id` | INTEGER (PK, autoincrement) | Surrogate key |
| `category` | TEXT | Fund category (e.g. Large Cap, Mid Cap) |
| `date_key` | INTEGER (FK → dim_date) | First day of the reporting month |
| `net_inflow_crore` | REAL | Industry-wide net inflow for the category (INR crore) |

### 3.7 `fact_holdings` (extended)
Source: `portfolio_holdings.csv` → `data/processed/portfolio_holdings_clean.csv`

| Column | Type | Business Definition |
|---|---|---|
| `holding_id` | INTEGER (PK, autoincrement) | Surrogate key |
| `amfi_code` | INTEGER (FK → dim_fund) | Scheme holding the stock |
| `date_key` | INTEGER (FK → dim_date) | Portfolio snapshot date |
| `stock_symbol` | TEXT | Exchange ticker symbol of the holding |
| `stock_name` | TEXT | Full company name |
| `sector` | TEXT | Sector classification |
| `weight_pct` | REAL, 0–100 | Holding's weight in the portfolio (%) |
| `market_value_cr` | REAL | Market value of the holding (INR crore) |
| `current_price_inr` | REAL | Current market price per share (INR) |

### 3.8 `fact_sip_industry` (extended)
Source: `sip_industry_history.csv` → `data/processed/sip_industry_history_clean.csv`

| Column | Type | Business Definition |
|---|---|---|
| `sip_industry_id` | INTEGER (PK, autoincrement) | Surrogate key |
| `date_key` | INTEGER (FK → dim_date) | First day of the reporting month |
| `sip_inflow_crore` | REAL | Total industry SIP inflow that month (INR crore) |
| `active_sip_accounts_crore` | REAL | Active SIP accounts, in crore |
| `new_sip_accounts_lakh` | REAL | New SIP accounts opened that month, in lakh |
| `sip_aum_lakh_crore` | REAL | Total SIP AUM, in lakh crore INR |
| `yoy_growth_pct` | REAL, nullable | Year-over-year SIP inflow growth (%); NULL for the first 12 months where no prior-year value exists |

---

## 4. Processed CSVs (`data/processed/`)

| File | Rows | Cleaned From |
|---|---|---|
| `nav_history_clean.csv` | 64,320 | `nav_history.csv` |
| `investor_transactions_clean.csv` | 32,778 | `investor_transactions.csv` |
| `scheme_performance_clean.csv` | 40 | `scheme_performance.csv` |
| `fund_master_clean.csv` | 40 | `fund_master.csv` |
| `amc_aum_history_clean.csv` | 90 | `amc_aum_history.csv` |
| `benchmark_history_clean.csv` | 8,050 | `benchmark_history.csv` |
| `category_inflows_clean.csv` | 144 | `category_inflows.csv` |
| `portfolio_holdings_clean.csv` | 322 | `portfolio_holdings.csv` |
| `sip_industry_history_clean.csv` | 48 | `sip_industry_history.csv` |
| `dim_date.csv` | 1,610 | generated (calendar dimension) |
| `scheme_performance_anomalies.csv` | 0 | anomaly detail from `scheme_performance.csv` (empty — no anomalies found) |

## 5. Data Quality Summary

- No missing values were found in any of the 9 raw source files except
  `sip_industry_history.csv.yoy_growth_pct` (12 nulls — legitimate, no
  prior-year data exists for the first 12 months of the series).
- No exact duplicate rows were present in any raw file.
- All `transaction_type`, `kyc_status`, `city_tier`, enum values in
  `investor_transactions.csv` were already within their expected domains.
- All `expense_ratio_pct` values in `fund_master.csv` and
  `scheme_performance.csv` fell within the expected 0.1%–2.5% band; no rows
  were flagged.
- `nav_history.csv` covered every expected business day already (no
  holiday gaps to fill on the business-day calendar); NAV was still forward-
  filled onto a full daily calendar (including weekends) so downstream joins
  against `dim_date` never hit a missing day.
- No performance-metric anomalies were flagged in `scheme_performance.csv`
  under the plausibility checks applied.

## 6. Source Reference

All raw CSVs originate from the uploaded dataset in `data/raw/`:
`amc_aum_history.csv`, `benchmark_history.csv`, `category_inflows.csv`,
`fund_master.csv`, `investor_transactions.csv`, `nav_history.csv`,
`portfolio_holdings.csv`, `scheme_performance.csv`, `sip_industry_history.csv`.
