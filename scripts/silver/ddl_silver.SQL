/* ============================================================================
   Project        : Car Sales Data Warehouse
   Database       : car_sales_dwh
   Layer          : Silver
   Source Object  : bronze.dealer_car_sales
   Target Object  : silver.dealer_car_sales

   Description:
       Creates the Silver-layer table when it does not already exist, validates
       the Bronze data, applies cleansing and type conversions, and performs a
       full load into the Silver layer.

   Silver transformations:
       - Remove leading and trailing spaces.
       - Convert empty strings to NULL.
       - Remove carriage-return and line-feed characters from commission_earned.
       - Convert source text values to appropriate SQL Server data types.
       - Reject the load when required values are missing or invalid.
       - Preserve source-system and source-file metadata.
       - Generate a new Silver-layer load timestamp.

   Load strategy:
       Batch processing using TRUNCATE TABLE followed by INSERT.

   Important:
       The Bronze layer is not modified by this script.
   ============================================================================ */

USE car_sales_dwh;
GO


/* ============================================================================
   1. Create the Silver table

   The table is created only when it does not already exist.
   Silver contains cleaned, standardized, and correctly typed data.
   ============================================================================ */

IF OBJECT_ID(N'silver.dealer_car_sales', N'U') IS NULL
BEGIN
    CREATE TABLE silver.dealer_car_sales
    (
        /* Business columns */
        sale_date              DATE            NOT NULL,
        salesperson            NVARCHAR(150)   NOT NULL,
        customer_name          NVARCHAR(150)   NOT NULL,
        car_make               NVARCHAR(100)   NOT NULL,
        car_model              NVARCHAR(100)   NOT NULL,
        car_year               SMALLINT        NOT NULL,
        sale_price             DECIMAL(18,2)   NOT NULL,
        commission_rate        DECIMAL(20,18)  NOT NULL,
        commission_earned      DECIMAL(18,2)   NOT NULL,

        /* Data warehouse metadata */
        dwh_load_date          DATETIME2(0)    NOT NULL,
        dwh_source_system      VARCHAR(50)     NOT NULL,
        dwh_source_file        NVARCHAR(260)   NULL
    );
END;
GO


/* ============================================================================
   2. Create the Silver loading procedure

   Procedure:
       silver.load_silver_dealer_car_sales

   Processing steps:
       1. Count the Bronze records.
       2. Clean and validate every Bronze record.
       3. Stop the load when invalid records are detected.
       4. Truncate the Silver table.
       5. Transform and insert the Bronze records.
       6. Compare the Bronze and Silver row counts.
       7. Commit the transaction when all validations pass.
   ============================================================================ */

CREATE OR ALTER PROCEDURE silver.load_silver_dealer_car_sales
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /* Use one load timestamp for every row in the current batch */
    DECLARE @load_date DATETIME2(0) = SYSDATETIME();

    /* Variables used for load validation */
    DECLARE @bronze_rows BIGINT;
    DECLARE @invalid_rows BIGINT;
    DECLARE @silver_rows BIGINT;


    /* ------------------------------------------------------------------------
       Count all records available in the Bronze source table
       ------------------------------------------------------------------------ */

    SELECT
        @bronze_rows = COUNT_BIG(*)
    FROM bronze.dealer_car_sales;


    /* ------------------------------------------------------------------------
       Validate that every Bronze record can be transformed.

       The first CROSS APPLY cleans the raw text values.
       The second CROSS APPLY attempts to convert the cleaned values to their
       target Silver data types.

       Any row containing a missing mandatory value or an invalid conversion
       is counted as invalid.
       ------------------------------------------------------------------------ */

    SELECT
        @invalid_rows = COUNT_BIG(*)
    FROM bronze.dealer_car_sales AS b

    CROSS APPLY
    (
        SELECT
            /* Remove spaces and convert empty text to NULL */
            NULLIF(
                LTRIM(RTRIM(b.sale_date)),
                ''
            ) AS clean_sale_date,

            NULLIF(
                LTRIM(RTRIM(b.salesperson)),
                ''
            ) AS clean_salesperson,

            NULLIF(
                LTRIM(RTRIM(b.customer_name)),
                ''
            ) AS clean_customer_name,

            NULLIF(
                LTRIM(RTRIM(b.car_make)),
                ''
            ) AS clean_car_make,

            NULLIF(
                LTRIM(RTRIM(b.car_model)),
                ''
            ) AS clean_car_model,

            NULLIF(
                LTRIM(RTRIM(b.car_year)),
                ''
            ) AS clean_car_year,

            NULLIF(
                LTRIM(RTRIM(b.sale_price)),
                ''
            ) AS clean_sale_price,

            NULLIF(
                LTRIM(RTRIM(b.commission_rate)),
                ''
            ) AS clean_commission_rate,

            /*
                commission_earned is the final CSV column.

                The raw Bronze value contains CHAR(13), and potentially
                CHAR(10), from the CSV line ending. These characters must be
                removed before numeric conversion.
            */
            NULLIF(
                LTRIM(
                    RTRIM(
                        REPLACE(
                            REPLACE(
                                b.commission_earned,
                                CHAR(13),
                                ''
                            ),
                            CHAR(10),
                            ''
                        )
                    )
                ),
                ''
            ) AS clean_commission_earned
    ) AS cleaned

    CROSS APPLY
    (
        SELECT
            /* Convert the ISO-formatted source date: YYYY-MM-DD */
            TRY_CONVERT(
                DATE,
                cleaned.clean_sale_date,
                23
            ) AS typed_sale_date,

            TRY_CONVERT(
                SMALLINT,
                cleaned.clean_car_year
            ) AS typed_car_year,

            TRY_CONVERT(
                DECIMAL(18,2),
                cleaned.clean_sale_price
            ) AS typed_sale_price,

            /*
                A high decimal scale is used to preserve the precision
                available in the source commission rate.
            */
            TRY_CONVERT(
                DECIMAL(20,18),
                cleaned.clean_commission_rate
            ) AS typed_commission_rate,

            TRY_CONVERT(
                DECIMAL(18,2),
                cleaned.clean_commission_earned
            ) AS typed_commission_earned
    ) AS typed

    WHERE typed.typed_sale_date IS NULL
       OR cleaned.clean_salesperson IS NULL
       OR cleaned.clean_customer_name IS NULL
       OR cleaned.clean_car_make IS NULL
       OR cleaned.clean_car_model IS NULL
       OR typed.typed_car_year IS NULL
       OR typed.typed_sale_price IS NULL
       OR typed.typed_commission_rate IS NULL
       OR typed.typed_commission_earned IS NULL;


    /* ------------------------------------------------------------------------
       Stop the load when at least one Bronze row cannot be transformed.

       This prevents silently excluding invalid records from the Silver layer.
       ------------------------------------------------------------------------ */

    IF @invalid_rows > 0
    BEGIN
        THROW 50001,
            'Silver load stopped because some Bronze records are missing or invalid.',
            1;
    END;


    /* ------------------------------------------------------------------------
       Execute the Silver full load inside a transaction
       ------------------------------------------------------------------------ */

    BEGIN TRY
        BEGIN TRANSACTION;

        /*
            Full-load strategy:
            Remove the previous Silver batch before inserting the new one.
        */
        TRUNCATE TABLE silver.dealer_car_sales;


        /* --------------------------------------------------------------------
           Insert cleaned and correctly typed records into Silver
           -------------------------------------------------------------------- */

        INSERT INTO silver.dealer_car_sales
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
            /* Convert sale date from raw text to DATE */
            TRY_CONVERT(
                DATE,
                NULLIF(LTRIM(RTRIM(b.sale_date)), ''),
                23
            ) AS sale_date,

            /* Clean and standardize text values */
            NULLIF(
                LTRIM(RTRIM(b.salesperson)),
                ''
            ) AS salesperson,

            NULLIF(
                LTRIM(RTRIM(b.customer_name)),
                ''
            ) AS customer_name,

            NULLIF(
                LTRIM(RTRIM(b.car_make)),
                ''
            ) AS car_make,

            NULLIF(
                LTRIM(RTRIM(b.car_model)),
                ''
            ) AS car_model,

            /* Convert vehicle year from text to SMALLINT */
            TRY_CONVERT(
                SMALLINT,
                NULLIF(LTRIM(RTRIM(b.car_year)), '')
            ) AS car_year,

            /* Convert monetary values to fixed-precision decimals */
            TRY_CONVERT(
                DECIMAL(18,2),
                NULLIF(LTRIM(RTRIM(b.sale_price)), '')
            ) AS sale_price,

            /* Preserve the source commission-rate precision */
            TRY_CONVERT(
                DECIMAL(20,18),
                NULLIF(LTRIM(RTRIM(b.commission_rate)), '')
            ) AS commission_rate,

            /*
                Remove hidden CSV line-ending characters before converting
                commission_earned to a monetary decimal value.
            */
            TRY_CONVERT(
                DECIMAL(18,2),
                NULLIF(
                    LTRIM(
                        RTRIM(
                            REPLACE(
                                REPLACE(
                                    b.commission_earned,
                                    CHAR(13),
                                    ''
                                ),
                                CHAR(10),
                                ''
                            )
                        )
                    ),
                    ''
                )
            ) AS commission_earned,

            /* Silver-layer metadata */
            @load_date AS dwh_load_date,
            b.dwh_source_system,
            b.dwh_source_file

        FROM bronze.dealer_car_sales AS b;


        /* Capture the number of records inserted into Silver */
        SET @silver_rows = @@ROWCOUNT;


        /* --------------------------------------------------------------------
           Validate source-to-target row-count reconciliation
           -------------------------------------------------------------------- */

        IF @silver_rows <> @bronze_rows
        BEGIN
            THROW 50002,
                'Silver row count does not match the Bronze row count.',
                1;
        END;


        /* Make the completed Silver load permanent */
        COMMIT TRANSACTION;


        /* Return a summary of the completed load */
        SELECT
            @bronze_rows AS bronze_rows,
            @silver_rows AS silver_rows,
            @invalid_rows AS invalid_rows,
            @load_date AS silver_load_date,
            'SUCCESS' AS load_status;

    END TRY

    BEGIN CATCH
        /*
            Roll back the full load when an error occurs after the
            transaction has started.
        */
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        /* Return the original SQL Server error to the caller */
        THROW;
    END CATCH;
END;
GO


/* ============================================================================
   3. Execute the Silver full-load procedure
   ============================================================================ */

EXEC silver.load_silver_dealer_car_sales;
GO


/* ============================================================================
   4. Validate the completed Silver load
   ============================================================================ */


/* ---------------------------------------------------------------------------
   4.1 Compare Bronze and Silver row counts

   Because no missing, invalid, or duplicate records were found in the source,
   both layers are expected to contain 2,500,000 records.
   --------------------------------------------------------------------------- */

SELECT
    (
        SELECT COUNT_BIG(*)
        FROM bronze.dealer_car_sales
    ) AS bronze_rows,

    (
        SELECT COUNT_BIG(*)
        FROM silver.dealer_car_sales
    ) AS silver_rows;
GO


/* ---------------------------------------------------------------------------
   4.2 Inspect a sample of the transformed Silver records
   --------------------------------------------------------------------------- */

SELECT TOP (10)
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
FROM silver.dealer_car_sales;
GO


/* ---------------------------------------------------------------------------
   4.3 Validate ranges and commission correctness

   The commission validation confirms that:

       commission_earned ≈ sale_price × commission_rate

   A tolerance of 0.01 is used because commission_earned is stored with two
   decimal places.
   --------------------------------------------------------------------------- */

SELECT
    COUNT_BIG(*) AS total_silver_rows,

    MIN(sale_date) AS minimum_sale_date,
    MAX(sale_date) AS maximum_sale_date,

    MIN(car_year) AS minimum_car_year,
    MAX(car_year) AS maximum_car_year,

    MIN(sale_price) AS minimum_sale_price,
    MAX(sale_price) AS maximum_sale_price,

    MIN(commission_rate) AS minimum_commission_rate,
    MAX(commission_rate) AS maximum_commission_rate,

    MIN(commission_earned) AS minimum_commission_earned,
    MAX(commission_earned) AS maximum_commission_earned,

    SUM(
        CASE
            WHEN ABS(
                commission_earned
                - ROUND(sale_price * commission_rate, 2)
            ) > 0.01
            THEN 1
            ELSE 0
        END
    ) AS inconsistent_commission_rows

FROM silver.dealer_car_sales;
GO
