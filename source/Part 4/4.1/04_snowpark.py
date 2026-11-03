import snowflake.snowpark as snowpark
from snowflake.snowpark.context import get_active_session
from snowflake.snowpark.functions import (
    col, count, sum as sum_, avg, max as max_, 
    datediff, current_date, date_trunc
)

# 1. Lấy phiên làm việc hiện tại trực tiếp từ môi trường Snowflake
session = get_active_session()
print("Ket noi Snowpark Session thanh cong!")

# Thiết lập context chính xác
session.use_database("TPCH_ANALYTICS_DB")
session.use_schema("ANALYTICS")
session.use_warehouse("TPCH_WH")

# -------------------------------------------------------------
# 4.1 Customer RFM Segmentation
# -------------------------------------------------------------
print("\n--- 1. Dang tinh toan RFM Segmentation ---")
customers = session.table("TPCH_ANALYTICS_DB.ANALYTICS.CUSTOMER_SILVER")
orders = session.table("TPCH_ANALYTICS_DB.ANALYTICS.ORDERS_SILVER")

rfm_df = (
    customers.join(orders, customers["C_CUSTKEY"] == orders["O_CUSTKEY"], "left")
    .group_by("C_CUSTKEY", "C_NAME")
    .agg([
        max_("O_ORDERDATE").alias("LAST_ORDER_DATE"),
        count("O_ORDERKEY").alias("FREQUENCY"),
        sum_("O_TOTALPRICE").alias("MONETARY")
    ])
    .with_column(
        "RECENCY_DAYS", 
        datediff("day", col("LAST_ORDER_DATE"), current_date())
    )
)

# Lưu kết quả vào bảng CUSTOMER_RFM_SCORES
rfm_df.write.mode("overwrite").save_as_table("TPCH_ANALYTICS_DB.ANALYTICS.CUSTOMER_RFM_SCORES")
print(f"Xong RFM. Tong so khach hang: {rfm_df.count()}")
rfm_df.show(5)

# -------------------------------------------------------------
# 4.2 Sales Trend Analysis
# -------------------------------------------------------------
print("\n--- 2. Dang phan tich Sales Trend ---")
monthly_sales = (
    orders
    .with_column("MONTH", date_trunc("month", col("O_ORDERDATE")))
    .group_by("MONTH")
    .agg([
        count("O_ORDERKEY").alias("ORDER_COUNT"),
        sum_("O_TOTALPRICE").alias("TOTAL_REVENUE"),
        avg("O_TOTALPRICE").alias("AVG_ORDER_VALUE")
    ])
    .sort("MONTH")
)

# Lưu kết quả vào bảng MONTHLY_SALES_TREND
monthly_sales.write.mode("overwrite").save_as_table("TPCH_ANALYTICS_DB.ANALYTICS.MONTHLY_SALES_TREND")
print("Xong Sales Trend.")
monthly_sales.show(5)

print("\n=== HOAN THANH TOAN BO PIPELINE SNOWPARK ===")