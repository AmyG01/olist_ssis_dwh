USE olist_dwh;

-- TEST 1 (Bronze): row count in Bronze = record count of the CSV file
SELECT t.table_name, t.expected_rows, t.actual_rows
FROM (
    SELECT 'bronze.olist_customers' AS table_name, 99441 AS expected_rows, (SELECT COUNT(*) FROM bronze.olist_customers) AS actual_rows
    UNION ALL SELECT 'bronze.olist_orders',                      99441,   (SELECT COUNT(*) FROM bronze.olist_orders)
    UNION ALL SELECT 'bronze.olist_order_items',                 112650,  (SELECT COUNT(*) FROM bronze.olist_order_items)
    UNION ALL SELECT 'bronze.olist_order_payments',              103886,  (SELECT COUNT(*) FROM bronze.olist_order_payments)
    UNION ALL SELECT 'bronze.olist_order_reviews',               99224,   (SELECT COUNT(*) FROM bronze.olist_order_reviews)
    UNION ALL SELECT 'bronze.olist_products',                    32951,   (SELECT COUNT(*) FROM bronze.olist_products)
    UNION ALL SELECT 'bronze.olist_sellers',                     3095,    (SELECT COUNT(*) FROM bronze.olist_sellers)
    UNION ALL SELECT 'bronze.olist_geolocation',                 1000163, (SELECT COUNT(*) FROM bronze.olist_geolocation)
    UNION ALL SELECT 'bronze.product_category_name_translation', 71,      (SELECT COUNT(*) FROM bronze.product_category_name_translation)
) t
WHERE t.expected_rows <> t.actual_rows;

-- TEST 2 (Silver): no duplicate review_id
SELECT review_id, COUNT(*) AS copies
FROM silver.order_reviews
GROUP BY review_id
HAVING COUNT(*) > 1;

-- TEST 3 (Silver): exactly one row per zip_code_prefix in geolocation
SELECT zip_code_prefix, COUNT(*) AS copies
FROM silver.geolocation
GROUP BY zip_code_prefix
HAVING COUNT(*) > 1;

-- TEST 4 (Gold): no NULL business keys in any dimension
SELECT 'dim_date' AS dim_name FROM gold.dim_date WHERE full_date IS NULL
UNION ALL SELECT 'dim_geography'    FROM gold.dim_geography    WHERE zip_code_prefix IS NULL
UNION ALL SELECT 'dim_customer'     FROM gold.dim_customer     WHERE customer_unique_id IS NULL
UNION ALL SELECT 'dim_product'      FROM gold.dim_product      WHERE product_id IS NULL
UNION ALL SELECT 'dim_seller'       FROM gold.dim_seller       WHERE seller_id IS NULL
UNION ALL SELECT 'dim_order_status' FROM gold.dim_order_status WHERE order_status IS NULL
UNION ALL SELECT 'dim_payment_type' FROM gold.dim_payment_type WHERE payment_type IS NULL;

-- TEST 5 (Gold): every surrogate key is unique per dimension
SELECT 'dim_date' AS dim_name, date_key AS key_value FROM gold.dim_date GROUP BY date_key HAVING COUNT(*) > 1
UNION ALL SELECT 'dim_geography',    geography_key    FROM gold.dim_geography    GROUP BY geography_key    HAVING COUNT(*) > 1
UNION ALL SELECT 'dim_customer',     customer_key     FROM gold.dim_customer     GROUP BY customer_key     HAVING COUNT(*) > 1
UNION ALL SELECT 'dim_product',      product_key      FROM gold.dim_product      GROUP BY product_key      HAVING COUNT(*) > 1
UNION ALL SELECT 'dim_seller',       seller_key       FROM gold.dim_seller       GROUP BY seller_key       HAVING COUNT(*) > 1
UNION ALL SELECT 'dim_order_status', order_status_key FROM gold.dim_order_status GROUP BY order_status_key HAVING COUNT(*) > 1
UNION ALL SELECT 'dim_payment_type', payment_type_key FROM gold.dim_payment_type GROUP BY payment_type_key HAVING COUNT(*) > 1;

-- TEST 6 (Gold): no orphan foreign keys in the facts
SELECT 'fact_sales.date_key' AS fk_name, f.date_key AS orphan_value FROM gold.fact_sales f WHERE NOT EXISTS (SELECT 1 FROM gold.dim_date d WHERE d.date_key = f.date_key)
UNION ALL SELECT 'fact_sales.customer_key',     f.customer_key     FROM gold.fact_sales f WHERE NOT EXISTS (SELECT 1 FROM gold.dim_customer d WHERE d.customer_key = f.customer_key)
UNION ALL SELECT 'fact_sales.product_key',      f.product_key      FROM gold.fact_sales f WHERE NOT EXISTS (SELECT 1 FROM gold.dim_product d WHERE d.product_key = f.product_key)
UNION ALL SELECT 'fact_sales.seller_key',       f.seller_key       FROM gold.fact_sales f WHERE NOT EXISTS (SELECT 1 FROM gold.dim_seller d WHERE d.seller_key = f.seller_key)
UNION ALL SELECT 'fact_sales.order_status_key', f.order_status_key FROM gold.fact_sales f WHERE NOT EXISTS (SELECT 1 FROM gold.dim_order_status d WHERE d.order_status_key = f.order_status_key)
UNION ALL SELECT 'fact_payments.date_key',      f.date_key         FROM gold.fact_payments f WHERE NOT EXISTS (SELECT 1 FROM gold.dim_date d WHERE d.date_key = f.date_key)
UNION ALL SELECT 'fact_payments.customer_key',  f.customer_key     FROM gold.fact_payments f WHERE NOT EXISTS (SELECT 1 FROM gold.dim_customer d WHERE d.customer_key = f.customer_key)
UNION ALL SELECT 'fact_payments.payment_type_key', f.payment_type_key FROM gold.fact_payments f WHERE NOT EXISTS (SELECT 1 FROM gold.dim_payment_type d WHERE d.payment_type_key = f.payment_type_key)
UNION ALL SELECT 'fact_reviews.date_key',       f.date_key         FROM gold.fact_reviews f WHERE NOT EXISTS (SELECT 1 FROM gold.dim_date d WHERE d.date_key = f.date_key)
UNION ALL SELECT 'fact_reviews.customer_key',   f.customer_key     FROM gold.fact_reviews f WHERE NOT EXISTS (SELECT 1 FROM gold.dim_customer d WHERE d.customer_key = f.customer_key);

-- TEST 7 (Gold): SUM(fact_sales.price) = SUM(silver.order_items.price)
SELECT g.total AS gold_total, s.total AS silver_total
FROM (SELECT SUM(price) AS total FROM gold.fact_sales) g
CROSS JOIN (SELECT SUM(price) AS total FROM silver.order_items) s
WHERE ISNULL(g.total, 0) <> ISNULL(s.total, 0);

-- TEST 8 (Gold): SUM(fact_payments.payment_value) = SUM(silver.order_payments.payment_value)
SELECT g.total AS gold_total, s.total AS silver_total
FROM (SELECT SUM(payment_value) AS total FROM gold.fact_payments) g
CROSS JOIN (SELECT SUM(payment_value) AS total FROM silver.order_payments) s
WHERE ISNULL(g.total, 0) <> ISNULL(s.total, 0);

-- TEST 9 (Gold): only one is_current = 1 row per customer_unique_id
SELECT customer_unique_id, COUNT(*) AS current_rows
FROM gold.dim_customer
WHERE is_current = 1
GROUP BY customer_unique_id
HAVING COUNT(*) > 1;

-- TEST 10 (Silver): no negative prices or freight values
SELECT order_id, order_item_id, price, freight_value
FROM silver.order_items
WHERE price < 0 OR freight_value < 0;