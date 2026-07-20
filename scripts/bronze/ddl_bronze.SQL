USE car_sales_dwh;
GO

/* ============================================================
   Project: Car Sales Data Warehouse
   Layer: Bronze
   Object: bronze.dealer_car_sales

   Purpose:
   Store automobile sales data exactly as received from the CSV.
   No cleansing, standardization, or type conversion is performed.
   ============================================================ */

/* Delete the table if it already exists */
DROP TABLE IF EXISTS bronze.dealer_car_sales;
GO

/* Create the Bronze table */
CREATE TABLE bronze.dealer_car_sales
(
    sale_date             NVARCHAR(50)  NULL,
    salesperson           NVARCHAR(150) NULL,
    customer_name         NVARCHAR(150) NULL,
    car_make              NVARCHAR(100) NULL,
    car_model             NVARCHAR(100) NULL,
    car_year              NVARCHAR(20)  NULL,
    sale_price            NVARCHAR(50)  NULL,
    commission_rate       NVARCHAR(50)  NULL,
    commission_earned     NVARCHAR(50)  NULL,

    /* Data warehouse metadata */
    dwh_load_date         DATETIME2(0)  NOT NULL
        CONSTRAINT df_bronze_dealer_car_sales_load_date
        DEFAULT SYSDATETIME(),

    dwh_source_system     VARCHAR(50)   NOT NULL
        CONSTRAINT df_bronze_dealer_car_sales_source_system
        DEFAULT 'dealer',

    dwh_source_file       NVARCHAR(260) NULL
);
GO

/* Validate table creation */
SELECT
    schema_name = SCHEMA_NAME(t.schema_id),
    table_name = t.name,
    column_name = c.name,
    data_type = TYPE_NAME(c.user_type_id),
    max_length = CASE
        WHEN TYPE_NAME(c.user_type_id) IN ('nvarchar', 'nchar')
            THEN c.max_length / 2
        ELSE c.max_length
    END,
    is_nullable = c.is_nullable
FROM sys.tables AS t
INNER JOIN sys.columns AS c
    ON t.object_id = c.object_id
WHERE t.object_id = OBJECT_ID('bronze.dealer_car_sales')
ORDER BY c.column_id;
GO



