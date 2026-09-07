-- ============================================================================
-- Bluestock Mutual Fund Analytics — Analytical Queries
-- Run against bluestock_mf.db
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Top 5 funds by AUM (latest performance snapshot)
-- ----------------------------------------------------------------------------
SELECT
    f.amfi_code,
    f.scheme_name,
    f.fund_house,
    f.category,
    p.aum_crore
FROM fact_performance p
JOIN dim_fund f ON f.amfi_code = p.amfi_code
ORDER BY p.aum_crore DESC
LIMIT 5;


-- ----------------------------------------------------------------------------
-- 2. Average NAV per month, per fund
-- ----------------------------------------------------------------------------
SELECT
    f.amfi_code,
    f.scheme_name,
    d.month_key,
    ROUND(AVG(n.nav), 4) AS avg_nav
FROM fact_nav n
JOIN dim_date d ON d.date_key = n.date_key
JOIN dim_fund f ON f.amfi_code = n.amfi_code
GROUP BY f.amfi_code, d.month_key
ORDER BY f.amfi_code, d.month_key;


-- ----------------------------------------------------------------------------
-- 3. SIP YoY growth: total SIP inflow (from investor transactions) by calendar
--    year, plus year-over-year percentage growth
-- ----------------------------------------------------------------------------
WITH sip_yearly AS (
    SELECT
        d.year,
        SUM(t.amount_inr) AS total_sip_amount
    FROM fact_transactions t
    JOIN dim_date d ON d.date_key = t.date_key
    WHERE t.transaction_type = 'SIP'
    GROUP BY d.year
)
SELECT
    year,
    total_sip_amount,
    LAG(total_sip_amount) OVER (ORDER BY year) AS prior_year_amount,
    ROUND(
        100.0 * (total_sip_amount - LAG(total_sip_amount) OVER (ORDER BY year))
        / NULLIF(LAG(total_sip_amount) OVER (ORDER BY year), 0), 2
    ) AS yoy_growth_pct
FROM sip_yearly
ORDER BY year;


-- ----------------------------------------------------------------------------
-- 4. Transactions by state — total amount and transaction count
-- ----------------------------------------------------------------------------
SELECT
    state,
    COUNT(*) AS txn_count,
    SUM(amount_inr) AS total_amount_inr,
    ROUND(AVG(amount_inr), 2) AS avg_amount_inr
FROM fact_transactions
GROUP BY state
ORDER BY total_amount_inr DESC;


-- ----------------------------------------------------------------------------
-- 5. Funds with expense_ratio < 1%
-- ----------------------------------------------------------------------------
SELECT
    amfi_code,
    scheme_name,
    fund_house,
    category,
    plan,
    expense_ratio_pct
FROM dim_fund
WHERE expense_ratio_pct < 1.0
ORDER BY expense_ratio_pct ASC;


-- ----------------------------------------------------------------------------
-- 6. Best risk-adjusted performers: top 10 funds by Sharpe ratio
--    (with return and risk context)
-- ----------------------------------------------------------------------------
SELECT
    f.scheme_name,
    f.category,
    p.return_3yr_pct,
    p.std_dev_ann_pct,
    p.sharpe_ratio,
    p.sortino_ratio,
    p.morningstar_rating
FROM fact_performance p
JOIN dim_fund f ON f.amfi_code = p.amfi_code
ORDER BY p.sharpe_ratio DESC
LIMIT 10;


-- ----------------------------------------------------------------------------
-- 7. SIP vs Lumpsum vs Redemption — investor behaviour split by city tier
-- ----------------------------------------------------------------------------
SELECT
    city_tier,
    transaction_type,
    COUNT(*) AS txn_count,
    SUM(amount_inr) AS total_amount_inr,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY city_tier), 2) AS pct_of_tier_txns
FROM fact_transactions
GROUP BY city_tier, transaction_type
ORDER BY city_tier, total_amount_inr DESC;


-- ----------------------------------------------------------------------------
-- 8. Fund category returns leaderboard: average 1yr/3yr/5yr return by category
-- ----------------------------------------------------------------------------
SELECT
    f.category,
    COUNT(*) AS num_funds,
    ROUND(AVG(p.return_1yr_pct), 2) AS avg_return_1yr,
    ROUND(AVG(p.return_3yr_pct), 2) AS avg_return_3yr,
    ROUND(AVG(p.return_5yr_pct), 2) AS avg_return_5yr,
    ROUND(AVG(p.expense_ratio_pct), 2) AS avg_expense_ratio
FROM fact_performance p
JOIN dim_fund f ON f.amfi_code = p.amfi_code
GROUP BY f.category
ORDER BY avg_return_3yr DESC;


-- ----------------------------------------------------------------------------
-- 9. Top sector exposure across all fund portfolio holdings
--    (aggregate market value and weighted average weight)
-- ----------------------------------------------------------------------------
SELECT
    sector,
    COUNT(DISTINCT amfi_code) AS num_funds_holding,
    ROUND(SUM(market_value_cr), 2) AS total_market_value_cr,
    ROUND(AVG(weight_pct), 2) AS avg_weight_pct
FROM fact_holdings
GROUP BY sector
ORDER BY total_market_value_cr DESC;


-- ----------------------------------------------------------------------------
-- 10. Investor cohort analysis: transaction value by age group and gender,
--     verified KYC only
-- ----------------------------------------------------------------------------
SELECT
    age_group,
    gender,
    COUNT(*) AS txn_count,
    SUM(amount_inr) AS total_amount_inr,
    ROUND(AVG(amount_inr), 2) AS avg_txn_amount,
    ROUND(AVG(annual_income_lakh), 2) AS avg_annual_income_lakh
FROM fact_transactions
WHERE kyc_status = 'Verified'
GROUP BY age_group, gender
ORDER BY age_group, gender;


-- ============================================================================
-- BONUS: AMC AUM growth over time (using extended fact_aum table)
-- ============================================================================
SELECT
    a.fund_house,
    d.full_date,
    fa.aum_crore,
    fa.num_schemes,
    fa.aum_crore - LAG(fa.aum_crore) OVER (PARTITION BY a.fund_house ORDER BY d.full_date) AS aum_change_crore
FROM fact_aum fa
JOIN dim_amc a ON a.amc_id = fa.amc_id
JOIN dim_date d ON d.date_key = fa.date_key
ORDER BY a.fund_house, d.full_date;
