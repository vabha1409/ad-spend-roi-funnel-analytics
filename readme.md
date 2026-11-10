# Multi-Channel Ad Spend ROI & Conversion Funnel Analysis

**Author:** Vaibhav D. Gourkhede  
**Tech Stack:** SQL (MySQL / SQLite), [Google Sheets (Live Model)](https://docs.google.com/spreadsheets/d/1vMFoFTKc2Z9y9fEcK1pwSrskuCS6LGA-E73Ts2IGoas/edit), Microsoft Power BI (DAX), Python  
**Dataset Scale:** 12,000 Daily Ad Performance & Funnel Records across 24 Campaigns, 5 Channels, 4 Cities, and 2 Device Types  

## Power BI Executive Dashboard Preview


## 1. Executive Summary & Business Problem
Marketing teams running multi-channel digital campaigns across **Google Search**, **YouTube Ads**, **Google Display**, **Instagram Ads**, and **Email Marketing** need to identify where users drop off in the post-click conversion funnel and which campaigns waste budget.

This project analyzes **12,000 daily campaign records (₹2.13 Cr total ad spend, 65.42M impressions, 1.49M clicks, and 88,561 completed orders generating ₹18.72 Cr in revenue)** to answer three core business questions:
1. **Channel Efficiency:** Which channels deliver the highest Return on Ad Spend (`ROAS`) and lowest Cost Per Acquisition (`CPA`)?
2. **Funnel Bottlenecks:** At which stage (`Impressions → Clicks → Landing Page Views → Add-to-Cart/Signups → Completed Orders`) do underperforming campaigns lose users?
3. **Budget Optimization:** How much incremental revenue can be unlocked by reallocating 50% of budget from underperforming campaigns (`ROAS < 1.0x`) into high-intent channels without increasing total ad spend?

## 2. Repository Structure
* `ad_campaign_roi_analysis.sql` — 10 business SQL queries using multi-table `INNER JOINs`, `CTEs`, `Window Functions (LAG, DENSE_RANK, SUM OVER)`, `CASE WHEN`, and `HAVING`.
* `ad_campaign_funnel_dataset_12k.csv` — 12,000-row cleaned dataset used for Power BI modeling.
* `setup_and_run_sql.py` — Python script that builds the 3-table relational SQLite database (`campaigns`, `daily_ad_performance`, `conversions_funnel`) and runs verification queries.
* `dashboard_preview.png` & `Ad_Spend_ROI_Dashboard.pdf` — Power BI Executive ROI & Funnel Overview dashboard export.
* **Live Google Sheets Funnel & Reallocation Model:** [View Google Sheet](https://docs.google.com/spreadsheets/d/1vMFoFTKc2Z9y9fEcK1pwSrskuCS6LGA-E73Ts2IGoas/edit)

## 3. Channel Performance Scorecard (Verified via SQL & Google Sheets)

| Advertising Channel | Campaigns | Impressions | Clicks | CTR (%) | Total Spend (₹) | Completed Orders | Click-to-Order CVR (%) | Total Revenue (₹) | ROAS (x) | CPA (₹) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Email Marketing** | 4 | 3,815,606 | 199,382 | 5.23% | ₹9,73,543 | 22,147 | 11.11% | ₹4,25,57,688 | **43.71x** | ₹43.96 |
| **Google Search** | 5 | 6,863,489 | 470,741 | 6.86% | ₹89,40,163 | 47,493 | 10.09% | ₹10,90,44,639 | **12.20x** | ₹188.24 |
| **YouTube Ads** | 5 | 16,640,862 | 303,648 | 1.82% | ₹41,32,229 | 8,343 | 2.75% | ₹1,66,65,668 | **4.03x** | ₹495.29 |
| **Instagram Ads** | 5 | 13,621,671 | 320,659 | 2.35% | ₹50,62,896 | 10,267 | 3.20% | ₹1,85,07,391 | **3.66x** | ₹493.12 |
| **Google Display** | 5 | 24,478,799 | 194,794 | 0.80% | ₹21,60,462 | 311 | 0.16% | ₹4,52,860 | **0.21x** | ₹6,946.82 |
| **Portfolio Total** | **24** | **65,420,427** | **1,489,224** | **2.28%** | **₹2,12,69,292** | **88,561** | **5.95%** | **₹18,72,28,245** | **8.80x** | **₹240.17** |

## 4. Key Insights & Recommendations
* **Pareto Concentration (81% of Revenue from 2 Channels):** **Google Search** (₹10.90 Cr revenue, `12.20x` ROAS) and **Email Marketing** (₹4.26 Cr revenue, `43.71x` ROAS) generated **80.97% of total portfolio revenue** while consuming only **46.61% of total ad spend**.
* **Funnel Drop-Off Diagnosis:** Using a multi-stage SQL CTE (`Query 3`), we isolated why **Google Display** underperformed (`0.21x` ROAS): while 64.4% of Display clicks reached the landing page (`125,480` views), **90.29% dropped off before Add-to-Cart**, and two broad-reach campaigns (`CMP-301` and `CMP-304`) recorded **zero completed orders** despite ₹8.45 Lakhs in spend.
* **Wasted Spend Audit (`HAVING ROAS < 1.0x`):** `Query 4` flagged **7 underperforming campaigns** (`CMP-205`, `CMP-301` to `CMP-305`, and `CMP-405`) that consumed **₹39,56,847 (18.6% of total budget)** while returning only ₹12,99,221 (`0.33x` blended ROAS).
* **Quantified Reallocation Impact:** Shifting **50% of wasted spend (₹19.78 Lakhs)** from the 7 sub-1.0x ROAS campaigns into high-intent **Google Search** (`12.20x` ROAS) projects **+₹2.35 Cr in net incremental revenue lift**, raising overall portfolio ROAS from **8.80x to 9.90x** with zero extra budget.
