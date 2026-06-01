CREATE TABLE marketing_spend (
    month DATE,
    platform TEXT,
    spend NUMERIC(10,2),
    impressions INT,
    clicks INT,
    conversions INT,
    revenue_attributed NUMERIC(10,2),
    cpc NUMERIC(10,2),
    cpa NUMERIC(10,2),
    roas NUMERIC(10,2)
);

CREATE TABLE orders (
    order_id TEXT PRIMARY KEY,
    customer_id TEXT,
    order_date DATE,
    channel TEXT,
    payment_method TEXT,
    region TEXT,
    items_ordered INT,
    primary_category TEXT,
    gross_revenue NUMERIC(10,2),
    discount_pct NUMERIC(5,2),
    discount_amount NUMERIC(10,2),
    shipping_cost NUMERIC(10,2),
    product_cost NUMERIC(10,2),
    platform_fee NUMERIC(10,2),
    transaction_fee NUMERIC(10,2),
    returned BOOLEAN,
    refund_amount NUMERIC(10,2),
    net_revenue NUMERIC(10,2),
    total_costs NUMERIC(10,2),
    profit NUMERIC(10,2)
);

CREATE TABLE products (
    product_id TEXT PRIMARY KEY,
    product_name TEXT,
    category TEXT,
    sub_category TEXT,
    unit_cost NUMERIC(10,2),
    selling_price NUMERIC(10,2),
    shipping_cost_per_unit NUMERIC(10,2),
    weight_lbs NUMERIC(10,2),
    supplier TEXT
);


ALTER TABLE marketing_spend
ALTER COLUMN month TYPE TEXT;


SELECT * FROM marketing_spend;
SELECT * FROM orders;
SELECT * FROM products;


-------------------------------------------------------------------------------------------------------------------------------------------

--ADDING COMPOSITE PRIMARY KEY TO (MARKETING_SPEND) TABLE

SELECT month, platform, COUNT(*)
FROM marketing_spend
GROUP BY month, platform
HAVING COUNT(*) > 1;

ALTER TABLE marketing_spend
ADD CONSTRAINT marketing_spend_pk
PRIMARY KEY (month, platform);
--------------------------------------------------------------------------------------------------------------------------------------------

--CHECK FOR DUPLICATE VALUES IN PRIMARY KEY

SELECT order_id, count(*)
FROM orders
group by order_id
having count(*) > 1;

SELECT product_id, count(*)
FROM products
group by product_id
having count(*) > 1;

-----CHECK FOR NULL VALUES

SELECT order_id 
from orders
where order_id ISNULL;

SELECT product_id 
from products
where product_id ISNULL;

SELECT month, platform
from marketing_spend
where (month ,platform) ISNULL;

-----Verify that order-level costs add up correctly (product cost + shipping + fees = total costs).
select * from orders;

SELECT 
    order_id,
    product_cost,
    shipping_cost,
    platform_fee,
    transaction_fee,
    total_costs,
    (product_cost + shipping_cost + platform_fee + transaction_fee) AS calculated_total
FROM orders
WHERE 
    ROUND(product_cost + shipping_cost + platform_fee + transaction_fee, 2) 
    <> ROUND(total_costs, 2);


----CHECKING FOR DATA QUALITY ISSUES

SELECT *
FROM orders
WHERE 
    order_id IS NULL
    OR order_date IS NULL
    OR gross_revenue IS NULL;

SELECT *
FROM orders
WHERE 
    gross_revenue < 0
    OR product_cost < 0
    OR shipping_cost < 0
    OR profit < 0;

SELECT *
FROM orders
WHERE discount_amount > gross_revenue;

SELECT *
FROM orders
WHERE total_costs > net_revenue;

SELECT DISTINCT channel FROM orders;
SELECT DISTINCT payment_method FROM orders;
SELECT DISTINCT region FROM orders;


SELECT *
FROM orders
ORDER BY gross_revenue DESC
LIMIT 10;

------------------------------------------------------------------------------------------------------------------------------------------

--Q1.What is the average profit margin by product category? Which categories are the most and least profitable, and what is driving the difference (product cost, shipping, returns, or discounts)?

----AVERAGE PROFIT MARGIN BY PRODUCT CATEGORY
SELECT
	primary_category,
	sum(net_revenue) as total_revenue,
	sum(total_costs) as total_cost,
	sum(profit) as total_profit,
	concat(round((sum(profit) / sum(net_revenue)) * 100,2), '%') as profit_margin
from orders
group by primary_category
order by profit_margin desc;

-----MOST PROFITABLE BY CATEGORY

SELECT
	primary_category,
	sum(total_costs) as total_cost,
	sum(profit) as total_profit
from orders
GROUP BY primary_category
order by total_profit desc
limit 3;

----LEAST PROFITABLE BY CATEGORY

SELECT 
	primary_category,
	sum(total_costs) as total_cost,
	sum(profit) as total_profit
from orders
GROUP BY primary_category
order by total_profit
limit 3;

------what is driving the difference (product cost, shipping, returns, or discounts)?

select * from orders;

SELECT
	primary_category,
	sum(net_revenue) as revenue,
	sum(total_costs) as total_cost,
	sum(product_cost) as product_cost,
	sum(profit) as total_profit,
	round((sum(profit) / sum(net_revenue)) * 100 ,2) as profit_margin,
	round(avg(shipping_cost),2) as avg_shipping_cost,
	round(avg(discount_pct),2) as avg_discount_pct,
	round(sum(case when returned then 1 else 0 end) * 100.0 / count(*) , 2) as return_rate
from orders
group by primary_category
order by profit_margin desc;

------------------------------------------------------------------------------------------------------------------------------------------

--Q2. How does profitability differ across sales channels (Website, Mobile App, Marketplace, Social Commerce)? Which channel has the best and worst profit per order after accounting for platform fees?

---Profitability across sales channels

SELECT
	channel,
	sum(profit) as total_profit,
	round((sum(profit) / NULLIF(sum(net_revenue),0)) *100 ,2) as profit_margin
from orders
group by channel
order by profit_margin desc;

SELECT 
    channel,
    COUNT(*) AS total_orders,
    SUM(net_revenue) AS total_revenue,
    SUM(profit) AS total_profit,
    ROUND(SUM(profit) / COUNT(*), 2) AS profit_per_order
FROM orders
GROUP BY channel
ORDER BY profit_per_order DESC;

---Which channel has the best and worst profit per order after accounting for platform fees?

select * from orders;

Select
	channel,
	round(avg(platform_fee) ,2) as avg_platform_fee,
	round(sum(profit) / count(*) ,2) as profit_per_order,
	round(sum(profit + platform_fee) / count(*) ,2) as profit_per_order_before_platform_fee
from orders
group by channel
order by profit_per_order desc;


------Percentage impact of platform_fees

SELECT 
    channel,
    ROUND(AVG(platform_fee), 2) AS avg_fee,
    ROUND(SUM(profit) / COUNT(*), 2) AS profit_after_fees,
    ROUND(SUM(profit + platform_fee) / COUNT(*), 2) AS profit_before_fees,
    ROUND(
        SUM(platform_fee) * 100.0 / NULLIF(SUM(profit + platform_fee), 0),
    2) AS fee_impact_pct
FROM orders
GROUP BY channel
ORDER BY fee_impact_pct DESC;

-----------------------------------------------------------------------------------------------------------------------------------------------

--Q3. What is the return rate by category and channel? Estimate how much total revenue was lost to returns over the analysis period.

---category & Channel wise return_rate
select * from orders;

SELECT 
	primary_category,
	channel,
	count(*) as total_orders,
	sum(case when returned then 1 else 0 end) as returned_orders,
	round(SUM(case when returned then 1 else 0 end) * 100.0 / count(*) , 2) as return_rate
from orders
group by primary_category, channel
order by return_rate desc;

----category wise return_rate

SELECT
	primary_category,
	count(*) as total_orders,
	sum(case when returned then 1 else 0 end) as returned_orders,
	round(sum(case when returned then 1 else 0 end) * 100.0 / count(*) ,2) as return_rate
from orders
group by primary_category
order by return_rate desc;

-----Channel wise return_rate

SELECT
	channel,
	count(*) as total_orders,
	sum(case when returned then 1 else 0 end) as returned_orders,
	round(sum(case when returned then 1 else 0 end) * 100.0 / count(*) ,2) as return_rate
from orders
group by channel
order by return_rate desc;

---Estimate how much total revenue was lost to returns over the analysis period.
select * from orders;

SELECT
	primary_category,
	channel,
	count(*) as total_orders,
	sum(case when returned then 1 else 0 end) as returned_orders,
	sum(refund_amount) as revenue_lost,
	round(sum(refund_amount) * 100.0 / NULLIF(sum(net_revenue),0) ,2) as revenue_loss_pct
FROM orders
group by primary_category, channel
order by revenue_loss_pct desc;

--------------------------------------------------------------------------------------------------------------------------------------------

--Q4. Analyze the marketing spend data: Which advertising platform delivers the best ROAS (Return on Ad Spend)? Are there any platforms where the company is spending money but not getting a positive return?

----Which advertising platform delivers the best ROAS (Return on Ad Spend)?

SELECT * FROM marketing_spend;

select
	platform,
	sum(spend) as total_spend,
	sum(revenue_attributed) as total_revenue,
	round(sum(revenue_attributed) / nullif(sum(spend),0) ,2) as roas
from marketing_spend
group by platform
order by roas desc;

----Are there any platforms where the company is spending money but not getting a positive return?

SELECT 
    platform,
    ROUND(SUM(spend) * 100.0 / SUM(SUM(spend)) OVER (), 2) AS spend_pct,
    ROUND(SUM(revenue_attributed) * 100.0 / SUM(SUM(revenue_attributed)) OVER (), 2) AS revenue_pct
FROM marketing_spend
GROUP BY platform
order by spend_pct;

------------------------------------------------------------------------------------------------------------------------------------------
--Q5. If the CEO asked you to cut 20% of the marketing budget, which platforms and months would you recommend reducing spend on? Support your recommendation with data.

SELECT 
    platform,
    month,
    SUM(spend) AS spend,
    round(SUM(revenue_attributed) / NULLIF(SUM(spend), 0) ,2) AS roas
FROM marketing_spend
GROUP BY platform, month
ORDER BY roas ASC, spend DESC;

SELECT
	platform,
	sum(revenue_attributed) as total_revenue,
	sum(spend) as total_spend,
	round(SUM(revenue_attributed) / NULLIF(SUM(spend), 0) ,2) AS roas
from marketing_spend
group by platform
order by roas;
	


SELECT
    platform,
    ROUND(SUM(revenue_attributed) / NULLIF(SUM(spend), 0), 2)  AS revenue_per_dollar,
    ROUND(AVG(cpa), 2) AS avg_cpa,
    ROUND(SUM(spend), 2) AS total_spend,
    CASE
        WHEN AVG(roas) >= 20 THEN 'Grow'
        WHEN AVG(roas) >= 15 THEN 'Hold'
        WHEN AVG(roas) >= 10 THEN 'Reduce'
        ELSE 'Cut'
    END  AS recommendation
FROM marketing_spend
GROUP BY platform
ORDER BY revenue_per_dollar DESC;