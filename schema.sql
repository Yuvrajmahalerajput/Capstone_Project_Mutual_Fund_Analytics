-- ============================================================================
-- Bluestock Mutual Fund Analytics Warehouse — Star Schema
-- SQLite DDL
-- ============================================================================
-- Grain notes:
--   dim_fund        : one row per scheme (amfi_code)
--   dim_date        : one row per calendar day, 2022-01-01 .. 2026-05-31
--   dim_amc         : one row per fund house / AMC (extended dimension)
--   fact_nav        : one row per (fund, day) NAV observation
--   fact_transactions: one row per investor transaction
--   fact_performance : one row per fund performance snapshot
--   fact_aum         : one row per (AMC, reporting date) AUM snapshot
--   fact_benchmark    : one row per (index, day) close value        [extended]
--   fact_category_inflow: one row per (category, month) net inflow [extended]
--   fact_holdings     : one row per (fund, stock, portfolio date)  [extended]
--   fact_sip_industry : one row per (month) industry SIP metrics   [extended]
-- ============================================================================

PRAGMA foreign_keys = ON;

-- ----------------------------------------------------------------------------
-- DIMENSION: dim_fund
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS dim_fund;
CREATE TABLE dim_fund (
    amfi_code           INTEGER PRIMARY KEY,
    fund_house          TEXT NOT NULL,
    scheme_name         TEXT NOT NULL,
    category            TEXT NOT NULL,          -- Equity / Debt
    sub_category        TEXT NOT NULL,          -- Large Cap, Liquid, etc.
    plan                TEXT NOT NULL,           -- Regular / Direct
    launch_date         TEXT NOT NULL,           -- ISO date (YYYY-MM-DD)
    benchmark           TEXT NOT NULL,
    expense_ratio_pct   REAL NOT NULL,
    exit_load_pct       REAL NOT NULL,
    min_sip_amount      INTEGER NOT NULL,
    min_lumpsum_amount  INTEGER NOT NULL,
    fund_manager        TEXT NOT NULL,
    risk_category       TEXT NOT NULL,
    sebi_category_code  TEXT NOT NULL,
    expense_ratio_flag  INTEGER NOT NULL DEFAULT 0  -- 1 = outside 0.1%-2.5% band
);

-- ----------------------------------------------------------------------------
-- DIMENSION: dim_date
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS dim_date;
CREATE TABLE dim_date (
    date_key        INTEGER PRIMARY KEY,   -- YYYYMMDD
    full_date       TEXT NOT NULL,         -- ISO date (YYYY-MM-DD)
    year             INTEGER NOT NULL,
    quarter          INTEGER NOT NULL,
    month            INTEGER NOT NULL,
    month_name       TEXT NOT NULL,
    month_key        TEXT NOT NULL,        -- YYYY-MM, convenient for monthly rollups
    day              INTEGER NOT NULL,
    day_of_week      INTEGER NOT NULL,     -- 0 = Monday ... 6 = Sunday
    day_name         TEXT NOT NULL,
    is_weekend       INTEGER NOT NULL,     -- 1/0
    is_month_end     INTEGER NOT NULL      -- 1/0
);

-- ----------------------------------------------------------------------------
-- DIMENSION: dim_amc (extended — AMC/fund-house grain, used by fact_aum)
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS dim_amc;
CREATE TABLE dim_amc (
    amc_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    fund_house  TEXT NOT NULL UNIQUE
);

-- ----------------------------------------------------------------------------
-- FACT: fact_nav
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS fact_nav;
CREATE TABLE fact_nav (
    nav_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    amfi_code   INTEGER NOT NULL,
    date_key    INTEGER NOT NULL,
    nav         REAL NOT NULL CHECK (nav > 0),
    FOREIGN KEY (amfi_code) REFERENCES dim_fund(amfi_code),
    FOREIGN KEY (date_key)  REFERENCES dim_date(date_key),
    UNIQUE (amfi_code, date_key)
);
CREATE INDEX idx_fact_nav_fund ON fact_nav(amfi_code);
CREATE INDEX idx_fact_nav_date ON fact_nav(date_key);

-- ----------------------------------------------------------------------------
-- FACT: fact_transactions
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS fact_transactions;
CREATE TABLE fact_transactions (
    transaction_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    investor_id          TEXT NOT NULL,
    amfi_code            INTEGER NOT NULL,
    date_key             INTEGER NOT NULL,
    transaction_type      TEXT NOT NULL CHECK (transaction_type IN ('SIP','Lumpsum','Redemption')),
    amount_inr            REAL NOT NULL CHECK (amount_inr > 0),
    state                 TEXT NOT NULL,
    city                  TEXT NOT NULL,
    city_tier             TEXT NOT NULL,
    age_group             TEXT NOT NULL,
    gender                TEXT NOT NULL,
    annual_income_lakh    REAL NOT NULL,
    payment_mode          TEXT NOT NULL,
    kyc_status             TEXT NOT NULL CHECK (kyc_status IN ('Verified','Pending','Rejected')),
    FOREIGN KEY (amfi_code) REFERENCES dim_fund(amfi_code),
    FOREIGN KEY (date_key)  REFERENCES dim_date(date_key)
);
CREATE INDEX idx_fact_txn_fund ON fact_transactions(amfi_code);
CREATE INDEX idx_fact_txn_date ON fact_transactions(date_key);
CREATE INDEX idx_fact_txn_investor ON fact_transactions(investor_id);
CREATE INDEX idx_fact_txn_type ON fact_transactions(transaction_type);

-- ----------------------------------------------------------------------------
-- FACT: fact_performance  (point-in-time snapshot, one row per fund)
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS fact_performance;
CREATE TABLE fact_performance (
    performance_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    amfi_code            INTEGER NOT NULL,
    return_1yr_pct        REAL NOT NULL,
    return_3yr_pct        REAL NOT NULL,
    return_5yr_pct        REAL NOT NULL,
    benchmark_3yr_pct     REAL NOT NULL,
    alpha                 REAL NOT NULL,
    beta                  REAL NOT NULL,
    sharpe_ratio           REAL NOT NULL,
    sortino_ratio          REAL NOT NULL,
    std_dev_ann_pct        REAL NOT NULL,
    max_drawdown_pct       REAL NOT NULL,
    aum_crore              REAL NOT NULL,
    expense_ratio_pct      REAL NOT NULL,
    morningstar_rating     INTEGER NOT NULL CHECK (morningstar_rating BETWEEN 1 AND 5),
    risk_grade             TEXT NOT NULL,
    anomaly_flags          TEXT,
    is_anomalous            INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY (amfi_code) REFERENCES dim_fund(amfi_code),
    UNIQUE (amfi_code)
);
CREATE INDEX idx_fact_perf_fund ON fact_performance(amfi_code);

-- ----------------------------------------------------------------------------
-- FACT: fact_aum  (AMC-level AUM snapshot, semi-annual)
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS fact_aum;
CREATE TABLE fact_aum (
    aum_id           INTEGER PRIMARY KEY AUTOINCREMENT,
    amc_id           INTEGER NOT NULL,
    date_key         INTEGER NOT NULL,
    aum_lakh_crore   REAL NOT NULL,
    aum_crore        REAL NOT NULL CHECK (aum_crore > 0),
    num_schemes      INTEGER NOT NULL CHECK (num_schemes > 0),
    FOREIGN KEY (amc_id)   REFERENCES dim_amc(amc_id),
    FOREIGN KEY (date_key) REFERENCES dim_date(date_key),
    UNIQUE (amc_id, date_key)
);
CREATE INDEX idx_fact_aum_amc ON fact_aum(amc_id);
CREATE INDEX idx_fact_aum_date ON fact_aum(date_key);

-- ----------------------------------------------------------------------------
-- FACT (extended): fact_benchmark — market index close values
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS fact_benchmark;
CREATE TABLE fact_benchmark (
    benchmark_id    INTEGER PRIMARY KEY AUTOINCREMENT,
    index_name       TEXT NOT NULL,
    date_key         INTEGER NOT NULL,
    close_value      REAL NOT NULL CHECK (close_value > 0),
    FOREIGN KEY (date_key) REFERENCES dim_date(date_key),
    UNIQUE (index_name, date_key)
);
CREATE INDEX idx_fact_bench_date ON fact_benchmark(date_key);
CREATE INDEX idx_fact_bench_index ON fact_benchmark(index_name);

-- ----------------------------------------------------------------------------
-- FACT (extended): fact_category_inflow — monthly net inflow by category
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS fact_category_inflow;
CREATE TABLE fact_category_inflow (
    category_inflow_id  INTEGER PRIMARY KEY AUTOINCREMENT,
    category              TEXT NOT NULL,
    date_key               INTEGER NOT NULL,   -- first day of month
    net_inflow_crore       REAL NOT NULL,
    FOREIGN KEY (date_key) REFERENCES dim_date(date_key),
    UNIQUE (category, date_key)
);
CREATE INDEX idx_fact_catinflow_date ON fact_category_inflow(date_key);

-- ----------------------------------------------------------------------------
-- FACT (extended): fact_holdings — portfolio holdings per fund
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS fact_holdings;
CREATE TABLE fact_holdings (
    holding_id         INTEGER PRIMARY KEY AUTOINCREMENT,
    amfi_code           INTEGER NOT NULL,
    date_key             INTEGER NOT NULL,
    stock_symbol         TEXT NOT NULL,
    stock_name           TEXT NOT NULL,
    sector               TEXT NOT NULL,
    weight_pct           REAL NOT NULL CHECK (weight_pct > 0 AND weight_pct <= 100),
    market_value_cr       REAL NOT NULL,
    current_price_inr     REAL NOT NULL,
    FOREIGN KEY (amfi_code) REFERENCES dim_fund(amfi_code),
    FOREIGN KEY (date_key)  REFERENCES dim_date(date_key)
);
CREATE INDEX idx_fact_hold_fund ON fact_holdings(amfi_code);
CREATE INDEX idx_fact_hold_sector ON fact_holdings(sector);

-- ----------------------------------------------------------------------------
-- FACT (extended): fact_sip_industry — monthly industry-wide SIP metrics
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS fact_sip_industry;
CREATE TABLE fact_sip_industry (
    sip_industry_id            INTEGER PRIMARY KEY AUTOINCREMENT,
    date_key                    INTEGER NOT NULL,  -- first day of month
    sip_inflow_crore             REAL NOT NULL,
    active_sip_accounts_crore    REAL NOT NULL,
    new_sip_accounts_lakh        REAL NOT NULL,
    sip_aum_lakh_crore           REAL NOT NULL,
    yoy_growth_pct                REAL,             -- NULL for first 12 months (no prior year)
    FOREIGN KEY (date_key) REFERENCES dim_date(date_key),
    UNIQUE (date_key)
);
CREATE INDEX idx_fact_sip_date ON fact_sip_industry(date_key);
