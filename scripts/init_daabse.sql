/*
this script for creating the databse 
1- move to master 
2- create the databse
3- create the schemas 

*/

USE master ;

CREATE DATABASE car_sales_dwh;

USE car_sales_dwh;

CREATE SCHEMA bronze;
GO
CREATE SCHEMA silver;
GO
CREATE SCHEMA gold;
GO


