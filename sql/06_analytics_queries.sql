SELECT 'fact_sales' AS tbl, COUNT(*) AS n FROM gold.fact_sales
UNION ALL SELECT 'fact_payments', COUNT(*) FROM gold.fact_payments
UNION ALL SELECT 'fact_reviews',  COUNT(*) FROM gold.fact_reviews
UNION ALL SELECT 'dim_customer',  COUNT(*) FROM gold.dim_customer;

SELECT TOP 3 * FROM etl.batch_log ORDER BY batch_id DESC;USE olist_dwh;

-- Q1: Monthly revenue and order count trend (2017-2018)
SELECT d.year, d.month, d.month_name,
       SUM(f.price)                 AS revenue,
       COUNT(DISTINCT f.order_id)   AS order_count
FROM gold.fact_sales f
JOIN gold.dim_date d ON d.date_key = f.date_key
WHERE d.year IN (2017, 2018)
GROUP BY d.year, d.month, d.month_name
ORDER BY d.year, d.month;

-- Q2: Top 10 product categories (English) by revenue
SELECT TOP 10 p.category_en,
       SUM(f.price) AS revenue
FROM gold.fact_sales f
JOIN gold.dim_product p ON p.product_key = f.product_key
GROUP BY p.category_en
ORDER BY revenue DESC;

-- Q3: Top 10 sellers by revenue and their average review score
-- Reviews belong to the order, so we use the distinct (order_id, seller_key) pairs.
WITH seller_orders AS (
    SELECT DISTINCT order_id, seller_key FROM gold.fact_sales
),
seller_revenue AS (
    SELECT seller_key, SUM(price) AS revenue FROM gold.fact_sales GROUP BY seller_key
),
seller_score AS (
    SELECT so.seller_key, AVG(CAST(r.review_score AS DECIMAL(4,2))) AS avg_review_score
    FROM seller_orders so
    JOIN gold.fact_reviews r ON r.order_id = so.order_id
    GROUP BY so.seller_key
)
SELECT TOP 10 s.seller_id, s.city, s.state, rev.revenue, sc.avg_review_score
FROM seller_revenue rev
JOIN gold.dim_seller s ON s.seller_key = rev.seller_key
LEFT JOIN seller_score sc ON sc.seller_key = rev.seller_key
ORDER BY rev.revenue DESC;

-- Q4: % of orders delivered late, by customer state
-- One row per order first (all items of an order share the same delivery date).
WITH delivered_orders AS (
    SELECT order_id, customer_key, MAX(CAST(is_late AS INT)) AS is_late
    FROM gold.fact_sales
    WHERE is_late IS NOT NULL
    GROUP BY order_id, customer_key
)
SELECT c.state,
       COUNT(*)       AS delivered_orders,
       SUM(o.is_late) AS late_orders,
       CAST(100.0 * SUM(o.is_late) / COUNT(*) AS DECIMAL(5,2)) AS pct_late
FROM delivered_orders o
JOIN gold.dim_customer c ON c.customer_key = o.customer_key
GROUP BY c.state
ORDER BY pct_late DESC;

-- Q5: Average delivery days by seller state -> customer state (top 10 routes by volume)
WITH shipments AS (
    SELECT order_id, seller_key, customer_key, MAX(days_to_deliver) AS days_to_deliver
    FROM gold.fact_sales
    WHERE days_to_deliver IS NOT NULL
    GROUP BY order_id, seller_key, customer_key
)
SELECT TOP 10 s.state AS seller_state,
       c.state AS customer_state,
       COUNT(*) AS shipments,
       CAST(AVG(CAST(sh.days_to_deliver AS DECIMAL(10,2))) AS DECIMAL(6,2)) AS avg_delivery_days
FROM shipments sh
JOIN gold.dim_seller   s ON s.seller_key   = sh.seller_key
JOIN gold.dim_customer c ON c.customer_key = sh.customer_key
GROUP BY s.state, c.state
ORDER BY shipments DESC;

-- Q6: Payment type mix by revenue and average installments
SELECT pt.payment_type,
       SUM(f.payment_value) AS revenue,
       CAST(100.0 * SUM(f.payment_value) / SUM(SUM(f.payment_value)) OVER () AS DECIMAL(5,2)) AS pct_of_revenue,
       CAST(AVG(CAST(f.payment_installments AS DECIMAL(10,2))) AS DECIMAL(5,2)) AS avg_installments
FROM gold.fact_payments f
JOIN gold.dim_payment_type pt ON pt.payment_type_key = f.payment_type_key
GROUP BY pt.payment_type
ORDER BY revenue DESC;

-- Q7: Repeat customer rate (customer_unique_id with more than 1 order)
WITH customer_orders AS (
    SELECT c.customer_unique_id, COUNT(DISTINCT f.order_id) AS order_count
    FROM gold.fact_sales f
    JOIN gold.dim_customer c ON c.customer_key = f.customer_key
    WHERE c.customer_key <> -1
    GROUP BY c.customer_unique_id
)
SELECT COUNT(*) AS total_customers,
       SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) AS repeat_customers,
       CAST(100.0 * SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS repeat_rate_pct
FROM customer_orders;

-- Q8: Does late delivery hurt review scores? (average score, late vs on time)
WITH delivered_orders AS (
    SELECT order_id, MAX(CAST(is_late AS INT)) AS is_late
    FROM gold.fact_sales
    WHERE is_late IS NOT NULL
    GROUP BY order_id
)
SELECT CASE WHEN o.is_late = 1 THEN 'late' ELSE 'on_time' END AS delivery,
       COUNT(*) AS reviews,
       CAST(AVG(CAST(r.review_score AS DECIMAL(4,2))) AS DECIMAL(4,2)) AS avg_review_score
FROM delivered_orders o
JOIN gold.fact_reviews r ON r.order_id = o.order_id
GROUP BY o.is_late
ORDER BY delivery;