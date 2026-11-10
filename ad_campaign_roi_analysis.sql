-- ============================================================================
-- PROJECT: Multi-Channel Ad Spend ROI & Conversion Funnel Analysis
-- AUTHOR:  Vaibhav D. Gourkhede
-- TOOLS:   SQL (MySQL / SQLite), Google Sheets, Power BI
-- DATASET: 12,000 Daily Ad Performance & Conversion Funnel Records (Jan–Sept 2026)
--          across 24 Campaigns, 5 Channels, 4 Regions, and 2 Device Types
-- ============================================================================

-- ============================================================================
-- 1. DATABASE SCHEMA DEFINITION (3 Relational Tables)
-- ============================================================================

CREATE TABLE IF NOT EXISTS campaigns (
    campaign_id          VARCHAR(20) PRIMARY KEY,
    campaign_name        VARCHAR(100) NOT NULL,
    channel              VARCHAR(50)  NOT NULL, -- Google Search, YouTube Ads, Google Display, Instagram Ads, Email Marketing
    objective            VARCHAR(50)  NOT NULL, -- Direct Purchase, Retargeting, Lead Gen, Brand Awareness
    target_region        VARCHAR(50)  NOT NULL, -- Bengaluru, Mumbai, Hyderabad, Gurugram
    allocated_budget_inr DECIMAL(12,2) NOT NULL
);

CREATE TABLE IF NOT EXISTS daily_ad_performance (
    record_id            INT PRIMARY KEY,
    campaign_id          VARCHAR(20) NOT NULL,
    report_date          DATE NOT NULL,
    device_type          VARCHAR(20) NOT NULL, -- Mobile, Desktop
    impressions          INT NOT NULL,
    clicks               INT NOT NULL,
    spend_inr            DECIMAL(12,2) NOT NULL,
    FOREIGN KEY (campaign_id) REFERENCES campaigns(campaign_id)
);

CREATE TABLE IF NOT EXISTS conversions_funnel (
    record_id            INT PRIMARY KEY,
    campaign_id          VARCHAR(20) NOT NULL,
    landing_page_views   INT NOT NULL,
    add_to_cart_signups  INT NOT NULL,
    completed_orders     INT NOT NULL,
    revenue_inr          DECIMAL(14,2) NOT NULL,
    FOREIGN KEY (record_id) REFERENCES daily_ad_performance(record_id),
    FOREIGN KEY (campaign_id) REFERENCES campaigns(campaign_id)
);

-- ============================================================================
-- 2. CORE BUSINESS & ANALYTICAL SQL QUERIES (10 Queries)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- QUERY 1: Executive Portfolio KPI Summary (Multi-Table JOIN & Aggregations)
-- Purpose: Compute top-line ad spend, funnel volume, ROAS, and CPA across all
--          12,000 daily records.
-- Verified Result: Spend = ₹2.13 Cr | Revenue = ₹18.72 Cr | ROAS = 8.80x | Orders = 88,561
-- ----------------------------------------------------------------------------
SELECT 
    COUNT(DISTINCT p.record_id)                                AS total_daily_records,
    COUNT(DISTINCT c.campaign_id)                              AS total_campaigns,
    SUM(p.impressions)                                         AS total_impressions,
    SUM(p.clicks)                                              AS total_clicks,
    ROUND(SUM(p.clicks) * 100.0 / SUM(p.impressions), 2)       AS overall_ctr_pct,
    ROUND(SUM(p.spend_inr), 2)                                 AS total_spend_inr,
    SUM(f.completed_orders)                                    AS total_orders,
    ROUND(SUM(f.completed_orders) * 100.0 / SUM(p.clicks), 2)  AS click_to_order_cvr_pct,
    ROUND(SUM(f.revenue_inr), 2)                               AS total_revenue_inr,
    ROUND(SUM(f.revenue_inr) / SUM(p.spend_inr), 2)            AS overall_roas_x,
    ROUND(SUM(p.spend_inr) / SUM(f.completed_orders), 2)       AS overall_cpa_inr
FROM daily_ad_performance p
INNER JOIN conversions_funnel f ON p.record_id = f.record_id
INNER JOIN campaigns c          ON p.campaign_id = c.campaign_id;

-- ----------------------------------------------------------------------------
-- QUERY 2: Channel-Wise ROI & Efficiency Scorecard
-- Purpose: Compare acquisition cost (CPA), click-through rate (CTR), conversion
--          rate (CVR), and Return on Ad Spend (ROAS) across all 5 channels.
-- Key Insight: Email Marketing (43.71x ROAS) and Google Search (12.20x ROAS)
--              drive 80.97% of total revenue, while Google Display lags at 0.21x.
-- ----------------------------------------------------------------------------
SELECT 
    c.channel,
    COUNT(DISTINCT c.campaign_id)                              AS active_campaigns,
    SUM(p.impressions)                                         AS impressions,
    SUM(p.clicks)                                              AS clicks,
    ROUND(SUM(p.clicks) * 100.0 / SUM(p.impressions), 2)       AS ctr_pct,
    ROUND(SUM(p.spend_inr), 2)                                 AS total_spend_inr,
    SUM(f.completed_orders)                                    AS completed_orders,
    ROUND(SUM(f.completed_orders) * 100.0 / SUM(p.clicks), 2)  AS cvr_pct,
    ROUND(SUM(f.revenue_inr), 2)                               AS total_revenue_inr,
    ROUND(SUM(f.revenue_inr) / SUM(p.spend_inr), 2)            AS roas_x,
    ROUND(SUM(p.spend_inr) / SUM(f.completed_orders), 2)       AS cpa_inr
FROM campaigns c
INNER JOIN daily_ad_performance p ON c.campaign_id = p.campaign_id
INNER JOIN conversions_funnel f   ON p.record_id = f.record_id
GROUP BY c.channel
ORDER BY roas_x DESC;

-- ----------------------------------------------------------------------------
-- QUERY 3: Full-Funnel Stage Drop-Off Analysis by Channel (CTE)
-- Purpose: Pinpoint exactly where users drop off in the 5-stage funnel:
--          Impressions -> Clicks -> Landing Page Views -> Cart/Signup -> Order.
-- Key Insight: Google Display loses 90.29% of users between Landing Page View
--              and Add-to-Cart, signaling low-intent banner traffic.
-- ----------------------------------------------------------------------------
WITH channel_funnel AS (
    SELECT 
        c.channel,
        SUM(p.impressions)         AS impressions,
        SUM(p.clicks)              AS clicks,
        SUM(f.landing_page_views)  AS lpv,
        SUM(f.add_to_cart_signups) AS carts,
        SUM(f.completed_orders)    AS orders
    FROM campaigns c
    INNER JOIN daily_ad_performance p ON c.campaign_id = p.campaign_id
    INNER JOIN conversions_funnel f   ON p.record_id = f.record_id
    GROUP BY c.channel
)
SELECT 
    channel,
    impressions,
    clicks,
    ROUND(clicks * 100.0 / impressions, 2)        AS impr_to_click_pct,
    lpv,
    ROUND(lpv * 100.0 / clicks, 2)                AS click_to_lpv_pct,
    carts,
    ROUND(carts * 100.0 / lpv, 2)                 AS lpv_to_cart_pct,
    orders,
    ROUND(orders * 100.0 / carts, 2)              AS cart_to_order_pct
FROM channel_funnel
ORDER BY lpv_to_cart_pct DESC;

-- ----------------------------------------------------------------------------
-- QUERY 4: Underperforming Campaign Audit (GROUP BY + HAVING + CASE WHEN)
-- Purpose: Identify wasted ad spend by flagging campaigns with ROAS < 1.0x
--          so marketing teams can reallocate budget.
-- Key Insight: 7 campaigns consumed ₹39.57 Lakhs (18.6% of total spend) with
--              ROAS <= 0.50x.
-- ----------------------------------------------------------------------------
SELECT 
    c.campaign_id,
    c.campaign_name,
    c.channel,
    c.objective,
    c.target_region,
    ROUND(SUM(p.spend_inr), 2)                                    AS spend_inr,
    SUM(f.completed_orders)                                       AS orders,
    ROUND(SUM(f.revenue_inr), 2)                                  AS revenue_inr,
    ROUND(SUM(f.revenue_inr) / SUM(p.spend_inr), 2)               AS roas_x,
    CASE 
        WHEN SUM(f.revenue_inr) / SUM(p.spend_inr) < 0.25 THEN 'CRITICAL: Pause Immediately'
        WHEN SUM(f.revenue_inr) / SUM(p.spend_inr) < 1.00 THEN 'WARNING: Cut Budget by 50%'
        ELSE 'HEALTHY'
    END                                                           AS action_recommendation
FROM campaigns c
INNER JOIN daily_ad_performance p ON c.campaign_id = p.campaign_id
INNER JOIN conversions_funnel f   ON p.record_id = f.record_id
GROUP BY c.campaign_id, c.campaign_name, c.channel, c.objective, c.target_region
HAVING (SUM(f.revenue_inr) / SUM(p.spend_inr)) < 1.00
ORDER BY roas_x ASC;

-- ----------------------------------------------------------------------------
-- QUERY 5: Top 2 Campaigns per Channel by Net Return (Window Function: DENSE_RANK)
-- Purpose: Rank campaigns within each channel by net revenue contribution
--          (Revenue minus Spend) using DENSE_RANK() OVER (PARTITION BY ...).
-- ----------------------------------------------------------------------------
WITH campaign_profit AS (
    SELECT 
        c.channel,
        c.campaign_id,
        c.campaign_name,
        ROUND(SUM(p.spend_inr), 2)                       AS spend_inr,
        ROUND(SUM(f.revenue_inr), 2)                     AS revenue_inr,
        ROUND(SUM(f.revenue_inr) - SUM(p.spend_inr), 2)  AS net_return_inr,
        ROUND(SUM(f.revenue_inr) / SUM(p.spend_inr), 2)  AS roas_x,
        DENSE_RANK() OVER (
            PARTITION BY c.channel 
            ORDER BY (SUM(f.revenue_inr) - SUM(p.spend_inr)) DESC
        ) AS channel_rank
    FROM campaigns c
    INNER JOIN daily_ad_performance p ON c.campaign_id = p.campaign_id
    INNER JOIN conversions_funnel f   ON p.record_id = f.record_id
    GROUP BY c.channel, c.campaign_id, c.campaign_name
)
SELECT *
FROM campaign_profit
WHERE channel_rank <= 2
ORDER BY channel, channel_rank;

-- ----------------------------------------------------------------------------
-- QUERY 6: Month-over-Month (MoM) Revenue & Spend Trend (CTE + LAG Window Function)
-- Purpose: Track monthly growth trajectory and calculate MoM % revenue change.
-- ----------------------------------------------------------------------------
WITH monthly_metrics AS (
    SELECT 
        SUBSTR(p.report_date, 1, 7)      AS report_month,
        ROUND(SUM(p.spend_inr), 2)       AS monthly_spend_inr,
        SUM(f.completed_orders)          AS monthly_orders,
        ROUND(SUM(f.revenue_inr), 2)     AS monthly_revenue_inr
    FROM daily_ad_performance p
    INNER JOIN conversions_funnel f ON p.record_id = f.record_id
    GROUP BY SUBSTR(p.report_date, 1, 7)
)
SELECT 
    report_month,
    monthly_spend_inr,
    monthly_orders,
    monthly_revenue_inr,
    LAG(monthly_revenue_inr) OVER (ORDER BY report_month) AS prev_month_revenue_inr,
    ROUND(
        (monthly_revenue_inr - LAG(monthly_revenue_inr) OVER (ORDER BY report_month)) * 100.0
        / LAG(monthly_revenue_inr) OVER (ORDER BY report_month),
        2
    ) AS mom_revenue_growth_pct
FROM monthly_metrics
ORDER BY report_month;

-- ----------------------------------------------------------------------------
-- QUERY 7: Device-Level Conversion & ROAS Comparison (Mobile vs. Desktop)
-- Purpose: Compare conversion efficiency between Mobile and Desktop traffic.
-- Key Insight: Mobile drives 61.8% of clicks, but Desktop converts at a higher
--              rate (6.77% CVR vs 5.44% on Mobile) and higher ROAS (10.00x vs 8.06x).
-- ----------------------------------------------------------------------------
SELECT 
    p.device_type,
    SUM(p.impressions)                                         AS impressions,
    SUM(p.clicks)                                              AS clicks,
    ROUND(SUM(p.spend_inr), 2)                                 AS spend_inr,
    SUM(f.completed_orders)                                    AS completed_orders,
    ROUND(SUM(f.completed_orders) * 100.0 / SUM(p.clicks), 2)  AS click_to_order_cvr_pct,
    ROUND(SUM(f.revenue_inr), 2)                               AS revenue_inr,
    ROUND(SUM(f.revenue_inr) / SUM(p.spend_inr), 2)            AS roas_x
FROM daily_ad_performance p
INNER JOIN conversions_funnel f ON p.record_id = f.record_id
GROUP BY p.device_type
ORDER BY roas_x DESC;

-- ----------------------------------------------------------------------------
-- QUERY 8: Regional Market Performance (Bengaluru, Hyderabad, Gurugram, Mumbai)
-- Purpose: Evaluate regional ROAS and order volume across target Indian hubs.
-- Key Insight: Bengaluru leads at 10.41x ROAS (₹6.34 Cr revenue), followed by
--              Hyderabad at 9.52x ROAS.
-- ----------------------------------------------------------------------------
SELECT 
    c.target_region,
    COUNT(DISTINCT c.campaign_id)                              AS campaigns_count,
    ROUND(SUM(p.spend_inr), 2)                                 AS spend_inr,
    SUM(f.completed_orders)                                    AS orders,
    ROUND(SUM(f.revenue_inr), 2)                               AS revenue_inr,
    ROUND(SUM(f.revenue_inr) / SUM(p.spend_inr), 2)            AS roas_x,
    ROUND(SUM(p.spend_inr) / SUM(f.completed_orders), 2)       AS cpa_inr
FROM campaigns c
INNER JOIN daily_ad_performance p ON c.campaign_id = p.campaign_id
INNER JOIN conversions_funnel f   ON p.record_id = f.record_id
GROUP BY c.target_region
ORDER BY roas_x DESC;

-- ----------------------------------------------------------------------------
-- QUERY 9: Pareto Revenue Concentration (Running Total Window Function)
-- Purpose: Calculate cumulative revenue share across campaigns to test the
--          80/20 Pareto rule.
-- ----------------------------------------------------------------------------
WITH campaign_rev AS (
    SELECT 
        c.campaign_id,
        c.campaign_name,
        c.channel,
        ROUND(SUM(f.revenue_inr), 2) AS revenue_inr
    FROM campaigns c
    INNER JOIN daily_ad_performance p ON c.campaign_id = p.campaign_id
    INNER JOIN conversions_funnel f   ON p.record_id = f.record_id
    GROUP BY c.campaign_id, c.campaign_name, c.channel
)
SELECT 
    campaign_id,
    campaign_name,
    channel,
    revenue_inr,
    ROUND(revenue_inr * 100.0 / SUM(revenue_inr) OVER (), 2) AS pct_of_total_rev,
    ROUND(
        SUM(revenue_inr) OVER (ORDER BY revenue_inr DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) * 100.0
        / SUM(revenue_inr) OVER (),
        2
    ) AS cumulative_revenue_pct
FROM campaign_rev
ORDER BY revenue_inr DESC;

-- ----------------------------------------------------------------------------
-- QUERY 10: Budget Reallocation Impact Simulation (What-If Modeling via CTE)
-- Purpose: Quantify the revenue lift of shifting 50% of spend (₹19.78L) from
--          the 7 underperforming campaigns (ROAS < 1.0x) into Google Search.
-- ----------------------------------------------------------------------------
WITH campaign_roas AS (
    SELECT 
        c.campaign_id,
        c.channel,
        SUM(p.spend_inr)   AS spend,
        SUM(f.revenue_inr) AS revenue,
        SUM(f.revenue_inr) / SUM(p.spend_inr) AS roas
    FROM campaigns c
    INNER JOIN daily_ad_performance p ON c.campaign_id = p.campaign_id
    INNER JOIN conversions_funnel f   ON p.record_id = f.record_id
    GROUP BY c.campaign_id, c.channel
),
wasted_pool AS (
    SELECT 
        SUM(spend)        AS low_roas_spend,
        SUM(revenue)      AS low_roas_revenue,
        SUM(spend) * 0.50 AS reallocated_budget_50pct
    FROM campaign_roas
    WHERE roas < 1.0
),
search_benchmark AS (
    SELECT SUM(revenue) / SUM(spend) AS search_roas
    FROM campaign_roas
    WHERE channel = 'Google Search'
)
SELECT 
    ROUND(w.low_roas_spend, 2)                                     AS current_underperforming_spend_inr,
    ROUND(w.reallocated_budget_50pct, 2)                           AS budget_shifted_50pct_inr,
    ROUND(s.search_roas, 2)                                        AS target_search_roas_x,
    ROUND(w.reallocated_budget_50pct * s.search_roas, 2)           AS projected_new_revenue_inr,
    ROUND((w.reallocated_budget_50pct * s.search_roas) - (w.low_roas_revenue * 0.50), 2) AS net_incremental_revenue_lift_inr
FROM wasted_pool w
CROSS JOIN search_benchmark s;