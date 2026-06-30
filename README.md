# E-Commerce Profitability & Marketing Efficiency Analysis
**Prepared by: Victor Lu**
**Analysis Period: January 2024 – December 2025**

---

## Project Overview

This project analyses 2,000 e-commerce orders across eight product categories
and four sales channels, alongside marketing spend data from six advertising
platforms. The goal is to identify profitability drivers, channel inefficiencies,
return rate patterns, and marketing ROI — and to make a data-backed recommendation
for a 20% marketing budget reduction.

---

## Repository Contents

```
├── data/
│   ├── orders.csv                          Raw order-level data (2,000 rows)
│   ├── marketing_spend.csv                 Platform-level marketing data (144 rows)
│   └── products.csv                        Product reference table (207 rows)
│
├── sql/
│   └── optimized_queries.sql               All SQL queries covering Q1–Q5
│
├── reports/
│   ├── ecommerce_final_report.docx         Final report (Word format)
│   ├── ecommerce_final_report.pdf          Final report (PDF format)
│   └── ecommerce_performance_report_       Corrected version of original draft
│       corrected.pdf
│
├── dashboard/
│   └── ecommerce_dashboard_victor_lu.html  Standalone interactive dashboard
│                                           (opens in any browser)
│
└── powerbi/
    ├── orders.csv                          Data file for Power BI
    ├── marketing_spend.csv                 Data file for Power BI
    ├── products.csv                        Data file for Power BI
    ├── DAX_Measures_Victor_Lu.dax          All DAX measures (readable reference)
    ├── BatchCreate_Measures_Victor_Lu.csx  Tabular Editor batch import script
    └── PowerBI_Setup_Guide_Victor_Lu.txt   Step-by-step Power BI build guide
```

---

## Dataset Summary

| Table | Rows | Key Columns |
|---|---|---|
| orders | 2,000 | order_id, channel, primary_category, gross_revenue, profit, returned |
| marketing_spend | 144 | platform, month, spend, revenue_attributed, roas, cpa |
| products | 207 | product_id, category, sub_category, unit_cost, selling_price |

### Important Data Notes
- The `returned` column stores `'Yes'`/`'No'` strings — not booleans. All SQL
  and DAX return rate calculations use `returned = 'Yes'` explicitly.
- All 144 returned orders have `net_revenue = 0` exactly. Revenue loss
  calculations use `gross_revenue` as the denominator to avoid division by zero.
- 563 orders (28.2%) have negative profit — these are legitimate loss-making
  orders, not data errors.
- `marketing_spend` is platform-level aggregated data. It does not join to
  `orders` at the order level — no relationship should be created between them.
- Website and Mobile App have `platform_fee = 0` for all orders. Only
  Marketplace and Social Commerce incur platform charges.
- Cost reconciliation confirmed zero mismatches across all 2,000 orders:
  `product_cost + shipping_cost + platform_fee + transaction_fee = total_costs`

---

## Key Findings

### Q1 — Profit Margin by Category
| Category | Margin % | Key Driver |
|---|---|---|
| Electronics | 31.13% | Shipping only 13.5% of gross revenue |
| Toys | 26.15% | Low shipping cost |
| Home & Kitchen | 25.37% | Balanced cost structure |
| Food & Beverage | 24.76% | Low return rate (5.67%) |
| Sports | 23.50% | Mid-range across all drivers |
| Clothing | 19.99% | Shipping at 19.84% |
| Beauty | 17.39% | High product cost + shipping |
| Books | 11.94% | Shipping at 27.94% of gross revenue |

**Driver:** Shipping cost % is the sole differentiator. Product costs (38–42%)
and discount rates (6.5–8.4%) are near-uniform across all categories.

---

### Q2 — Channel Profitability
| Channel | Profit/Order | Margin % | Avg Platform Fee | Fee Drag % |
|---|---|---|---|---|
| Mobile App | $36.32 | 29.76% | $0.00 | 0.0% |
| Website | $31.60 | 27.01% | $0.00 | 0.0% |
| Social Commerce | $17.11 | 15.37% | $9.87 | 36.6% |
| Marketplace | $15.40 | 13.03% | $18.97 | 55.2% |

**Key insight:** Without platform fees, Marketplace would earn $34.37/order —
nearly matching Mobile App. The $18.97/order fee consumes 55.2% of pre-fee profit.

---

### Q3 — Return Rates & Revenue Lost
- **Overall return rate:** 7.20% (144 of 2,000 orders)
- **Total revenue lost:** $20,582 (7.40% of gross revenue)
- **Highest return rate:** Electronics (8.61%)
- **Anomaly:** Food & Beverage has the lowest return rate (5.67%) but the
  highest revenue loss % (9.50%) — high-value items are being returned
  disproportionately.
- **Worst channel:** Social Commerce (9.14% rate, 9.01% revenue loss %)

---

### Q4 — Marketing ROAS by Platform
| Platform | ROAS | Avg CPA | Efficiency Gap |
|---|---|---|---|
| TikTok Ads | 24.02x | $3.93 | +5.5% |
| Influencer | 22.70x | $4.80 | +7.8% |
| Instagram Ads | 15.73x | $5.55 | -0.4% |
| Google Ads | 14.38x | $6.48 | -3.4% |
| Facebook Ads | 11.45x | $8.38 | -6.2% |
| Email Marketing | 4.81x | $26.01 | -3.4% |

**Efficiency Gap** = Revenue Share % minus Spend Share %. Positive means the
platform earns more than its proportional cost. Negative means it costs more
than it returns.

---

### Q5 — 20% Budget Cut Recommendation
**Target:** $100,701 (20% of $503,506 total budget)
**Achieved:** $100,569 — within 0.1% of target ✓

| Platform | Action | Cut % | Saving |
|---|---|---|---|
| Email Marketing | Eliminate | 100% | $24,461 |
| Facebook Ads | Halve | 50% | $53,226 |
| Google Ads | Trim | 15% | $22,882 |
| Instagram Ads | Hold | 0% | — |
| Influencer | Protect | 0% | — |
| TikTok Ads | Protect | 0% | — |

**Priority months to cut first:** Email Dec/Oct 2025, Facebook Nov 2024 & 2025,
Google Sep/Jul 2025.

---

## SQL Queries

All queries are in `sql/optimized_queries.sql`. The file is structured in sections:

```
Section 1  — Schema setup & primary keys
Section 2  — Data quality checks
Q1         — Profit margin by product category (3 queries)
Q2         — Profitability across sales channels (2 queries)
Q3         — Return rate by category and channel (4 queries)
Q4         — Marketing spend ROAS by platform (2 queries)
Q5         — 20% budget cut recommendation (3 queries)
```

**Database:** MySQL 8.0+
**Key fix applied:** `marketing_spend.month` and `marketing_spend.platform`
must be `VARCHAR` before a composite primary key can be applied:
```sql
ALTER TABLE marketing_spend
    MODIFY COLUMN month    VARCHAR(10),
    MODIFY COLUMN platform VARCHAR(100);
```

---

## Interactive Dashboard

`dashboard/ecommerce_dashboard_victor_lu.html`

Open in any modern browser (Chrome, Edge, Safari). No installation required.
Requires an internet connection to load the Chart.js library from CDN.

**Pages:**
1. Overview — KPI cards, profit by category, channel revenue split, ROAS trend
2. Profitability — margin rankings, shipping vs margin scatter plot, full table
3. Channels — profit per order, before/after fee comparison, channel detail
4. Returns — return rates by category and channel, anomaly bubble chart
5. Marketing ROI — ROAS rankings, efficiency gap, 24-month ROAS trend
6. Budget Cut — current vs proposed spend, cut plan table, priority timeline

---

## Power BI Setup

All files are in the `powerbi/` folder. Full instructions are in
`PowerBI_Setup_Guide_Victor_Lu.txt`. Summary:

**Step 1 —** Install Power BI Desktop (free):
https://powerbi.microsoft.com/desktop

**Step 2 —** Load the 3 CSV files via Home → Get Data → Text/CSV

**Step 3 —** No relationships needed. All three tables are standalone
for this analysis. Do not create a relationship between `orders` and
`marketing_spend` — they do not share a join key.

**Step 4 —** Create the `_Measures` table manually before running the script:
Home → Enter Data → name it `_Measures` → Load

**Step 5 —** Install Tabular Editor 2 (free):
https://github.com/TabularEditor/TabularEditor/releases

**Step 6 —** In Power BI Desktop: External Tools → Tabular Editor →
Advanced Scripting → paste `BatchCreate_Measures_Victor_Lu.csx` → press F5
→ Ctrl+S to save back to Power BI

**Step 7 —** Build 6 report pages using the measures from the `_Measures`
table. Visual type reference:
- KPI values → Card (new) visual in the Visualizations panel
- Category/channel comparisons → Clustered Bar Chart
- Trends over time → Line Chart or Column Chart
- Proportions → Donut Chart
- Correlations → Scatter Chart
- Detailed data → Table visual

**DAX measures are organised into 8 display folders:**
1. Core Financials
2. Category Profitability
3. Channel Profitability
4. Return Rates
5. Marketing ROI
6. Budget Cut Analysis
7. Time Intelligence
8. KPI Status Labels

---

## Tools Used

| Tool | Purpose |
|---|---|
| MySQL 8.0 | Data validation, schema setup, all analytical queries |
| Python (pandas) | Data verification and cross-checking query results |
| Power BI Desktop | Interactive dashboard and DAX measures |
| Tabular Editor 2 | Batch DAX measure import via C# scripting |
| ReportLab | PDF report generation |
| python-docx | Word document generation |
| Chart.js | HTML dashboard charts |

---

## Recommendations Summary

| Priority | Area | Action |
|---|---|---|
| Immediate | Marketing | Eliminate Email Marketing — redirect $24,461 to TikTok/Influencer |
| Immediate | Marketing | Cut Facebook Ads 50% — target November months first |
| Immediate | Marketing | Trim Google Ads 15% — target September/July months |
| High | Product | Review Books shipping — 27.94% of gross is structural, not cyclical |
| High | Channels | Renegotiate Marketplace fees or apply price premium |
| High | Channels | Scale Mobile App — zero fees, $36.32 profit/order |
| Medium | Product | Review Beauty supplier + fulfilment contracts |
| Medium | Returns | Add size guides for Clothing, specs for Electronics |
| Medium | Returns | Investigate Food & Beverage high-value returns (9.50% loss rate) |
| Ongoing | Marketing | Protect TikTok (24.02x) and Influencer (22.70x) budgets |

---

*Analysis Period: January 2024 – December 2025*
*Prepared by: Victor Lu*
