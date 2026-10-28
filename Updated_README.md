# 📈 Institutional Credit Risk & Strategy Analytics
### Data Engineering & Corporate Finance Case Study
**Author:** Matthew Hanna  
**Specialty Focus:** PostgreSQL, ETL Pipelines, Credit Risk Modeling (PD/LGD/EL), Dynamic Data Sanitization, Window Functions

---

## Project Overview & Objective
This project analyzes a massive institutional credit and consumer debt asset matrix spanning over **2.26 million historical loan contracts** to evaluate portfolio stability and isolate clean risk performance metrics [cite: 1]. In financial analytics, evaluating historical performance without accounting for cohort timelines, borrower leverage, or text formatting anomalies yields distorted risk signals [cite: 1].

The core objective of this study was to engineer an optimized data extraction and database pipeline in PostgreSQL that sanitizes raw data files, standardizes text fields, and utilizes advanced common table expressions to model **Expected Losses (EL)**, track **Liquidity Velocity**, and identify the ultimate **Credit Performance Breakpoints** across the history of the portfolio [cite: 1].

---

## Tech Stack & Database Architecture
*   **Database Engine:** PostgreSQL [cite: 1]
*   **Data Pipeline Engine:** Python 3.13 (Pandas Framework) [cite: 1]
*   **Visual Interface:** pgAdmin 4 [cite: 1]
*   **Core Concepts Demonstrated:** Common Table Expressions (CTEs), Partitioned Window Functions (`NTILE()`, `SUM() OVER()`), Conditional Logic (`CASE WHEN`), Inline Data Type Casting (`::NUMERIC`), File Encoding Sanitization [cite: 1].

---

## Strategic Business Questions & Key Findings

### 1. Macro Trend Analysis: Identifying the "Crisis Vintage" (Vintage Analysis)
*   **The Problem:** All-time historical averages merge completely different macroeconomic cycles together, creating a flat signal that hides periods of dangerous underwriting [cite: 1].
*   **The Solution:** Chronologically extracted, isolated, and grouped total capital allocated against non-performing asset (NPA) dollar volumes by loan origination year [cite: 1].
*   **Key Insight:** While newer loan cohorts appeared pristine, **the 2015 Vintage was exposed as the highest-risk origination window in the bank's history, hitting a peak 19.00% NPA Rate** [cite: 1]. Over \$1 out of every \$5 lent during 2015 turned toxic or defaulted, signaling a historical breakdown in baseline credit risk controls or heavy macroeconomic pressure during that cycle [cite: 1].

### 2. Data Cleaning & Encoding Inconsistencies
*   **The Problem:** Initial database bulk copy commands crashed completely at line 991,013 due to hidden, non-standard text artifacts within raw borrower fields (e.g., job titles), while a 70+ column Kaggle layout caused memory panics and structural column mismatches [cite: 1].
*   **The Solution:** Engineered a custom Python ETL script that filtered the data down to 21 target analytical columns, aggressively stripped out non-UTF8 string anomalies, and applied strict text-scrubbing parameters (`errors='ignore'`) [cite: 1].
*   **Result:** Successfully bypassed the data-entry corruption layers, allowing a flawless, lightning-fast command-line stream (`\copy`) of **all 2,260,701 rows representing \$34.01 Billion in total capital** into the database [cite: 1].

### 3. Pinpointing the "Leverage Cliff" Breakpoint
*   **The Problem:** Evaluating credit margins purely by checking average interest rates fails to account for whether aggressive yields actually protect the bank against highly leveraged corporations [cite: 1].
*   **The Solution:** Segmented the entire 2.26 million row database into 5 distinct borrower leverage percentiles based on Debt-to-Income (`dti`) ratios using an advanced statistical window function (`NTILE`) [cite: 1].
*   **Key Insight:** Discovered an absolute **Leverage Cliff at Tier 5 (DTI > 26.19)** [cite: 1]. While average coupon yields climbed aggressively to a peak of 14.58% to compensate for risk, **actual capital recovery rates collapsed to a portfolio low of 76.02%**, proving empirically that high interest pricing completely fails to recover margins once a borrower crosses the 26.19 leverage threshold [cite: 1].

---

## SQL Query Breakdown & Highlights

### --Query 1: Portfolio Scope & Asset Sizing Check
*   **Business Intent:** Profile absolute size, scale, and mean exposure boundaries of the baseline asset portfolio [cite: 1].

```sql
SELECT 
    COUNT(*) AS total_loan_contracts,
    SUM(loan_amnt) AS total_nominal_capital_extended,
    AVG(loan_amnt) AS average_corporate_loan_size
FROM loan_portfolio;
```

*   **Empirical Discovery:** Baseline metrics confirm **2,260,701 active positions** representing **\$34,016,115,925** in deployed capital with an average line sizing of **\$15,046.93** [cite: 1].

---

### --Query 2: Credit Grade Concentration of Capital
*   **Business Intent:** Segment exposure balance sheet across asset grades to identify concentration risks [cite: 1].

```sql
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
```

*   **Empirical Discovery:** Middle-market risk segments (**Grades B and C**) dominate portfolio structure, dictating **58.1% of entire balance sheet exposure** (\$19.18 Billion exposed) [cite: 1].

---

### --Query 3: Gross Capital Recovery Analytics
*   **Business Intent:** Analyze structural efficiency by tracking principal recovered against total original capital deployment [cite: 1].

```sql
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
```

*   **Empirical Discovery:** Uncovered a counter-intuitive **Maturity J-Curve**. Top-tier positions (Grade A: 73.99% recovery) display lower indices than distressed positions (Grade F: 92.48%) due to a high density of newer, non-matured active paying contracts [cite: 1].

---

### --Query 4: Asset Write-Off Variance
*   **Business Intent:** Isolate healthy performing cash lines from non-performing assets (NPAs) to calculate direct default rates per tranche [cite: 1].

```sql
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
```

*   **Empirical Discovery:** Risk pricing models validated: asset degradation scales predictably from a minimal **3.28% default floor in Grade A** to an unstable **37.48% default failure in Grade G** [cite: 1].

---

### --Query 5: Time-Series Analysis
*   **Business Intent:** Group contracts by origination year to monitor structural shifts in underwriting policy discipline across macro economic cycles [cite: 1].

```sql
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
```

*   **Empirical Discovery:** The **2015 Vintage represents the peak crisis cohort**, generating a massive **19.00% NPA Rate**, signaling a historical relaxation of internal credit rules or significant macro stress [cite: 1].

---

### --Query 6: Risk-Adjusted Return vs. Leverage
*   **Business Intent:** Evaluate if charging premium interest yields to high debt-to-income (DTI) companies successfully drives margin or drives asset collapse [cite: 1].

```sql
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
```

*   **Empirical Discovery:** Discovered the **Leverage Cliff Breakpoint**. While coupon yields scale aggressively up to **14.58% in Tier 5**, actual recovery performance drops sharply to **76.02%**, proving that elevated pricing parameters fail to cover structural default volume beyond a 26.19 DTI threshold [cite: 1].

---

### --Query 7: Expected Losses / Allowance for Credit Losses
*   **Business Intent:** Model regulatory expected losses (EL = EAD x PD x LGD) across active working exposures to structure defensive liquidity pools [cite: 1].

```sql
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
        (a.active_capital_exposed * r.probability_of_default * r.loss_given_default), 
        '$999,999,999,999'
    ) AS required_credit_loss_reserve
FROM ActiveExposure a
JOIN HistoricalRiskCoefficients r ON a.grade = r.grade
ORDER BY a.grade ASC;
```

*   **Empirical Discovery:** LGD parameters mirror structural stability between **45%-50%** globally, while Grade C segments dictate the largest capital preservation necessity, demanding a **\$448.84 Million isolated treasury reserve pool** [cite: 1].

---

### --Query 8: Monthly Cash Inflow Projections
*   **Business Intent:** Map recurring asset installment cash generation velocity across active contracts to establish dynamic liquidity profiles [cite: 1].

```sql
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
```

*   **Empirical Discovery:** Asset liquidity engine shows high compounding runway velocity, accelerating from sub-\$100k startup phases to a massive **\$21,149,043 monthly run-rate capacity** by late 2018 [cite: 1].

---

### --Query 9: Geographic Concentration of Risk
*   **Business Intent:** Quantify macroeconomic asset vulnerability and localized default variances by geographic territory boundaries [cite: 1].

```sql
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
```

*   **Empirical Discovery:** Discovered systemic exposure vulnerabilities within California (**13.91% allocation share matching \$4.80 Billion exposed capital**). Top regional areas demonstrate uniform deterioration rates ranging from **10.27% to 12.99%** [cite: 1].

---

### --Query 10: Employment Tenure & Debt Stability Matrix
*   **Business Intent:** Test structural reliability of employment history durations (`emp_length`) against cash flow consistency parameters [cite: 1].

```sql
SELECT 
    CASE WHEN emp_length IS NULL OR emp_length = '' OR emp_length = 'n/a' THEN 'Unreported/Unemployed' ELSE emp_length END AS employment_duration,
    COUNT(*) AS total_borrower_contracts,
    TO_CHAR(AVG(annual_inc), '$999,999,999') AS mean_annual_income,
    TO_CHAR(AVG(loan_amnt), '$999,999,999') AS average_credit_line_extended,
    ROUND((COUNT(CASE WHEN loan_status IN ('Charged Off', 'Default') THEN 1 END)::NUMERIC / COUNT(*)) * 100, 2) AS cohort_write_off_rate_pct
FROM loan_portfolio
GROUP BY CASE WHEN emp_length IS NULL OR emp_length = '' OR emp_length = 'n/a' THEN 'Unreported/Unemployed' ELSE emp_length END
ORDER BY cohort_write_off_rate_pct DESC;
```

*   **Empirical Discovery:** Statistical modeling **debunks employment tenure longevity rules**. Active defaults for veteran talent (`10+ years` at 11.11% failure) track closely to freshman professionals (`< 1 year` at 11.68% failure) [cite: 1]. Credit focus shifts exclusively away from career age parameters to focus instead on mitigating the un-disclosed income tiers (**14.38% default leakage**) [cite: 1].

---

## 🚀 Key Takeaways & Strategic Credit Advisory Recommendations
1.  **Enact Credit Caps for Tier 5 Leverage:** Recommend immediate underwriting adjustments enforcing automated constraints on credit applications exhibiting an independent **Debt-to-Income calculation above 26.19%**, as pricing structures can no longer neutralize downside default scaling [cite: 1].
2.  **Bolster Regional Allocations Out of California:** Implement geographical capital distribution constraints to decrease single-state systemic exposure from its current peak concentration profile down to a safer target boundary [cite: 1].
3.  **Refine Asset-Liability Capital Reserves:** Treasury management must proactively reallocate cash reserve accounts to fund credit loss pools matching the quantified capital at risk findings [cite: 1].

---

## Summary Conclusion
By shifting focus from flat static lookup summaries to complex quantitative risk models, this project extracted clean, action-oriented financial intelligence from millions of raw, unformatted loan contracts [cite: 1]. It debunks legacy underwriting assumptions regarding employment tenure stability, maps critical geographic risk clusters, and establishes the exact data manipulation, auditing, and architectural schema logic necessary for senior asset-liability management and corporate treasury advisory teams [cite: 1].
