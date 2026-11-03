
========================================================================================================================
                                      MEDALLION DATA PIPELINE ARCHITECTURE (TPC-H)
========================================================================================================================

 [Data Source Files]
   orders.csv, customer.csv, lineitem.csv, part.csv, supplier.csv, nation.csv, region.csv
        │
        │  (Upload qua Snowsight / Unload)
        ▼
 ┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
 │ STAGING STAGE: @TPCH_ANALYTICS_DB.STAGING.TPCH_DATA_STAGE (Internal Stage, File Format: TPCH_CSV_FORMAT)           │
 └────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
        │
        │  (COPY INTO ... ON_ERROR = 'CONTINUE')
        ▼
 ┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
 │ BRONZE LAYER (Schema: STAGING) - Raw Untransformed Data Tables                                                     │
 │                                                                                                                    │
 │  ┌─────────────────────────┐  ┌─────────────────────────┐  ┌─────────────────────────┐  ┌────────────────────────┐ │
 │  │ ORDERS (1.5M rows)      │  │ CUSTOMER (150K rows)    │  │ LINEITEM (6.0M rows)    │  │ STATIC LOOKUPS         │ │
 │  │ O_ORDERKEY, O_TOTALPRICE│  │ C_CUSTKEY, C_NAME,      │  │ L_ORDERKEY, L_EXTENDED..│  │ PART, SUPPLIER,        │ │
 │  │ O_ORDERDATE, O_STATUS...│  │ C_NATIONKEY, C_ACCTBAL..│  │ L_DISCOUNT, L_TAX...    │  │ PARTSUPP, NATION, REG. │ │
 │  └───────────┬─────────────┘  └───────────┬─────────────┘  └───────────┬─────────────┘  └───────────┬────────────┘ │
 └──────────────┼────────────────────────────┼────────────────────────────┼────────────────────────────┼──────────────┘
                │                            │                            │                            │
                │ (Change Tracking)          │ (Change Tracking)          │ (Change Tracking)          │
                ▼                            ▼                            ▼                            │
 ┌────────────────────────────┐ ┌────────────────────────────┐ ┌────────────────────────────┐          │
 │ ORDERS_STREAM              │ │ CUSTOMER_STREAM            │ │ LINEITEM_STREAM            │          │
 │ (CDC: INSERT / UPDATE)     │ │ (CDC: INSERT / UPDATE)     │ │ (CDC: INSERT / UPDATE)     │          │
 └──────────────┬─────────────┘ └───────────┬────────────────┘ └───────────┬────────────────┘          │
                │                           │                              │                           │
                │                           │                              │ (Join Enrichment)         │
                │ (Triggers Root Task)      │ (Triggered by DAG)           │ ◄─────────────────────────┘
                ▼                           ▼                              ▼
 ┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
 │ AUTOMATED ORCHESTRATION & STORED PROCEDURES (Tasks DAG)                                                            │
 │                                                                                                                    │
 │  [TASK_BRONZE_TO_SILVER_ORDERS] ──(Triggers AFTER)──► [TASK_BRONZE_TO_SILVER_CUSTOMERS]                            │
 │         │                                                    │                                                     │
 │         ▼ (Calls SP)                                         ▼ (Calls SP)                                          │
 │   SP_TRANSFORM_ORDERS_SILVER()                         SP_TRANSFORM_CUSTOMER_SILVER()                              │
 └─────────┬────────────────────────────────────────────────────┬─────────────────────────────────────────────────────┘
           │                                                    │
           ▼                                                    ▼
 ┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
 │ SILVER LAYER (Schema: ANALYTICS) - Cleaned, Enriched & Denormalized Data                                           │
 │                                                                                                                    │
 │  ┌────────────────────────────────────┐  ┌────────────────────────────────────┐  ┌───────────────────────────────┐ │
 │  │ ORDERS_SILVER                      │  │ CUSTOMER_SILVER                    │  │ LINEITEM_SILVER               │ │
 │  │ - O_ORDERSTATUS_DESC (Enriched)    │  │ - C_NATION_NAME (Joined NATION)    │  │ - L_PART_NAME (Joined PART)   │ │
 │  │ - O_ORDER_YEAR, MONTH, QUARTER     │  │ - C_REGION_NAME (Joined REGION)    │  │ - L_SUPPLIER_NAME (Joined SUP)│ │
 │  │ - O_PRIORITY_RANK, O_CLERK_ID      │  │ - C_MKTSEGMENT, C_ACCTBAL          │  │ - L_NET_PRICE, L_FINAL_PRICE  │ │
 │  │ - Audit: FIRST_LOADED, LAST_UPDATE │  │ - LOAD_TIMESTAMP                   │  │ - L_SHIP_DELAY_DAYS           │ │
 │  └─────────────────┬──────────────────┘  └─────────────────┬──────────────────┘  └───────────────────────────────┘ │
 └────────────────────┼───────────────────────────────────────┼───────────────────────────────────────────────────────┘
                      │                                       │
                      ├───────────────────┐                   │
                      │                   │                   │
                      ▼                   ▼                   ▼
 ┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
 │ GOLD TRANSFORMATION TASKS (Tasks DAG Concurrency)                                                                  │
 │                                                                                                                    │
 │  [TASK_SILVER_TO_GOLD_DAILY_SALES]                    [TASK_SILVER_TO_GOLD_CUSTOMER_LTV]                           │
 │  (Executes AFTER: Orders Silver Task)                 (Executes AFTER: Customers Silver Task)                      │
 │         │                                                    │                                                     │
 │         ▼ (Calls SP)                                         ▼ (Calls SP)                                          │
 │   SP_CALCULATE_DAILY_SALES_SUMMARY()                   SP_CALCULATE_CUSTOMER_LTV()                                 │
 └─────────┬────────────────────────────────────────────────────┬─────────────────────────────────────────────────────┘
           │                                                    │
           ▼                                                    ▼
 ┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
 │ GOLD LAYER (Schema: ANALYTICS) - Aggregated Business Metrics & Customer Lifetime Value                             │
 │                                                                                                                    │
 │  ┌───────────────────────────────────────────────┐   ┌──────────────────────────────────────────────────────────┐  │
 │  │ DAILY_SALES_SUMMARY                           │   │ CUSTOMER_LTV                                             │  │
 │  │ - SUMMARY_DATE (PK)                           │   │ - C_CUSTKEY (PK), C_NAME, C_NATION_NAME                  │  │
 │  │ - TOTAL_ORDERS, TOTAL_CUSTOMERS               │   │ - TOTAL_ORDERS, TOTAL_SPENT, AVG_ORDER_VALUE             │  │
 │  │ - TOTAL_REVENUE                               │   │ - FIRST_ORDER_DATE, LAST_ORDER_DATE                      │  │
 │  │ - AVG_ORDER_VALUE, MIN/MAX_ORDER_VALUE        │   │ - CUSTOMER_TENURE_DAYS                                   │  │
 │  │                                               │   │ - CUSTOMER_TIER (VIP, GOLD, SILVER, BRONZE, STANDARD)    │  │
 │  │                                               │   │ - IS_ACTIVE (Order placed in last 90 days)               │  │
 │  └───────────────────────┬───────────────────────┘   └────────────────────────────┬─────────────────────────────┘  │
 └──────────────────────────┼────────────────────────────────────────────────────────┼────────────────────────────────┘
                            │                                                        │
                            ▼                                                        ▼
 ┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
 │ CONSUMPTION & REPORTING LAYER (Schema: REPORTS / Python / BI Dashboards)                                           │
 │                                                                                                                    │
 │  • Snowpark Python DataFrames: RFM Segmentation (`CUSTOMER_RFM_SCORES`), Monthly Sales Trend Analysis              │
 │  • Business Intelligence: Tableau / Power BI / Apache Superset Dashboard Connectivity                              │
 │  • Analytical Queries & SQL UDFs: Customer Tier classification, Phone & Email Validation Regex                     │
 └────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
========================================================================================================================
```

---
