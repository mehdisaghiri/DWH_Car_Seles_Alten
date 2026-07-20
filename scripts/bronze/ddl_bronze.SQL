



USE car_sales_dwh;
GO
CREATE TABLE bronze.dealer_car_sales(sale_data DATE,
        salesperson NVARCHAR(100),
        customer_name NVARCHAR(100),
        car_make NVARCHAR(50),
        car_model NVARCHAR(50),
        car_year INT,
        sale_price DECIMAL(12,2),
        commision_rate DECIMAL(12,2),
        commision_earned DECIMAL(12,2),
);

GO

USE car_sales_dwh


BULK INSERT bronze.dealer_car_sales
FROM "path"
WITH (
     FROMAT ='csv'
     FIRSTROW = 2,
     FIELDTERMINATOR = ',',
     ROWTERMINATOR = '0X0a',
     TABLOCK
);

GO

