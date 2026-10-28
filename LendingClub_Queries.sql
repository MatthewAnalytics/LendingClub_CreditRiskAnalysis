--Query 1: Portfolio Scope & Asset Sizing Check
SELECT 
    COUNT(*) AS total_loan_contracts,
    SUM(loan_amnt) AS total_nominal_capital_extended,
    AVG(loan_amnt) AS average_corporate_loan_size
FROM loan_portfolio;


--Query 2: Credit Grade Concentration of Capital
SELECT 
    grade,
    COUNT(*) AS contract_count,
    -- Formats the total capital to look like a professional financial statement
    TO_CHAR(SUM(loan_amnt), '$999,999,999,999') AS total_capital_exposed,
    -- Calculates the percentage of the entire portfolio this grade represents
    ROUND((COUNT(*)::NUMERIC / 2260701) * 100, 2) AS portfolio_share_pct
FROM loan_portfolio
GROUP BY grade
ORDER BY grade ASC;


--Query 3: Gross Capital Recovery Analytics
SELECT 
    grade,
    TO_CHAR(SUM(loan_amnt), '$999,999,999,999') AS capital_extended,
    TO_CHAR(SUM(total_pymnt), '$999,999,999,999') AS total_cash_recovered,
    -- Capital Recovery Rate Formula
    ROUND((SUM(total_pymnt) / SUM(loan_amnt)) * 100, 2) AS capital_recovery_rate_pct
FROM loan_portfolio
WHERE grade IS NOT NULL AND grade != ''
GROUP BY grade
ORDER BY grade ASC;


--Query 4: Asset Write-Off Variance
SELECT 
    grade,
    -- Counts active, healthy loans
    COUNT(CASE WHEN loan_status IN ('Current', 'Fully Paid') THEN 1 END) AS healthy_loan_count,
    -- Counts impaired, toxic loans
    COUNT(CASE WHEN loan_status IN ('Charged Off', 'Default', 'Late (31-120 days)') THEN 1 END) AS toxic_loan_count,
    -- Calculates the explicit Default Rate by contract volume
    ROUND(
        (COUNT(CASE WHEN loan_status IN ('Charged Off', 'Default') THEN 1 END)::NUMERIC / COUNT(*)) * 100, 2
    ) AS write_off_rate_pct
FROM loan_portfolio
WHERE grade IS NOT NULL AND grade != ''
GROUP BY grade
ORDER BY grade ASC;


--Query 5: Time-Series Analysis
SELECT 
    -- Slices the last 4 characters of the date string to isolate the year
    RIGHT(issue_d, 4) AS loan_vintage_year,
    COUNT(*) AS total_loans_issued,
    TO_CHAR(SUM(loan_amnt), '$999,999,999,999') AS total_capital_allocated,
    -- Calculates the Non-Performing Asset (NPA) rate by capital volume
    ROUND(
        (SUM(CASE WHEN loan_status IN ('Charged Off', 'Default', 'Late (31-120 days)') THEN loan_amnt ELSE 0 END) / 
        SUM(loan_amnt)) * 100, 2
    ) AS npa_capital_rate_pct
FROM loan_portfolio
WHERE issue_d IS NOT NULL AND issue_d != ''
GROUP BY RIGHT(issue_d, 4)
ORDER BY loan_vintage_year DESC;



--Query 6: Risk-Adjusted Return vs. Leverage
WITH LeverageSegments AS (
    SELECT 
        id,
        loan_amnt,
        total_pymnt,
        -- Safely cast the interest rate text column to numerical decimals for math
        int_rate::NUMERIC AS coupon_rate, 
        dti,
        -- Dynamic Window Function to divide 2.2+ Million rows into 5 exact performance percentiles
        NTILE(5) OVER(ORDER BY dti ASC) AS leverage_tier
    FROM loan_portfolio
    WHERE dti IS NOT NULL AND dti > 0
)
SELECT 
    leverage_tier,
    ROUND(MIN(dti)::NUMERIC, 2) AS min_dti_in_tier,
    ROUND(MAX(dti)::NUMERIC, 2) AS max_dti_in_tier,
    ROUND(AVG(coupon_rate), 2) AS avg_coupon_yield_pct,
    ROUND((SUM(total_pymnt) / SUM(loan_amnt)) * 100, 2) AS capital_recovery_rate_pct
FROM LeverageSegments
GROUP BY leverage_tier
ORDER BY leverage_tier ASC;


--Query 7: Expected Losses / Allowance for Credit Losses
WITH HistoricalRiskCoefficients AS (
    -- Step 1: Isolate closed historical assets to calculate real loss performance per grade
    SELECT 
        grade,
        -- Probability of Default (PD): Closed contracts that failed vs. Total closed contracts
        COUNT(CASE WHEN loan_status = 'Charged Off' THEN 1 END)::NUMERIC / 
            NULLIF(COUNT(CASE WHEN loan_status IN ('Fully Paid', 'Charged Off') THEN 1 END), 0) AS probability_of_default,
        
        -- Loss Given Default (LGD): Average principal lost on default contracts after collateral recovery
        SUM(CASE WHEN loan_status = 'Charged Off' THEN (loan_amnt - total_pymnt) ELSE 0 END) / 
            NULLIF(SUM(CASE WHEN loan_status = 'Charged Off' THEN loan_amnt ELSE 0 END), 0) AS loss_given_default
    FROM loan_portfolio
    WHERE grade IS NOT NULL AND grade != ''
    GROUP BY grade
),
ActiveExposure AS (
    -- Step 2: Sum up active capital exposure currently working out in the market
    SELECT 
        grade,
        SUM(loan_amnt) AS active_capital_exposed
    FROM loan_portfolio
    WHERE loan_status IN ('Current', 'In Grace Period', 'Late (16-30 days)')
    GROUP BY grade
)
-- Step 3: Combine metrics to build the Expected Loss Provision Model
SELECT 
    a.grade,
    TO_CHAR(a.active_capital_exposed, '$999,999,999,999') AS active_portfolio_exposure,
    ROUND(r.probability_of_default * 100, 2) AS calculated_pd_pct,
    ROUND(r.loss_given_default * 100, 2) AS calculated_lgd_pct,
    -- Expected Loss Formula: Exposure * PD * LGD
    TO_CHAR(
        SUM(a.active_capital_exposed * r.probability_of_default * r.loss_given_default), 
        '$999,999,999,999'
    ) AS required_credit_loss_reserve
FROM ActiveExposure a
JOIN HistoricalRiskCoefficients r ON a.grade = r.grade
GROUP BY a.grade, a.active_capital_exposed, r.probability_of_default, r.loss_given_default
ORDER BY a.grade ASC;



--Query 8: Monthly Cash Inflow Projections
WITH MonthlyCashFlows AS (
    SELECT 
        -- Standardize chronological windows
        RIGHT(issue_d, 4) AS calendar_year,
        LEFT(issue_d, 3) AS calendar_month,
        -- Aggregate recurring contract obligations
        SUM(installment) AS scheduled_monthly_inflow
    FROM loan_portfolio
    WHERE loan_status IN ('Current', 'Fully Paid')
      AND issue_d IS NOT NULL 
      AND issue_d LIKE '%-%'
    GROUP BY RIGHT(issue_d, 4), LEFT(issue_d, 3)
)
SELECT 
    calendar_year,
    calendar_month,
    TO_CHAR(scheduled_monthly_inflow, '$999,999,999,999') AS scheduled_monthly_cash_inflow,
    -- Running total over time to track liquidity accumulation velocity
    TO_CHAR(
        SUM(scheduled_monthly_inflow) OVER(
            ORDER BY calendar_year ASC, 
                     CASE calendar_month
                        WHEN 'Jan' THEN 1 WHEN 'Feb' THEN 2 WHEN 'Mar' THEN 3 
                        WHEN 'Apr' THEN 4 WHEN 'May' THEN 5 WHEN 'Jun' THEN 6 
                        WHEN 'Jul' THEN 7 WHEN 'Aug' THEN 8 WHEN 'Sep' THEN 9 
                        WHEN 'Oct' THEN 10 WHEN 'Nov' THEN 11 WHEN 'Dec' THEN 12
                        ELSE 13
                     END
        ), 
        '$999,999,999,999'
    ) AS cumulative_liquidity_velocity
FROM MonthlyCashFlows
ORDER BY calendar_year DESC, 
         CASE calendar_month
            WHEN 'Jan' THEN 1 WHEN 'Feb' THEN 2 WHEN 'Mar' THEN 3 
            WHEN 'Apr' THEN 4 WHEN 'May' THEN 5 WHEN 'Jun' THEN 6 
            WHEN 'Jul' THEN 7 WHEN 'Aug' THEN 8 WHEN 'Sep' THEN 9 
            WHEN 'Oct' THEN 10 WHEN 'Nov' THEN 11 WHEN 'Dec' THEN 12
            ELSE 13
         END DESC;



--Query 9: Geographic Concentration of Risk
SELECT 
    addr_state AS us_state,
    COUNT(*) AS total_loan_contracts,
    TO_CHAR(SUM(loan_amnt), '$999,999,999,999') AS total_capital_exposed,
    -- Calculates percentage concentration of the bank's total balance sheet
    ROUND((COUNT(*)::NUMERIC / 2260701) * 100, 2) AS state_portfolio_share_pct,
    -- Calculates the specific localized default rate
    ROUND(
        (COUNT(CASE WHEN loan_status IN ('Charged Off', 'Default') THEN 1 END)::NUMERIC / COUNT(*)) * 100, 2
    ) AS localized_write_off_rate_pct
FROM loan_portfolio
WHERE addr_state IS NOT NULL AND addr_state != ''
GROUP BY addr_state
ORDER BY total_loan_contracts DESC
LIMIT 10; -- Isolate the Top 10 exposed states for executive reporting



--Query 10: Employment Tenure & Debt Stability Matrix
SELECT 
    CASE 
        WHEN emp_length IS NULL OR emp_length = '' OR emp_length = 'n/a' THEN 'Unreported/Unemployed'
        ELSE emp_length
    END AS employment_duration,
    COUNT(*) AS total_borrower_contracts,
    TO_CHAR(AVG(annual_inc), '$999,999,999') AS mean_annual_income,
    TO_CHAR(AVG(loan_amnt), '$999,999,999') AS average_credit_line_extended,
    -- Localized default performance tracking per career tenure cohort
    ROUND(
        (COUNT(CASE WHEN loan_status IN ('Charged Off', 'Default') THEN 1 END)::NUMERIC / COUNT(*)) * 100, 2
    ) AS cohort_write_off_rate_pct
FROM loan_portfolio
GROUP BY 
    CASE 
        WHEN emp_length IS NULL OR emp_length = '' OR emp_length = 'n/a' THEN 'Unreported/Unemployed'
        ELSE emp_length
    END
ORDER BY cohort_write_off_rate_pct DESC;
