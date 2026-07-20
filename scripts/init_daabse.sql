/* ============================================================
   Project: Car Sales Data Warehouse
   Purpose: Recreate database and schemas
   Warning: This deletes the existing database and all its data
   ============================================================ */

USE master;
GO

/* Drop the database if it already exists */
IF DB_ID(N'car_sales_dwh') IS NOT NULL
BEGIN
    ALTER DATABASE car_sales_dwh
    SET SINGLE_USER
    WITH ROLLBACK IMMEDIATE;

    DROP DATABASE car_sales_dwh;
END;
GO

/* Create the data warehouse database */
CREATE DATABASE car_sales_dwh;
GO

USE car_sales_dwh;
GO

/* Create the Medallion architecture schemas */
CREATE SCHEMA bronze;
GO

CREATE SCHEMA silver;
GO

CREATE SCHEMA gold;
GO

/* Validate database and schema creation */
SELECT
    DB_NAME() AS database_name,
    name AS schema_name
FROM sys.schemas
WHERE name IN ('bronze', 'silver', 'gold')
ORDER BY name;
GO
