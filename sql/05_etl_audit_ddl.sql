USE olist_dwh;

IF OBJECT_ID('etl.batch_log', 'U') IS NULL
CREATE TABLE etl.batch_log (
    batch_id INT IDENTITY(1,1) NOT NULL CONSTRAINT pk_batch_log PRIMARY KEY,
    start_ts DATETIME2 NOT NULL CONSTRAINT df_batch_log_start_ts DEFAULT SYSDATETIME(),
    end_ts   DATETIME2 NULL,
    status   NVARCHAR(20) NOT NULL CONSTRAINT df_batch_log_status DEFAULT 'RUNNING'
);

IF OBJECT_ID('etl.load_log', 'U') IS NULL
CREATE TABLE etl.load_log (
    load_id      INT IDENTITY(1,1) NOT NULL CONSTRAINT pk_load_log PRIMARY KEY,
    batch_id     INT NOT NULL,
    package      NVARCHAR(100) NOT NULL,
    table_name   NVARCHAR(128) NOT NULL,
    rows_read    INT NULL,
    rows_written INT NULL,
    rows_error   INT NULL,
    ts           DATETIME2 NOT NULL CONSTRAINT df_load_log_ts DEFAULT SYSDATETIME()
);

IF OBJECT_ID('etl.error_rows', 'U') IS NULL
CREATE TABLE etl.error_rows (
    error_id     INT IDENTITY(1,1) NOT NULL CONSTRAINT pk_error_rows PRIMARY KEY,
    batch_id     INT NOT NULL,
    table_name   NVARCHAR(128) NOT NULL,
    error_code   INT NULL,
    error_column NVARCHAR(100) NULL,
    raw_row      NVARCHAR(MAX) NULL,
    ts           DATETIME2 NOT NULL CONSTRAINT df_error_rows_ts DEFAULT SYSDATETIME()
);