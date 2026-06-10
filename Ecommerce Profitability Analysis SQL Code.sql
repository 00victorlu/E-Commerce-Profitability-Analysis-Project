SELECT * FROM marketing_spend;
SELECT * FROM orders;
SELECT * FROM products;


-- ============================================================
-- SECTION 1: SCHEMA SETUP & PRIMARY KEYS
-- ============================================================
 
-- Fix column types before adding composite PK
-- (TEXT columns cannot be used in keys without a length in MySQL)
ALTER TABLE marketing_spend
    MODIFY COLUMN month     VARCHAR(10),
    MODIFY COLUMN platform  VARCHAR(100);
 
-- Verify no duplicates exist before adding PK
SELECT month, platform, COUNT(*) AS cnt
FROM marketing_spend
GROUP BY month, platform
HAVING COUNT(*) > 1;
 
-- Add composite primary key
ALTER TABLE marketing_spend
ADD CONSTRAINT marketing_spend_pk
PRIMARY KEY (month, platform);
 
-- Verify PKs on orders and products
SELECT order_id,   COUNT(*) FROM orders   GROUP BY order_id   HAVING COUNT(*) > 1;
SELECT product_id, COUNT(*) FROM products GROUP BY product_id HAVING COUNT(*) > 1;
 
 
-- ============================================================
-- SECTION 2: DATA QUALITY CHECKS
-- ============================================================
 
-- NULL checks on primary keys
SELECT order_id   FROM orders          WHERE order_id   IS NULL;
SELECT product_id FROM products        WHERE product_id IS NULL;
SELECT month, platform FROM marketing_spend WHERE month IS NULL OR platform IS NULL;
 
-- NULL checks on critical order fields
SELECT *
FROM orders
WHERE order_id IS NULL
   OR order_date IS NULL
   OR gross_revenue IS NULL;
 
-- Negative value check
-- NOTE: profit CAN be legitimately negative for loss-making orders
-- (563 orders have negative profit in this dataset — expected behaviour)
SELECT *
FROM orders
WHERE gross_revenue  < 0
   OR product_cost   < 0
   OR shipping_cost  < 0;
 
-- Cost reconciliation: product_cost + shipping + fees must equal total_costs
SELECT
    order_id,
    product_cost,
    shipping_cost,
    platform_fee,
    transaction_fee,
    total_costs,
    ROUND(product_cost + shipping_cost + platform_fee + transaction_fee, 2) AS calculated_total
FROM orders
WHERE ROUND(product_cost + shipping_cost + platform_fee + transaction_fee, 2)
   <> ROUND(total_costs, 2);
 
-- Sanity checks
SELECT * FROM orders WHERE discount_amount > gross_revenue;
SELECT * FROM orders WHERE total_costs     > net_revenue;  -- 563 rows expected (loss-making orders)
 
-- Distinct value checks
SELECT DISTINCT channel         FROM orders;
SELECT DISTINCT payment_method  FROM orders;
SELECT DISTINCT region          FROM orders;
SELECT DISTINCT returned        FROM orders;  -- Confirms 'Yes'/'No' strings (not boolean)
 
-- Top 10 orders by revenue
SELECT * FROM orders ORDER BY gross_revenue DESC LIMIT 10;
 
 
-- ============================================================
-- Q1. PROFIT MARGIN BY PRODUCT CATEGORY
-- What is the average profit margin by category?
-- Which are most/least profitable, and what drives the difference?
-- ============================================================
 
-- 1a. Full margin summary with all cost drivers
-- Percentages use gross_revenue as base for fair cross-category comparison.
-- Key insight: product_cost_pct and shipping_pct are the primary margin drivers —
-- discounts and return rates are nearly uniform across categories.
SELECT
    primary_category,
    COUNT(*)                                                                    AS total_orders,
    ROUND(SUM(gross_revenue), 2)                                                AS gross_revenue,
    ROUND(SUM(net_revenue), 2)                                                  AS net_revenue,
    ROUND(SUM(total_costs), 2)                                                  AS total_costs,
    ROUND(SUM(profit), 2)                                                       AS total_profit,
 
    -- Core margin (on net_revenue — what the business actually received)
    ROUND(SUM(profit) / NULLIF(SUM(net_revenue), 0) * 100, 2)                  AS profit_margin_pct,
 
    -- Cost drivers (as % of gross to compare across categories fairly)
    ROUND(SUM(product_cost)  / NULLIF(SUM(gross_revenue), 0) * 100, 2)         AS product_cost_pct,
    ROUND(SUM(shipping_cost) / NULLIF(SUM(gross_revenue), 0) * 100, 2)         AS shipping_cost_pct,
    ROUND(SUM(discount_amount) / NULLIF(SUM(gross_revenue), 0) * 100, 2)       AS discount_pct,
    ROUND(SUM(refund_amount) / NULLIF(SUM(gross_revenue), 0) * 100, 2)         AS refund_pct,
 
    -- Return behaviour
    ROUND(AVG(discount_pct), 2)                                                 AS avg_discount_rate,
    ROUND(
        SUM(CASE WHEN returned = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2
    )                                                                           AS return_rate_pct
 
FROM orders
GROUP BY primary_category
ORDER BY profit_margin_pct DESC;
 
 
-- 1b. Top 3 most profitable categories
SELECT
    primary_category,
    ROUND(SUM(profit), 2)                                                       AS total_profit,
    ROUND(SUM(profit) / NULLIF(SUM(net_revenue), 0) * 100, 2)                  AS profit_margin_pct
FROM orders
GROUP BY primary_category
ORDER BY total_profit DESC
LIMIT 3;
 
 
-- 1c. Bottom 3 least profitable categories
SELECT
    primary_category,
    ROUND(SUM(profit), 2)                                                       AS total_profit,
    ROUND(SUM(profit) / NULLIF(SUM(net_revenue), 0) * 100, 2)                  AS profit_margin_pct
FROM orders
GROUP BY primary_category
ORDER BY total_profit ASC
LIMIT 3;
 
 
-- ============================================================
-- Q2. PROFITABILITY ACROSS SALES CHANNELS
-- Which channel has the best/worst profit per order
-- after accounting for platform fees?
-- ============================================================
 
-- 2a. Full channel profitability breakdown
-- NOTE: Website and Mobile App have zero platform fees in this dataset.
-- Only Marketplace (avg $18.97/order) and Social Commerce (avg $9.87/order) incur them.
SELECT
    channel,
    COUNT(*)                                                                    AS total_orders,
    ROUND(SUM(gross_revenue), 2)                                                AS gross_revenue,
    ROUND(SUM(net_revenue), 2)                                                  AS net_revenue,
    ROUND(SUM(gross_revenue) / COUNT(*), 2)                                     AS avg_order_value,
    ROUND(SUM(profit), 2)                                                       AS total_profit,
    ROUND(SUM(profit) / COUNT(*), 2)                                            AS profit_per_order,
    ROUND(SUM(profit) / NULLIF(SUM(net_revenue), 0) * 100, 2)                  AS profit_margin_pct,
 
    -- Platform fee impact (meaningful only for Marketplace and Social Commerce)
    ROUND(SUM(platform_fee) / COUNT(*), 2)                                      AS avg_platform_fee_per_order,
    ROUND(SUM(platform_fee), 2)                                                 AS total_platform_fees,
    ROUND(SUM(profit + platform_fee) / COUNT(*), 2)                             AS profit_per_order_before_platform_fee,
 
    -- Fee drag: how much margin is lost purely to platform fees
    ROUND(
        SUM(platform_fee) * 100.0 / NULLIF(SUM(profit + platform_fee), 0), 2
    )                                                                           AS platform_fee_drag_pct
 
FROM orders
GROUP BY channel
ORDER BY profit_per_order DESC;
 
 
-- 2b. Channel comparison: best vs worst after platform fees
-- Ranks channels by profit per order both before and after fees
-- to isolate the true cost of each platform's fee structure
SELECT
    channel,
    ROUND(SUM(profit + platform_fee) / COUNT(*), 2)                             AS profit_before_fees,
    ROUND(SUM(platform_fee) / COUNT(*), 2)                                      AS avg_fee,
    ROUND(SUM(profit) / COUNT(*), 2)                                            AS profit_after_fees,
    RANK() OVER (ORDER BY SUM(profit) / COUNT(*) DESC)                          AS rank_after_fees
FROM orders
GROUP BY channel
ORDER BY profit_after_fees DESC;
 
 
-- ============================================================
-- Q3. RETURN RATE BY CATEGORY AND CHANNEL
-- Estimate total revenue lost to returns.
-- ============================================================
 
-- NOTE: In this dataset, returned orders have net_revenue = 0 exactly.
-- Revenue lost is measured via refund_amount (more precise than net_revenue),
-- expressed as a % of gross_revenue to avoid division-by-zero on returned orders.
 
-- 3a. Return rate and revenue lost by category
SELECT
    primary_category,
    COUNT(*)                                                                    AS total_orders,
    SUM(CASE WHEN returned = 'Yes' THEN 1 ELSE 0 END)                          AS returned_orders,
    ROUND(
        SUM(CASE WHEN returned = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2
    )                                                                           AS return_rate_pct,
    ROUND(SUM(refund_amount), 2)                                                AS revenue_lost,
    ROUND(SUM(refund_amount) / NULLIF(SUM(gross_revenue), 0) * 100, 2)         AS revenue_lost_pct
FROM orders
GROUP BY primary_category
ORDER BY return_rate_pct DESC;
 
 
-- 3b. Return rate and revenue lost by channel
SELECT
    channel,
    COUNT(*)                                                                    AS total_orders,
    SUM(CASE WHEN returned = 'Yes' THEN 1 ELSE 0 END)                          AS returned_orders,
    ROUND(
        SUM(CASE WHEN returned = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2
    )                                                                           AS return_rate_pct,
    ROUND(SUM(refund_amount), 2)                                                AS revenue_lost,
    ROUND(SUM(refund_amount) / NULLIF(SUM(gross_revenue), 0) * 100, 2)         AS revenue_lost_pct
FROM orders
GROUP BY channel
ORDER BY return_rate_pct DESC;
 
 
-- 3c. Cross-tab: category × channel return rate
SELECT
    primary_category,
    channel,
    COUNT(*)                                                                    AS total_orders,
    SUM(CASE WHEN returned = 'Yes' THEN 1 ELSE 0 END)                          AS returned_orders,
    ROUND(
        SUM(CASE WHEN returned = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2
    )                                                                           AS return_rate_pct,
    ROUND(SUM(refund_amount), 2)                                                AS revenue_lost
FROM orders
GROUP BY primary_category, channel
ORDER BY return_rate_pct DESC;
 
 
-- 3d. Total revenue lost to returns across the full period
SELECT
    ROUND(SUM(refund_amount), 2)                                                AS total_revenue_lost,
    ROUND(SUM(gross_revenue), 2)                                                AS total_gross_revenue,
    ROUND(SUM(refund_amount) / NULLIF(SUM(gross_revenue), 0) * 100, 2)         AS overall_loss_pct,
    SUM(CASE WHEN returned = 'Yes' THEN 1 ELSE 0 END)                          AS total_returned_orders,
    COUNT(*)                                                                    AS total_orders,
    ROUND(
        SUM(CASE WHEN returned = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2
    )                                                                           AS overall_return_rate_pct
FROM orders;
 
 
-- ============================================================
-- Q4. MARKETING SPEND — ROAS BY PLATFORM
-- Which platform delivers the best ROAS?
-- Are any platforms spending without positive return?
-- ============================================================
 
-- 4a. ROAS ranking with spend efficiency gap
-- revenue_vs_spend_gap: positive = platform earns more than its share of spend (efficient)
--                       negative = platform costs more than it earns proportionally (inefficient)
SELECT
    platform,
    ROUND(SUM(spend), 2)                                                        AS total_spend,
    ROUND(SUM(revenue_attributed), 2)                                           AS total_revenue,
    ROUND(SUM(revenue_attributed) / NULLIF(SUM(spend), 0), 2)                  AS roas,
    ROUND(AVG(cpa), 2)                                                          AS avg_cpa,
    ROUND(SUM(conversions), 0)                                                  AS total_conversions,
 
    -- Spend share vs revenue share gap — key efficiency signal
    ROUND(SUM(spend) * 100.0 / SUM(SUM(spend)) OVER (), 2)                     AS spend_share_pct,
    ROUND(SUM(revenue_attributed) * 100.0 / SUM(SUM(revenue_attributed)) OVER (), 2) AS revenue_share_pct,
    ROUND(
        SUM(revenue_attributed) * 100.0 / SUM(SUM(revenue_attributed)) OVER ()
        - SUM(spend) * 100.0 / SUM(SUM(spend)) OVER (), 2
    )                                                                           AS revenue_vs_spend_gap
 
FROM marketing_spend
GROUP BY platform
ORDER BY roas DESC;
 
 
-- 4b. Platforms with negative efficiency (spending more than they earn back)
-- These are the candidates for budget cuts in Q5
SELECT
    platform,
    ROUND(SUM(spend), 2)                                                        AS total_spend,
    ROUND(SUM(revenue_attributed) / NULLIF(SUM(spend), 0), 2)                  AS roas,
    ROUND(
        SUM(revenue_attributed) * 100.0 / SUM(SUM(revenue_attributed)) OVER ()
        - SUM(spend) * 100.0 / SUM(SUM(spend)) OVER (), 2
    )                                                                           AS revenue_vs_spend_gap,
    CASE
        WHEN SUM(revenue_attributed) / NULLIF(SUM(spend), 0) >= 20 THEN 'Efficient — Grow'
        WHEN SUM(revenue_attributed) / NULLIF(SUM(spend), 0) >= 15 THEN 'Acceptable — Hold'
        WHEN SUM(revenue_attributed) / NULLIF(SUM(spend), 0) >= 10 THEN 'Below target — Reduce'
        ELSE 'Underperforming — Cut'
    END                                                                         AS efficiency_label
FROM marketing_spend
GROUP BY platform
ORDER BY roas DESC;
 
 
-- ============================================================
-- Q5. 20% BUDGET CUT RECOMMENDATION
-- Which platforms and months should spend be reduced on?
-- ============================================================
 
-- 5a. Platform-level cut plan
-- Total budget: $503,506 | 20% cut target: $100,701
-- Strategy: apply deepest cuts to lowest-ROAS platforms first
SELECT
    platform,
    ROUND(SUM(spend), 2)                                                        AS total_spend,
    ROUND(SUM(spend) * 100.0 / SUM(SUM(spend)) OVER (), 2)                     AS spend_share_pct,
    ROUND(SUM(revenue_attributed) / NULLIF(SUM(spend), 0), 2)                  AS roas,
    ROUND(AVG(cpa), 2)                                                          AS avg_cpa,
 
    -- Proposed 20% cut amount per platform
    ROUND(SUM(spend) * 0.20, 2)                                                 AS proposed_20pct_cut,
 
    CASE
        WHEN SUM(revenue_attributed) / NULLIF(SUM(spend), 0) >= 20 THEN 'Grow — protect budget'
        WHEN SUM(revenue_attributed) / NULLIF(SUM(spend), 0) >= 15 THEN 'Hold — minor trim only'
        WHEN SUM(revenue_attributed) / NULLIF(SUM(spend), 0) >= 10 THEN 'Reduce — cut 20%'
        ELSE 'Cut — cut aggressively (>20%)'
    END                                                                         AS recommendation
 
FROM marketing_spend
GROUP BY platform
ORDER BY roas ASC;
 
 
-- 5b. Specific month × platform combos to cut first
-- Targets the highest-spend months on the lowest-ROAS platforms.
-- Cutting these specific months concentrates the budget reduction where
-- it causes the least revenue damage.
SELECT
    platform,
    month,
    ROUND(SUM(spend), 2)                                                        AS spend,
    ROUND(SUM(revenue_attributed), 2)                                           AS revenue,
    ROUND(SUM(revenue_attributed) / NULLIF(SUM(spend), 0), 2)                  AS roas,
    ROUND(SUM(spend) * 0.20, 2)                                                 AS proposed_cut
FROM marketing_spend
WHERE platform IN ('Email Marketing', 'Facebook Ads', 'Google Ads')
GROUP BY platform, month
ORDER BY roas ASC, spend DESC
LIMIT 15;
 
 
-- 5c. Validate the 20% cut target is achievable from underperforming platforms alone
-- Confirms that cutting 20% from Email Marketing, Facebook Ads, and Google Ads
-- is sufficient to meet the $100,701 target without touching high-ROAS platforms
SELECT
    SUM(total_spend)                                                            AS spend_in_scope,
    ROUND(SUM(total_spend) * 0.20, 2)                                           AS savings_from_20pct_cut,
    ROUND(503506.14 * 0.20, 2)                                                  AS total_target,
    CASE
        WHEN ROUND(SUM(total_spend) * 0.20, 2) >= ROUND(503506.14 * 0.20, 2)
        THEN 'Target met — cut only from these 3 platforms'
        ELSE 'Target not met — extend cuts to additional platforms'
    END                                                                         AS verdict
FROM (
    SELECT
        platform,
        ROUND(SUM(spend), 2) AS total_spend
    FROM marketing_spend
    WHERE platform IN ('Email Marketing', 'Facebook Ads', 'Google Ads')
    GROUP BY platform
) scoped_platforms;