-- =====================================================================
-- PHẦN 4: SQL USER-DEFINED FUNCTIONS (UDFs)
-- =====================================================================

-- Cấp quyền thao tác cho TPCH_DEVELOPER và quyền sử dụng cho TPCH_ANALYST
GRANT ALL PRIVILEGES ON SCHEMA TPCH_ANALYTICS_DB.UDFS TO ROLE TPCH_DEVELOPER;
GRANT USAGE ON SCHEMA TPCH_ANALYTICS_DB.UDFS TO ROLE TPCH_ANALYST;
USE ROLE TPCH_DEVELOPER;
USE WAREHOUSE TPCH_WH;
USE DATABASE TPCH_ANALYTICS_DB;
USE SCHEMA UDFS;
-- ---------------------------------------------------------------------
-- UDF 1: Phan loai hang khach hang dua tren tong doanh thu
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION FN_GET_CUSTOMER_TIER(TOTAL_REVENUE NUMBER(15,2))
RETURNS VARCHAR(20)
AS
$$
    CASE
        WHEN TOTAL_REVENUE >= 500000 THEN 'VIP'
        WHEN TOTAL_REVENUE >= 200000 THEN 'GOLD'
        WHEN TOTAL_REVENUE >= 100000 THEN 'SILVER'
        WHEN TOTAL_REVENUE >= 50000  THEN 'BRONZE'
        ELSE 'STANDARD'
    END
$$;

-- ---------------------------------------------------------------------
-- UDF 2: Validate dinh dang so dien thoai (ho tro ca chuan TPC-H va quoc te)
-- Chuan TPC-H: 27-918-335-1736 (XX-XXX-XXX-XXXX)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION FN_VALIDATE_PHONE(PHONE_STR VARCHAR)
RETURNS BOOLEAN
AS
$$
    REGEXP_LIKE(TRIM(PHONE_STR), '^([0-9]{2,3}-[0-9]{3}-[0-9]{3}-[0-9]{4}|\\+?[0-9]{1,3}[- ]?[0-9]{3,4}[- ]?[0-9]{3,4})$')
$$;

-- ---------------------------------------------------------------------
-- UDF 3: Validate dia chi email
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION FN_VALIDATE_EMAIL(EMAIL_STR VARCHAR)
RETURNS BOOLEAN
AS
$$
    REGEXP_LIKE(TRIM(EMAIL_STR), '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$')
$$;

SHOW USER FUNCTIONS IN SCHEMA TPCH_ANALYTICS_DB.UDFS;
-- ---------------------------------------------------------------------
-- TEST CÁC UDFs
-- ---------------------------------------------------------------------
USE ROLE TPCH_ANALYST;

-- 1. Test UDF 1 voi bang CUSTOMER_LTV
SELECT 
    C_CUSTKEY,
    C_NAME,
    TOTAL_SPENT,
    TPCH_ANALYTICS_DB.UDFS.FN_GET_CUSTOMER_TIER(TOTAL_SPENT) AS CALCULATED_TIER,
    CUSTOMER_TIER AS EXISTING_TIER
FROM TPCH_ANALYTICS_DB.ANALYTICS.CUSTOMER_LTV
LIMIT 10;

-- 2. Test UDF 2 voi so dien thoai that va test case sai
SELECT 
    C_PHONE,
    TPCH_ANALYTICS_DB.UDFS.FN_VALIDATE_PHONE(C_PHONE) AS IS_VALID_PHONE
FROM TPCH_ANALYTICS_DB.ANALYTICS.CUSTOMER_SILVER
LIMIT 5;

-- Test case kiem tra tinh dung/sai cua UDF phone
SELECT 
    TPCH_ANALYTICS_DB.UDFS.FN_VALIDATE_PHONE('27-918-335-1736') AS SHOULD_BE_TRUE,
    TPCH_ANALYTICS_DB.UDFS.FN_VALIDATE_PHONE('12345-abc-999') AS SHOULD_BE_FALSE;

-- 3. Test UDF 3 kiem tra email
SELECT 
    TPCH_ANALYTICS_DB.UDFS.FN_VALIDATE_EMAIL('bao.nguyen@hust.edu.vn') AS VALID_EMAIL,
    TPCH_ANALYTICS_DB.UDFS.FN_VALIDATE_EMAIL('invalid_email_at_domain') AS INVALID_EMAIL;