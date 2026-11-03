USE olist_dwh;

-- ============ DIMENSIONS ============

IF OBJECT_ID('gold.dim_date', 'U') IS NULL
CREATE TABLE gold.dim_date (
    date_key    INT NOT NULL CONSTRAINT pk_dim_date PRIMARY KEY,   -- 20170131
    full_date   DATE NOT NULL,
    year        INT NOT NULL,
    quarter     INT NOT NULL,
    month       INT NOT NULL,
    month_name  NVARCHAR(20) NOT NULL,
    day_of_week INT NOT NULL,                                       -- 1 = Monday ... 7 = Sunday
    day_name    NVARCHAR(20) NOT NULL,
    is_weekend  BIT NOT NULL
);

IF OBJECT_ID('gold.dim_geography', 'U') IS NULL
CREATE TABLE gold.dim_geography (
    geography_key   INT IDENTITY(1,1) NOT NULL CONSTRAINT pk_dim_geography PRIMARY KEY,
    zip_code_prefix CHAR(5) NOT NULL CONSTRAINT uq_dim_geography_zip UNIQUE,
    city            NVARCHAR(100) NULL,
    state           CHAR(2) NULL,
    latitude        DECIMAL(9,6) NULL,
    longitude       DECIMAL(9,6) NULL
);

IF OBJECT_ID('gold.dim_customer', 'U') IS NULL
CREATE TABLE gold.dim_customer (
    customer_key       INT IDENTITY(1,1) NOT NULL CONSTRAINT pk_dim_customer PRIMARY KEY,
    customer_unique_id NVARCHAR(50) NOT NULL,
    geography_key      INT NOT NULL CONSTRAINT fk_dim_customer_dim_geography REFERENCES gold.dim_geography (geography_key),
    city               NVARCHAR(100) NULL,
    state              CHAR(2) NULL,
    valid_from         DATE NOT NULL,
    valid_to           DATE NOT NULL,
    is_current         BIT NOT NULL,
    CONSTRAINT uq_dim_customer_version UNIQUE (customer_unique_id, valid_from)
);

IF OBJECT_ID('gold.dim_product', 'U') IS NULL
CREATE TABLE gold.dim_product (
    product_key INT IDENTITY(1,1) NOT NULL CONSTRAINT pk_dim_product PRIMARY KEY,
    product_id  NVARCHAR(50) NOT NULL CONSTRAINT uq_dim_product_id UNIQUE,
    category_pt NVARCHAR(255) NULL,
    category_en NVARCHAR(255) NULL,
    weight_g    INT NULL,
    photos_qty  INT NULL
);

IF OBJECT_ID('gold.dim_seller', 'U') IS NULL
CREATE TABLE gold.dim_seller (
    seller_key    INT IDENTITY(1,1) NOT NULL CONSTRAINT pk_dim_seller PRIMARY KEY,
    seller_id     NVARCHAR(50) NOT NULL CONSTRAINT uq_dim_seller_id UNIQUE,
    geography_key INT NOT NULL CONSTRAINT fk_dim_seller_dim_geography REFERENCES gold.dim_geography (geography_key),
    city          NVARCHAR(100) NULL,
    state         CHAR(2) NULL
);

IF OBJECT_ID('gold.dim_order_status', 'U') IS NULL
CREATE TABLE gold.dim_order_status (
    order_status_key INT IDENTITY(1,1) NOT NULL CONSTRAINT pk_dim_order_status PRIMARY KEY,
    order_status     NVARCHAR(30) NOT NULL CONSTRAINT uq_dim_order_status UNIQUE,
    is_completed     BIT NOT NULL
);

IF OBJECT_ID('gold.dim_payment_type', 'U') IS NULL
CREATE TABLE gold.dim_payment_type (
    payment_type_key INT IDENTITY(1,1) NOT NULL CONSTRAINT pk_dim_payment_type PRIMARY KEY,
    payment_type     NVARCHAR(30) NOT NULL CONSTRAINT uq_dim_payment_type UNIQUE
);

-- ============ FACTS ============

IF OBJECT_ID('gold.fact_sales', 'U') IS NULL
CREATE TABLE gold.fact_sales (          -- grain: one row per order item
    sales_key           BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT pk_fact_sales PRIMARY KEY,
    order_id            NVARCHAR(50) NOT NULL,
    order_item_id       INT NOT NULL,
    date_key            INT NOT NULL CONSTRAINT fk_fact_sales_dim_date REFERENCES gold.dim_date (date_key),
    customer_key        INT NOT NULL CONSTRAINT fk_fact_sales_dim_customer REFERENCES gold.dim_customer (customer_key),
    product_key         INT NOT NULL CONSTRAINT fk_fact_sales_dim_product REFERENCES gold.dim_product (product_key),
    seller_key          INT NOT NULL CONSTRAINT fk_fact_sales_dim_seller REFERENCES gold.dim_seller (seller_key),
    order_status_key    INT NOT NULL CONSTRAINT fk_fact_sales_dim_order_status REFERENCES gold.dim_order_status (order_status_key),
    price               DECIMAL(10,2) NOT NULL,
    freight_value       DECIMAL(10,2) NOT NULL,
    total_item_value    DECIMAL(10,2) NOT NULL,
    days_to_deliver     INT NULL,       -- NULL when not delivered
    delivery_delay_days INT NULL,       -- positive = late, NULL when not delivered
    is_late             BIT NULL        -- NULL when not delivered
);

IF OBJECT_ID('gold.fact_payments', 'U') IS NULL
CREATE TABLE gold.fact_payments (       -- grain: one row per payment line per order
    payment_key          BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT pk_fact_payments PRIMARY KEY,
    order_id             NVARCHAR(50) NOT NULL,
    payment_sequential   INT NOT NULL,
    date_key             INT NOT NULL CONSTRAINT fk_fact_payments_dim_date REFERENCES gold.dim_date (date_key),
    customer_key         INT NOT NULL CONSTRAINT fk_fact_payments_dim_customer REFERENCES gold.dim_customer (customer_key),
    payment_type_key     INT NOT NULL CONSTRAINT fk_fact_payments_dim_payment_type REFERENCES gold.dim_payment_type (payment_type_key),
    payment_installments INT NULL,
    payment_value        DECIMAL(10,2) NOT NULL
);

IF OBJECT_ID('gold.fact_reviews', 'U') IS NULL
CREATE TABLE gold.fact_reviews (        -- grain: one row per review
    review_key   BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT pk_fact_reviews PRIMARY KEY,
    review_id    NVARCHAR(50) NOT NULL,
    order_id     NVARCHAR(50) NOT NULL,
    date_key     INT NOT NULL CONSTRAINT fk_fact_reviews_dim_date REFERENCES gold.dim_date (date_key),
    customer_key INT NOT NULL CONSTRAINT fk_fact_reviews_dim_customer REFERENCES gold.dim_customer (customer_key),
    review_score TINYINT NOT NULL
);

-- ============ UNKNOWN (-1) ROWS, inserted only if missing ============

IF NOT EXISTS (SELECT 1 FROM gold.dim_date WHERE date_key = -1)
    INSERT INTO gold.dim_date (date_key, full_date, year, quarter, month, month_name, day_of_week, day_name, is_weekend)
    VALUES (-1, '1900-01-01', 1900, 1, 1, 'Unknown', 0, 'Unknown', 0);

IF NOT EXISTS (SELECT 1 FROM gold.dim_geography WHERE geography_key = -1)
BEGIN
    SET IDENTITY_INSERT gold.dim_geography ON;
    INSERT INTO gold.dim_geography (geography_key, zip_code_prefix, city, state, latitude, longitude)
    VALUES (-1, '-1', 'Unknown', 'XX', NULL, NULL);
    SET IDENTITY_INSERT gold.dim_geography OFF;
END

IF NOT EXISTS (SELECT 1 FROM gold.dim_customer WHERE customer_key = -1)
BEGIN
    SET IDENTITY_INSERT gold.dim_customer ON;
    INSERT INTO gold.dim_customer (customer_key, customer_unique_id, geography_key, city, state, valid_from, valid_to, is_current)
    VALUES (-1, 'unknown', -1, 'Unknown', 'XX', '1900-01-01', '9999-12-31', 1);
    SET IDENTITY_INSERT gold.dim_customer OFF;
END

IF NOT EXISTS (SELECT 1 FROM gold.dim_product WHERE product_key = -1)
BEGIN
    SET IDENTITY_INSERT gold.dim_product ON;
    INSERT INTO gold.dim_product (product_key, product_id, category_pt, category_en, weight_g, photos_qty)
    VALUES (-1, 'unknown', 'Unknown', 'Unknown', NULL, NULL);
    SET IDENTITY_INSERT gold.dim_product OFF;
END

IF NOT EXISTS (SELECT 1 FROM gold.dim_seller WHERE seller_key = -1)
BEGIN
    SET IDENTITY_INSERT gold.dim_seller ON;
    INSERT INTO gold.dim_seller (seller_key, seller_id, geography_key, city, state)
    VALUES (-1, 'unknown', -1, 'Unknown', 'XX');
    SET IDENTITY_INSERT gold.dim_seller OFF;
END

IF NOT EXISTS (SELECT 1 FROM gold.dim_order_status WHERE order_status_key = -1)
BEGIN
    SET IDENTITY_INSERT gold.dim_order_status ON;
    INSERT INTO gold.dim_order_status (order_status_key, order_status, is_completed)
    VALUES (-1, 'Unknown', 0);
    SET IDENTITY_INSERT gold.dim_order_status OFF;
END

IF NOT EXISTS (SELECT 1 FROM gold.dim_payment_type WHERE payment_type_key = -1)
BEGIN
    SET IDENTITY_INSERT gold.dim_payment_type ON;
    INSERT INTO gold.dim_payment_type (payment_type_key, payment_type)
    VALUES (-1, 'Unknown');
    SET IDENTITY_INSERT gold.dim_payment_type OFF;
END

-- ============ FILL dim_date (2016-01-01 to 2019-12-31), only missing dates ============

;WITH d AS (
    SELECT CAST('2016-01-01' AS DATE) AS full_date
    UNION ALL
    SELECT DATEADD(DAY, 1, full_date) FROM d WHERE full_date < '2019-12-31'
)
INSERT INTO gold.dim_date (date_key, full_date, year, quarter, month, month_name, day_of_week, day_name, is_weekend)
SELECT CONVERT(INT, CONVERT(CHAR(8), d.full_date, 112)),
       d.full_date,
       YEAR(d.full_date),
       DATEPART(QUARTER, d.full_date),
       MONTH(d.full_date),
       DATENAME(MONTH, d.full_date),
       x.dow,
       CHOOSE(x.dow, 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'),
       CASE WHEN x.dow >= 6 THEN 1 ELSE 0 END
FROM d
CROSS APPLY (SELECT (DATEDIFF(DAY, '19000101', d.full_date) % 7) + 1 AS dow) x   -- 1900-01-01 was a Monday
WHERE NOT EXISTS (SELECT 1 FROM gold.dim_date t
                  WHERE t.date_key = CONVERT(INT, CONVERT(CHAR(8), d.full_date, 112)))
OPTION (MAXRECURSION 2000);