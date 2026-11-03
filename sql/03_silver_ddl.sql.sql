USE olist_dwh;

EXEC('CREATE OR ALTER FUNCTION silver.fn_proper_case (@s NVARCHAR(255))
RETURNS NVARCHAR(255)
AS
BEGIN
    DECLARE @r NVARCHAR(255) = LOWER(LTRIM(RTRIM(@s)));
    DECLARE @i INT = 1;
    IF @r IS NULL OR @r = '''' RETURN @r;
    SET @r = STUFF(@r, 1, 1, UPPER(LEFT(@r, 1)));
    WHILE @i < LEN(@r)
    BEGIN
        IF SUBSTRING(@r, @i, 1) = '' ''
            SET @r = STUFF(@r, @i + 1, 1, UPPER(SUBSTRING(@r, @i + 1, 1)));
        SET @i = @i + 1;
    END
    RETURN @r;
END');

IF OBJECT_ID('silver.category_translation', 'U') IS NULL
CREATE TABLE silver.category_translation (
    category_pt NVARCHAR(255) NOT NULL CONSTRAINT pk_silver_category_translation PRIMARY KEY,
    category_en NVARCHAR(255) NOT NULL,
    dwh_load_ts DATETIME2 NOT NULL CONSTRAINT df_silver_category_translation_load_ts DEFAULT SYSDATETIME()
);

IF OBJECT_ID('silver.customers', 'U') IS NULL
CREATE TABLE silver.customers (
    customer_id        NVARCHAR(50) NOT NULL CONSTRAINT pk_silver_customers PRIMARY KEY,
    customer_unique_id NVARCHAR(50) NOT NULL,
    zip_code_prefix    CHAR(5)      NULL,
    city               NVARCHAR(100) NULL,
    state              CHAR(2)      NULL,
    dwh_load_ts DATETIME2 NOT NULL CONSTRAINT df_silver_customers_load_ts DEFAULT SYSDATETIME()
);

IF OBJECT_ID('silver.sellers', 'U') IS NULL
CREATE TABLE silver.sellers (
    seller_id       NVARCHAR(50) NOT NULL CONSTRAINT pk_silver_sellers PRIMARY KEY,
    zip_code_prefix CHAR(5)      NULL,
    city            NVARCHAR(100) NULL,
    state           CHAR(2)      NULL,
    dwh_load_ts DATETIME2 NOT NULL CONSTRAINT df_silver_sellers_load_ts DEFAULT SYSDATETIME()
);

IF OBJECT_ID('silver.geolocation', 'U') IS NULL
CREATE TABLE silver.geolocation (
    zip_code_prefix CHAR(5) NOT NULL CONSTRAINT pk_silver_geolocation PRIMARY KEY,
    latitude        DECIMAL(9,6) NULL,
    longitude       DECIMAL(9,6) NULL,
    city            NVARCHAR(100) NULL,
    state           CHAR(2)      NULL,
    dwh_load_ts DATETIME2 NOT NULL CONSTRAINT df_silver_geolocation_load_ts DEFAULT SYSDATETIME()
);

IF OBJECT_ID('silver.products', 'U') IS NULL
CREATE TABLE silver.products (
    product_id                 NVARCHAR(50) NOT NULL CONSTRAINT pk_silver_products PRIMARY KEY,
    category_pt                NVARCHAR(255) NOT NULL,
    category_en                NVARCHAR(255) NOT NULL,
    product_name_length        INT NULL,
    product_description_length INT NULL,
    photos_qty                 INT NULL,
    weight_g                   INT NULL,
    length_cm                  INT NULL,
    height_cm                  INT NULL,
    width_cm                   INT NULL,
    dwh_load_ts DATETIME2 NOT NULL CONSTRAINT df_silver_products_load_ts DEFAULT SYSDATETIME()
);

IF OBJECT_ID('silver.orders', 'U') IS NULL
CREATE TABLE silver.orders (
    order_id              NVARCHAR(50) NOT NULL CONSTRAINT pk_silver_orders PRIMARY KEY,
    customer_id           NVARCHAR(50) NOT NULL,
    order_status          NVARCHAR(30) NOT NULL,
    is_delivered          BIT NOT NULL,
    order_purchase_ts     DATETIME2 NULL,
    order_approved_ts     DATETIME2 NULL,
    delivered_carrier_ts  DATETIME2 NULL,
    delivered_customer_ts DATETIME2 NULL,
    estimated_delivery_ts DATETIME2 NULL,
    dwh_load_ts DATETIME2 NOT NULL CONSTRAINT df_silver_orders_load_ts DEFAULT SYSDATETIME()
);

IF OBJECT_ID('silver.order_items', 'U') IS NULL
CREATE TABLE silver.order_items (
    order_id          NVARCHAR(50) NOT NULL,
    order_item_id     INT NOT NULL,
    product_id        NVARCHAR(50) NOT NULL,
    seller_id         NVARCHAR(50) NOT NULL,
    shipping_limit_ts DATETIME2 NULL,
    price             DECIMAL(10,2) NOT NULL,
    freight_value     DECIMAL(10,2) NOT NULL,
    total_item_value  DECIMAL(10,2) NOT NULL,
    dwh_load_ts DATETIME2 NOT NULL CONSTRAINT df_silver_order_items_load_ts DEFAULT SYSDATETIME(),
    CONSTRAINT pk_silver_order_items PRIMARY KEY (order_id, order_item_id)
);

IF OBJECT_ID('silver.order_payments', 'U') IS NULL
CREATE TABLE silver.order_payments (
    order_id             NVARCHAR(50) NOT NULL,
    payment_sequential   INT NOT NULL,
    payment_type         NVARCHAR(30) NOT NULL,
    payment_installments INT NULL,
    payment_value        DECIMAL(10,2) NOT NULL,
    dwh_load_ts DATETIME2 NOT NULL CONSTRAINT df_silver_order_payments_load_ts DEFAULT SYSDATETIME(),
    CONSTRAINT pk_silver_order_payments PRIMARY KEY (order_id, payment_sequential)
);

IF OBJECT_ID('silver.order_reviews', 'U') IS NULL
CREATE TABLE silver.order_reviews (
    review_id       NVARCHAR(50) NOT NULL CONSTRAINT pk_silver_order_reviews PRIMARY KEY,
    order_id        NVARCHAR(50) NOT NULL,
    review_score    TINYINT NOT NULL,
    comment_title   NVARCHAR(MAX) NULL,
    comment_message NVARCHAR(MAX) NULL,
    review_creation_ts DATETIME2 NULL,
    review_answer_ts   DATETIME2 NULL,
    dwh_load_ts DATETIME2 NOT NULL CONSTRAINT df_silver_order_reviews_load_ts DEFAULT SYSDATETIME()
);