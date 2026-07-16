Automotive Data Warehouse & Sales Forecasting

A data warehouse project that centralizes automobile sales data, models it for analytics using a Medallion (Bronze/Silver/Gold) architecture, and delivers insights through Power BI and an interactive web dashboard, including a machine learning model to forecast next-year sales.

📌 Project Overview

Raw automobile sales data is ingested, cleaned, and transformed into a business-ready star schema. The resulting data powers:


Power BI dashboards for business reporting
A machine learning model to predict next-year sales/prices
A web dashboard (Streamlit) to explore forecasts interactively


🏗️ High-Level Architecture

SOURCE          →        SQL SERVER (DATA WAREHOUSE)                 →     CONSUME
(CSV file)      →   BRONZE  →   SILVER   →    GOLD                   →     Power BI
                  (raw)      (cleaned)   (business-ready,                  Ad-hoc SQL queries
                                          star schema)                     Web Dashboard
                                                                            Machine Learning

LayerObject TypeLoadTransformationsData ModelBronzeTablesBatch, full load (truncate & insert)None (raw, as-is)NoneSilverTablesBatch, full load (truncate & insert)Cleansing, standardization, normalization, derived columns, enrichmentNoneGoldViewsNo loadData integration, aggregation, business logicStar schema, aggregated/flat tables

🛠️ Tech Stack

PurposeToolData WarehouseSQL Server / SSMSETLT-SQL (Bronze → Silver → Gold)Data Modeling / DiagramsDraw.ioBI & ReportingPower BI DesktopMachine LearningPython (pandas, scikit-learn, Prophet)Web DashboardPython (Streamlit)Version ControlGit / GitHub

📂 Naming Conventions


Case: snake_case
Language: English
Schemas: bronze, silver, gold
Bronze/Silver tables: <sourcesystem>_<entity> (matches source, no renaming)
Gold tables/views: <category>_<entity> (e.g. dim_car, fact_car_sales)
Surrogate keys: <table_name>_key (e.g. car_key)
Metadata columns: prefixed dwh_ (e.g. dwh_load_date, dwh_source_system)
Date columns: suffixed _date (e.g. sale_date)
Boolean columns: prefixed is_ / has_
Stored procedures: load_<layer>_<entity> (e.g. load_gold_dim_car)


📁 Project Structure

├── docs/                  # Cahier des charges, architecture diagrams, data catalog
├── sql/
│   ├── bronze/            # DDL + load scripts for raw ingestion
│   ├── silver/            # Cleansing & transformation scripts
│   └── gold/              # Star schema views & business logic
├── notebooks/             # EDA and model training notebooks
├── src/
│   ├── ml/                # Forecasting model code
│   └── dashboard/         # Streamlit web dashboard app
├── powerbi/               # .pbix files
└── README.md

🚀 Roadmap (Epics)


Requirements Analysis
Design Data Architecture
Project Initialization
Build Bronze Layer
Build Silver Layer
Build Gold Layer
Build Power BI Layer
Build AI / Prediction Layer
Build Web Dashboard

