USE car_sales_dwh;
GO

CREATE OR ALTER PROCEDURE bronze.load_bronze_dealer_car_sales
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @load_date DATETIME2(0) = SYSDATETIME();

    /* Temporary table matching the 9 CSV columns */
    DROP TABLE IF EXISTS #dealer_car_sales_import;

    CREATE TABLE #dealer_car_sales_import
    (
        sale_date          NVARCHAR(50)  NULL,
        salesperson        NVARCHAR(150) NULL,
        customer_name      NVARCHAR(150) NULL,
        car_make           NVARCHAR(100) NULL,
        car_model          NVARCHAR(100) NULL,
        car_year           NVARCHAR(20)  NULL,
        sale_price         NVARCHAR(50)  NULL,
        commission_rate    NVARCHAR(50)  NULL,
        commission_earned  NVARCHAR(50)  NULL
    );

    /* Import the CSV into the temporary table */
    BULK INSERT #dealer_car_sales_import
    FROM 'C:\Users\Mehdi\Desktop\ALTEN DATA PROJECT\data\car_sales_data.csv'
    WITH
    (
        FORMAT = 'CSV',
        FIRSTROW = 2,
        FIELDQUOTE = '"',
        CODEPAGE = '65001',
        ROWTERMINATOR = '0x0a',
        TABLOCK
    );

    BEGIN TRY
        BEGIN TRANSACTION;

        /* Full-load strategy: delete existing rows */
        TRUNCATE TABLE bronze.dealer_car_sales;

        /* Insert source data and generate metadata */
        INSERT INTO bronze.dealer_car_sales
        (
            sale_date,
            salesperson,
            customer_name,
            car_make,
            car_model,
            car_year,
            sale_price,
            commission_rate,
            commission_earned,
            dwh_load_date,
            dwh_source_system,
            dwh_source_file
        )
        SELECT
            sale_date,
            salesperson,
            customer_name,
            car_make,
            car_model,
            car_year,
            sale_price,
            commission_rate,
            commission_earned,
            @load_date,
            'dealer',
            'car_sales_data.csv'
        FROM #dealer_car_sales_import;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;

    /* Load validation */
    SELECT
        COUNT_BIG(*) AS loaded_rows,
        MIN(dwh_load_date) AS dwh_load_date,
        MIN(dwh_source_file) AS source_file
    FROM bronze.dealer_car_sales;
END;
GO

/*Run the loading procedure:*/
EXEC bronze.load_bronze_dealer_car_sales;
GO



/*Check the imported rows:*/
SELECT TOP (100)
    *
FROM bronze.dealer_car_sales;
GO

/*Check the total row count*/
SELECT COUNT_BIG(*) AS total_rows
FROM bronze.dealer_car_sales;
GO





/* validate Bronze completeness */


USE car_sales_dwh;
GO

/* 1. Total rows */
SELECT COUNT_BIG(*) AS total_rows
FROM bronze.dealer_car_sales;


/* 2. Check null values */
SELECT
    SUM(CASE WHEN sale_date IS NULL OR LTRIM(RTRIM(sale_date)) = '' THEN 1 ELSE 0 END) AS null_sale_date,
    SUM(CASE WHEN salesperson IS NULL OR LTRIM(RTRIM(salesperson)) = '' THEN 1 ELSE 0 END) AS null_salesperson,
    SUM(CASE WHEN customer_name IS NULL OR LTRIM(RTRIM(customer_name)) = '' THEN 1 ELSE 0 END) AS null_customer_name,
    SUM(CASE WHEN car_make IS NULL OR LTRIM(RTRIM(car_make)) = '' THEN 1 ELSE 0 END) AS null_car_make,
    SUM(CASE WHEN car_model IS NULL OR LTRIM(RTRIM(car_model)) = '' THEN 1 ELSE 0 END) AS null_car_model,
    SUM(CASE WHEN car_year IS NULL OR LTRIM(RTRIM(car_year)) = '' THEN 1 ELSE 0 END) AS null_car_year,
    SUM(CASE WHEN sale_price IS NULL OR LTRIM(RTRIM(sale_price)) = '' THEN 1 ELSE 0 END) AS null_sale_price,
    SUM(CASE WHEN commission_rate IS NULL OR LTRIM(RTRIM(commission_rate)) = '' THEN 1 ELSE 0 END) AS null_commission_rate,
    SUM(CASE WHEN commission_earned IS NULL OR LTRIM(RTRIM(commission_earned)) = '' THEN 1 ELSE 0 END) AS null_commission_earned
FROM bronze.dealer_car_sales;


/* 3. Check duplicate rows */
SELECT
    COUNT_BIG(*) AS duplicate_groups,
    SUM(duplicate_count - 1) AS duplicate_rows
FROM
(
    SELECT
        COUNT_BIG(*) AS duplicate_count
    FROM bronze.dealer_car_sales
    GROUP BY
        sale_date,
        salesperson,
        customer_name,
        car_make,
        car_model,
        car_year,
        sale_price,
        commission_rate,
        commission_earned
    HAVING COUNT_BIG(*) > 1
) AS duplicates;


/* 4. Check invalid dates and numeric values */
SELECT
    SUM(CASE WHEN TRY_CONVERT(DATE, sale_date) IS NULL THEN 1 ELSE 0 END) AS invalid_sale_dates,
    SUM(CASE WHEN TRY_CONVERT(INT, car_year) IS NULL THEN 1 ELSE 0 END) AS invalid_car_years,
    SUM(CASE WHEN TRY_CONVERT(DECIMAL(18,2), sale_price) IS NULL THEN 1 ELSE 0 END) AS invalid_sale_prices,
    SUM(CASE WHEN TRY_CONVERT(DECIMAL(18,10), commission_rate) IS NULL THEN 1 ELSE 0 END) AS invalid_commission_rates,
    SUM(CASE WHEN TRY_CONVERT(DECIMAL(18,2), commission_earned) IS NULL THEN 1 ELSE 0 END) AS invalid_commission_earned
FROM bronze.dealer_car_sales;
GO
