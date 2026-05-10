-- ================================================================
--   GRADUATION PROJECT — COMPLETE SQL ANSWERS
--   ✦ Part 1 : Core Queries (JOINs · Filters · Aggregations)
--   ✦ Part 2 : Enhanced Queries (Window Functions)
--
--   Schema: sales_fact_1997 | sales_fact_1998 | product |
--           customer | store | region | time_by_day | returns
-- ================================================================

-- ################################################################
--  PART 1 · CORE QUERIES  (JOINs · Filters · Aggregations)
-- ################################################################

-- ============================================================
--   GRADUATION PROJECT — BUSINESS QUESTIONS SQL ANSWERS
--   Schema: sales_fact | product | customer | store |
--           time_by_day | region | returns
-- ============================================================


-- ══════════════════════════════════════════════════════════
--  SECTION 1 · SALES
-- ══════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────
-- SALES 01 · Total revenue generated in each year (1997 vs 1998)
-- KPI: Total Revenue = unit_sales × product_retail_price
-- ─────────────────────────────────────────────────────────
SELECT
    t.the_year                                        AS sales_year,
    COUNT(DISTINCT s.customer_id)                     AS total_customers,
    SUM(s.unit_sales)                                 AS total_units_sold,
    ROUND(SUM(s.unit_sales * s.store_sales / s.unit_sales
              * s.unit_sales), 2)                     AS total_revenue   -- store_sales IS the revenue column
FROM sales_fact_1997 s
JOIN time_by_day t ON s.time_id = t.time_id
GROUP BY t.the_year

UNION ALL

SELECT
    t.the_year,
    COUNT(DISTINCT s.customer_id),
    SUM(s.unit_sales),
    ROUND(SUM(s.store_sales), 2)
FROM sales_fact_1998 s
JOIN time_by_day t ON s.time_id = t.time_id
GROUP BY t.the_year

ORDER BY sales_year;

-- Simpler combined version (if a single sales table with year column exists):
-- SELECT
--     t.the_year                          AS sales_year,
--     ROUND(SUM(s.store_sales), 2)        AS total_revenue,
--     SUM(s.unit_sales)                   AS total_units_sold
-- FROM sales_fact s
-- JOIN time_by_day t ON s.time_id = t.time_id
-- GROUP BY t.the_year
-- ORDER BY t.the_year;


-- ─────────────────────────────────────────────────────────
-- SALES 02 · Which month generates the highest average revenue?
-- Requires: Calendar join, month aggregation
-- ─────────────────────────────────────────────────────────
SELECT
    t.month_of_year                             AS month_number,
    t.the_month                                 AS month_name,
    ROUND(AVG(daily_revenue.daily_rev), 2)      AS avg_daily_revenue,
    ROUND(SUM(s.store_sales), 2)                AS total_monthly_revenue
FROM (
    SELECT * FROM sales_fact_1997
    UNION ALL
    SELECT * FROM sales_fact_1998
) s
JOIN time_by_day t ON s.time_id = t.time_id
JOIN (
    SELECT time_id, SUM(store_sales) AS daily_rev
    FROM (
        SELECT * FROM sales_fact_1997
        UNION ALL
        SELECT * FROM sales_fact_1998
    ) all_sales
    GROUP BY time_id
) daily_revenue ON s.time_id = daily_revenue.time_id
GROUP BY t.month_of_year, t.the_month
ORDER BY total_monthly_revenue DESC;


-- ─────────────────────────────────────────────────────────
-- SALES 03 · Year-over-Year (YoY) revenue growth % from 1997 to 1998
-- KPI: YoY Growth % = (1998_rev - 1997_rev) / 1997_rev * 100
-- ─────────────────────────────────────────────────────────
WITH yearly_revenue AS (
    SELECT
        t.the_year,
        ROUND(SUM(s.store_sales), 2) AS total_revenue
    FROM (
        SELECT * FROM sales_fact_1997
        UNION ALL
        SELECT * FROM sales_fact_1998
    ) s
    JOIN time_by_day t ON s.time_id = t.time_id
    GROUP BY t.the_year
)
SELECT
    r1997.total_revenue                                              AS revenue_1997,
    r1998.total_revenue                                              AS revenue_1998,
    ROUND(r1998.total_revenue - r1997.total_revenue, 2)             AS revenue_growth,
    ROUND(
        (r1998.total_revenue - r1997.total_revenue)
        / r1997.total_revenue * 100, 2
    )                                                                AS yoy_growth_pct
FROM
    (SELECT total_revenue FROM yearly_revenue WHERE the_year = 1997) r1997,
    (SELECT total_revenue FROM yearly_revenue WHERE the_year = 1998) r1998;


-- ─────────────────────────────────────────────────────────
-- SALES 04 · Total number of transactions (orders) per quarter
-- Requires: Calendar dimension with quarter field
-- ─────────────────────────────────────────────────────────
SELECT
    t.the_year          AS sales_year,
    t.quarter           AS sales_quarter,
    COUNT(*)            AS total_transactions,
    SUM(s.unit_sales)   AS total_units,
    ROUND(SUM(s.store_sales), 2) AS total_revenue
FROM (
    SELECT * FROM sales_fact_1997
    UNION ALL
    SELECT * FROM sales_fact_1998
) s
JOIN time_by_day t ON s.time_id = t.time_id
GROUP BY t.the_year, t.quarter
ORDER BY t.the_year, t.quarter;


-- ─────────────────────────────────────────────────────────
-- SALES 05 · Average Order Value (AOV) overall and by store
-- KPI: AOV = Total Revenue / Total Orders
-- ─────────────────────────────────────────────────────────
-- Overall AOV
SELECT
    ROUND(SUM(s.store_sales) / COUNT(*), 2) AS overall_aov
FROM (
    SELECT * FROM sales_fact_1997
    UNION ALL
    SELECT * FROM sales_fact_1998
) s;

-- AOV by store
SELECT
    s.store_id,
    st.store_name,
    COUNT(*)                                    AS total_orders,
    ROUND(SUM(s.store_sales), 2)                AS total_revenue,
    ROUND(SUM(s.store_sales) / COUNT(*), 2)     AS aov_per_store
FROM (
    SELECT * FROM sales_fact_1997
    UNION ALL
    SELECT * FROM sales_fact_1998
) s
JOIN store st ON s.store_id = st.store_id
GROUP BY s.store_id, st.store_name
ORDER BY aov_per_store DESC;


-- ══════════════════════════════════════════════════════════
--  SECTION 2 · PRODUCT
-- ══════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────
-- PRODUCT 01 · Top 10 products by highest total revenue
-- Requires: Sales JOIN Products, ORDER BY revenue DESC
-- ─────────────────────────────────────────────────────────
SELECT
    p.product_id,
    p.product_name,
    p.brand_name,
    ROUND(SUM(s.store_sales), 2)    AS total_revenue,
    SUM(s.unit_sales)               AS total_units_sold
FROM (
    SELECT * FROM sales_fact_1997
    UNION ALL
    SELECT * FROM sales_fact_1998
) s
JOIN product p ON s.product_id = p.product_id
GROUP BY p.product_id, p.product_name, p.brand_name
ORDER BY total_revenue DESC
LIMIT 10;


-- ─────────────────────────────────────────────────────────
-- PRODUCT 02 · Product brands with highest profit margin
-- KPI: Profit Margin = store_sales - store_cost  (retail_price - cost)
-- ─────────────────────────────────────────────────────────
SELECT
    p.brand_name,
    ROUND(SUM(s.store_sales), 2)                            AS total_revenue,
    ROUND(SUM(s.store_cost), 2)                             AS total_cost,
    ROUND(SUM(s.store_sales) - SUM(s.store_cost), 2)        AS total_profit,
    ROUND(
        (SUM(s.store_sales) - SUM(s.store_cost))
        / SUM(s.store_sales) * 100, 2
    )                                                        AS profit_margin_pct
FROM (
    SELECT * FROM sales_fact_1997
    UNION ALL
    SELECT * FROM sales_fact_1998
) s
JOIN product p ON s.product_id = p.product_id
GROUP BY p.brand_name
ORDER BY profit_margin_pct DESC;


-- ─────────────────────────────────────────────────────────
-- PRODUCT 03 · Products with highest return rate & impact on net revenue
-- KPI: Return Rate % = returned_qty / sold_qty × 100
-- ─────────────────────────────────────────────────────────
SELECT
    p.product_id,
    p.product_name,
    p.brand_name,
    SUM(s.unit_sales)                                                AS total_sold_qty,
    COALESCE(SUM(r.units_returned), 0)                               AS total_returned_qty,
    ROUND(SUM(s.store_sales), 2)                                     AS gross_revenue,
    ROUND(COALESCE(SUM(r.units_returned), 0)
          * AVG(s.store_sales / s.unit_sales), 2)                    AS revenue_lost,
    ROUND(SUM(s.store_sales)
          - COALESCE(SUM(r.units_returned), 0)
            * AVG(s.store_sales / s.unit_sales), 2)                  AS net_revenue,
    ROUND(
        COALESCE(SUM(r.units_returned), 0) * 100.0
        / NULLIF(SUM(s.unit_sales), 0), 2
    )                                                                AS return_rate_pct
FROM (
    SELECT * FROM sales_fact_1997
    UNION ALL
    SELECT * FROM sales_fact_1998
) s
JOIN product p ON s.product_id = p.product_id
LEFT JOIN (
    SELECT product_id, SUM(units_returned) AS units_returned
    FROM returns
    GROUP BY product_id
) r ON p.product_id = r.product_id
GROUP BY p.product_id, p.product_name, p.brand_name
ORDER BY return_rate_pct DESC
LIMIT 20;


-- ─────────────────────────────────────────────────────────
-- PRODUCT 04 · Do low-fat or recyclable products sell more?
-- Segment analysis on product attributes
-- ─────────────────────────────────────────────────────────
SELECT
    p.low_fat,
    p.recyclable_package,
    COUNT(DISTINCT p.product_id)            AS product_count,
    SUM(s.unit_sales)                       AS total_units_sold,
    ROUND(SUM(s.store_sales), 2)            AS total_revenue,
    ROUND(AVG(s.store_sales), 2)            AS avg_sale_per_transaction
FROM (
    SELECT * FROM sales_fact_1997
    UNION ALL
    SELECT * FROM sales_fact_1998
) s
JOIN product p ON s.product_id = p.product_id
GROUP BY p.low_fat, p.recyclable_package
ORDER BY total_revenue DESC;


-- ══════════════════════════════════════════════════════════
--  SECTION 3 · CUSTOMER
-- ══════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────
-- CUSTOMER 01 · Which customer income brackets drive the most revenue?
-- Requires: Sales JOIN Customers, GROUP BY yearly_income
-- ─────────────────────────────────────────────────────────
SELECT
    c.yearly_income                         AS income_bracket,
    COUNT(DISTINCT s.customer_id)           AS total_customers,
    COUNT(*)                                AS total_transactions,
    SUM(s.unit_sales)                       AS total_units_sold,
    ROUND(SUM(s.store_sales), 2)            AS total_revenue,
    ROUND(AVG(s.store_sales), 2)            AS avg_transaction_value
FROM (
    SELECT * FROM sales_fact_1997
    UNION ALL
    SELECT * FROM sales_fact_1998
) s
JOIN customer c ON s.customer_id = c.customer_id
GROUP BY c.yearly_income
ORDER BY total_revenue DESC;


-- ─────────────────────────────────────────────────────────
-- CUSTOMER 02 · Revenue contribution by loyalty card tier
-- Segment by member_card column (Bronze, Normal, Silver, Gold)
-- ─────────────────────────────────────────────────────────
SELECT
    c.member_card                           AS loyalty_tier,
    COUNT(DISTINCT s.customer_id)           AS total_customers,
    COUNT(*)                                AS total_transactions,
    ROUND(SUM(s.store_sales), 2)            AS total_revenue,
    ROUND(AVG(s.store_sales), 2)            AS avg_transaction_value,
    ROUND(
        SUM(s.store_sales) * 100.0
        / SUM(SUM(s.store_sales)) OVER (), 2
    )                                       AS revenue_share_pct
FROM (
    SELECT * FROM sales_fact_1997
    UNION ALL
    SELECT * FROM sales_fact_1998
) s
JOIN customer c ON s.customer_id = c.customer_id
GROUP BY c.member_card
ORDER BY total_revenue DESC;


-- ─────────────────────────────────────────────────────────
-- CUSTOMER 03 · Gender-based difference in purchasing behaviour & avg spend
-- GROUP BY gender
-- ─────────────────────────────────────────────────────────
SELECT
    c.gender,
    COUNT(DISTINCT s.customer_id)           AS total_customers,
    COUNT(*)                                AS total_transactions,
    SUM(s.unit_sales)                       AS total_units_purchased,
    ROUND(SUM(s.store_sales), 2)            AS total_revenue,
    ROUND(AVG(s.store_sales), 2)            AS avg_spend_per_transaction,
    ROUND(SUM(s.store_sales)
          / COUNT(DISTINCT s.customer_id), 2) AS avg_spend_per_customer
FROM (
    SELECT * FROM sales_fact_1997
    UNION ALL
    SELECT * FROM sales_fact_1998
) s
JOIN customer c ON s.customer_id = c.customer_id
GROUP BY c.gender
ORDER BY total_revenue DESC;


-- ─────────────────────────────────────────────────────────
-- CUSTOMER 04 · Which countries contribute the most customers & revenue?
-- GROUP BY customer_country (USA, Canada, Mexico)
-- ─────────────────────────────────────────────────────────
SELECT
    c.country                               AS customer_country,
    COUNT(DISTINCT c.customer_id)           AS total_customers,
    COUNT(*)                                AS total_transactions,
    ROUND(SUM(s.store_sales), 2)            AS total_revenue,
    ROUND(AVG(s.store_sales), 2)            AS avg_spend_per_transaction,
    ROUND(
        SUM(s.store_sales) * 100.0
        / SUM(SUM(s.store_sales)) OVER (), 2
    )                                       AS revenue_share_pct
FROM (
    SELECT * FROM sales_fact_1997
    UNION ALL
    SELECT * FROM sales_fact_1998
) s
JOIN customer c ON s.customer_id = c.customer_id
WHERE c.country IN ('USA', 'Canada', 'Mexico')
GROUP BY c.country
ORDER BY total_revenue DESC;


-- ══════════════════════════════════════════════════════════
--  SECTION 4 · REGIONAL
-- ══════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────
-- REGIONAL 01 · Which sales region generates the highest total revenue?
-- Chain: Sales → Stores → Region
-- ─────────────────────────────────────────────────────────
SELECT
    r.sales_region                          AS region_name,
    COUNT(DISTINCT st.store_id)             AS store_count,
    COUNT(*)                                AS total_transactions,
    ROUND(SUM(s.store_sales), 2)            AS total_revenue,
    ROUND(AVG(s.store_sales), 2)            AS avg_transaction_value
FROM (
    SELECT * FROM sales_fact_1997
    UNION ALL
    SELECT * FROM sales_fact_1998
) s
JOIN store st   ON s.store_id  = st.store_id
JOIN region r   ON st.region_id = r.region_id
GROUP BY r.sales_region
ORDER BY total_revenue DESC;


-- ─────────────────────────────────────────────────────────
-- REGIONAL 02 · Top performing store by revenue AND by transaction count
-- GROUP BY store_id, ORDER BY revenue
-- ─────────────────────────────────────────────────────────
SELECT
    st.store_id,
    st.store_name,
    st.store_city,
    st.store_state,
    r.sales_region                          AS region_name,
    COUNT(*)                                AS total_transactions,
    SUM(s.unit_sales)                       AS total_units_sold,
    ROUND(SUM(s.store_sales), 2)            AS total_revenue,
    ROUND(AVG(s.store_sales), 2)            AS avg_order_value,
    -- rank by revenue
    RANK() OVER (ORDER BY SUM(s.store_sales) DESC)   AS revenue_rank,
    -- rank by transactions
    RANK() OVER (ORDER BY COUNT(*) DESC)             AS transaction_rank
FROM (
    SELECT * FROM sales_fact_1997
    UNION ALL
    SELECT * FROM sales_fact_1998
) s
JOIN store st   ON s.store_id  = st.store_id
JOIN region r   ON st.region_id = r.region_id
GROUP BY st.store_id, st.store_name, st.store_city, st.store_state, r.sales_region
ORDER BY total_revenue DESC;


-- ─────────────────────────────────────────────────────────
-- REGIONAL 03 · Stores with the worst return rates — geographic clusters?
-- Chain: Returns → Stores → Region
-- ─────────────────────────────────────────────────────────
SELECT
    st.store_id,
    st.store_name,
    st.store_city,
    st.store_state,
    r.sales_region                          AS region_name,
    SUM(sales.unit_sales)                   AS total_units_sold,
    COALESCE(SUM(ret.units_returned), 0)    AS total_units_returned,
    ROUND(
        COALESCE(SUM(ret.units_returned), 0) * 100.0
        / NULLIF(SUM(sales.unit_sales), 0), 2
    )                                       AS return_rate_pct
FROM (
    SELECT * FROM sales_fact_1997
    UNION ALL
    SELECT * FROM sales_fact_1998
) sales
JOIN store st   ON sales.store_id = st.store_id
JOIN region r   ON st.region_id   = r.region_id
LEFT JOIN (
    SELECT store_id, SUM(units_returned) AS units_returned
    FROM returns
    GROUP BY store_id
) ret ON st.store_id = ret.store_id
GROUP BY st.store_id, st.store_name, st.store_city, st.store_state, r.sales_region
ORDER BY return_rate_pct DESC;


-- ─────────────────────────────────────────────────────────
-- REGIONAL 04 · Does store size (store_sqft) correlate with higher revenue?
-- Correlation: sqft vs revenue per store
-- ─────────────────────────────────────────────────────────
SELECT
    st.store_id,
    st.store_name,
    st.store_sqft                           AS total_sqft,
    ROUND(SUM(s.store_sales), 2)            AS total_revenue,
    ROUND(SUM(s.store_sales) / st.store_sqft, 4) AS revenue_per_sqft,
    -- Pearson correlation approximated via grouped data
    ROUND(AVG(s.store_sales), 2)            AS avg_transaction_value
FROM (
    SELECT * FROM sales_fact_1997
    UNION ALL
    SELECT * FROM sales_fact_1998
) s
JOIN store st ON s.store_id = st.store_id
WHERE st.store_sqft IS NOT NULL
GROUP BY st.store_id, st.store_name, st.store_sqft
ORDER BY total_revenue DESC;

-- Summary correlation view (high / medium / low sqft buckets):
SELECT
    CASE
        WHEN st.store_sqft >= 25000 THEN 'Large (≥25,000 sqft)'
        WHEN st.store_sqft >= 15000 THEN 'Medium (15,000–24,999 sqft)'
        ELSE                              'Small (<15,000 sqft)'
    END                                     AS store_size_category,
    COUNT(DISTINCT st.store_id)             AS store_count,
    ROUND(AVG(st.store_sqft), 0)            AS avg_sqft,
    ROUND(SUM(s.store_sales), 2)            AS total_revenue,
    ROUND(AVG(s.store_sales
          / st.store_sqft), 4)              AS avg_revenue_per_sqft
FROM (
    SELECT * FROM sales_fact_1997
    UNION ALL
    SELECT * FROM sales_fact_1998
) s
JOIN store st ON s.store_id = st.store_id
WHERE st.store_sqft IS NOT NULL
GROUP BY store_size_category
ORDER BY avg_revenue_per_sqft DESC;


-- ─────────────────────────────────────────────────────────
-- REGIONAL 05 · Which store type is most profitable?
-- (Supermarket vs Small Grocery vs Gourmet)
-- GROUP BY store_type
-- ─────────────────────────────────────────────────────────
SELECT
    st.store_type,
    COUNT(DISTINCT st.store_id)             AS store_count,
    COUNT(*)                                AS total_transactions,
    SUM(s.unit_sales)                       AS total_units_sold,
    ROUND(SUM(s.store_sales), 2)            AS total_revenue,
    ROUND(SUM(s.store_cost), 2)             AS total_cost,
    ROUND(SUM(s.store_sales)
          - SUM(s.store_cost), 2)           AS total_profit,
    ROUND(
        (SUM(s.store_sales) - SUM(s.store_cost))
        / SUM(s.store_sales) * 100, 2
    )                                       AS profit_margin_pct,
    ROUND(SUM(s.store_sales)
          / COUNT(DISTINCT st.store_id), 2) AS avg_revenue_per_store
FROM (
    SELECT * FROM sales_fact_1997
    UNION ALL
    SELECT * FROM sales_fact_1998
) s
JOIN store st ON s.store_id = st.store_id
GROUP BY st.store_type
ORDER BY total_profit DESC;


-- ══════════════════════════════════════════════════════════
--  SECTION 5 · RETURNS
-- ══════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────
-- RETURNS 01 · Total number of returns & overall return rate (both years)
-- KPI: Total Returns, Return Rate %
-- ─────────────────────────────────────────────────────────
SELECT
    SUM(s.unit_sales)                              AS total_units_sold,
    COALESCE(SUM(r.units_returned), 0)             AS total_units_returned,
    COUNT(*)                                       AS total_sale_transactions,
    ROUND(
        COALESCE(SUM(r.units_returned), 0) * 100.0
        / NULLIF(SUM(s.unit_sales), 0), 2
    )                                              AS overall_return_rate_pct
FROM (
    SELECT * FROM sales_fact_1997
    UNION ALL
    SELECT * FROM sales_fact_1998
) s
LEFT JOIN returns r ON s.product_id  = r.product_id
                    AND s.store_id   = r.store_id
                    AND s.time_id    = r.time_id;

-- By year breakdown:
SELECT
    t.the_year                                     AS sales_year,
    SUM(s.unit_sales)                              AS total_units_sold,
    COALESCE(SUM(r.units_returned), 0)             AS total_units_returned,
    ROUND(
        COALESCE(SUM(r.units_returned), 0) * 100.0
        / NULLIF(SUM(s.unit_sales), 0), 2
    )                                              AS return_rate_pct
FROM (
    SELECT * FROM sales_fact_1997
    UNION ALL
    SELECT * FROM sales_fact_1998
) s
JOIN time_by_day t ON s.time_id = t.time_id
LEFT JOIN returns r ON s.product_id = r.product_id
                    AND s.store_id  = r.store_id
                    AND s.time_id   = r.time_id
GROUP BY t.the_year
ORDER BY t.the_year;


-- ─────────────────────────────────────────────────────────
-- RETURNS 02 · Estimated revenue lost due to returns
-- KPI: Revenue lost = returned_qty × retail_price (avg unit price)
-- ─────────────────────────────────────────────────────────
SELECT
    SUM(r.units_returned)                                   AS total_units_returned,
    ROUND(AVG(s.store_sales / s.unit_sales), 4)             AS avg_unit_retail_price,
    ROUND(
        SUM(r.units_returned)
        * AVG(s.store_sales / s.unit_sales), 2
    )                                                       AS estimated_revenue_lost,
    ROUND(SUM(s.store_sales), 2)                            AS gross_revenue,
    ROUND(
        SUM(r.units_returned)
        * AVG(s.store_sales / s.unit_sales) * 100.0
        / NULLIF(SUM(s.store_sales), 0), 2
    )                                                       AS revenue_lost_pct
FROM (
    SELECT * FROM sales_fact_1997
    UNION ALL
    SELECT * FROM sales_fact_1998
) s
LEFT JOIN returns r ON s.product_id = r.product_id
                    AND s.store_id  = r.store_id
                    AND s.time_id   = r.time_id
WHERE r.units_returned IS NOT NULL;

-- By product category:
SELECT
    pc.product_family,
    pc.product_department,
    SUM(r.units_returned)                                   AS total_returned,
    ROUND(
        SUM(r.units_returned)
        * AVG(s.store_sales / s.unit_sales), 2
    )                                                       AS revenue_lost,
    ROUND(
        SUM(r.units_returned) * 100.0
        / NULLIF(SUM(s.unit_sales), 0), 2
    )                                                       AS return_rate_pct
FROM (
    SELECT * FROM sales_fact_1997
    UNION ALL
    SELECT * FROM sales_fact_1998
) s
JOIN product p          ON s.product_id          = p.product_id
JOIN product_class pc   ON p.product_class_id    = pc.product_class_id
LEFT JOIN returns r      ON s.product_id          = r.product_id
                         AND s.store_id           = r.store_id
                         AND s.time_id            = r.time_id
WHERE r.units_returned IS NOT NULL
GROUP BY pc.product_family, pc.product_department
ORDER BY revenue_lost DESC;


-- ################################################################
--  PART 2 · ENHANCED QUERIES  (Window Functions)
-- ################################################################

-- ================================================================
--   GRADUATION PROJECT — BUSINESS QUESTIONS SQL ANSWERS
--   ✦ Enhanced with Window Functions ✦
--   Schema: sales_fact_1997 | sales_fact_1998 | product |
--           customer | store | region | time_by_day | returns
--
--   Window Functions Used:
--     ROW_NUMBER()   RANK()         DENSE_RANK()
--     LAG()          LEAD()         NTILE()
--     SUM() OVER()   AVG() OVER()   COUNT() OVER()
--     FIRST_VALUE()  LAST_VALUE()   PERCENT_RANK()
--     CUME_DIST()    RUNNING TOTALS  MOVING AVERAGES
-- ================================================================


-- ══════════════════════════════════════════════════════════════
--  SECTION 1 · SALES
-- ══════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────
-- SALES 01 · Total revenue per year (1997 vs 1998)
-- Window: LAG() to compare with previous year + running total
-- ──────────────────────────────────────────────────────────────
WITH yearly AS (
    SELECT
        t.the_year                           AS sales_year,
        COUNT(DISTINCT s.customer_id)        AS total_customers,
        SUM(s.unit_sales)                    AS total_units_sold,
        ROUND(SUM(s.store_sales), 2)         AS total_revenue
    FROM (
        SELECT * FROM sales_fact_1997
        UNION ALL
        SELECT * FROM sales_fact_1998
    ) s
    JOIN time_by_day t ON s.time_id = t.time_id
    GROUP BY t.the_year
)
SELECT
    sales_year,
    total_customers,
    total_units_sold,
    total_revenue,

    -- ▶ LAG: previous year's revenue for direct comparison
    LAG(total_revenue) OVER (ORDER BY sales_year)            AS prev_year_revenue,

    -- ▶ Revenue growth vs previous year
    ROUND(
        total_revenue
        - LAG(total_revenue) OVER (ORDER BY sales_year), 2
    )                                                        AS revenue_change,

    -- ▶ YoY growth %
    ROUND(
        (total_revenue - LAG(total_revenue) OVER (ORDER BY sales_year))
        / NULLIF(LAG(total_revenue) OVER (ORDER BY sales_year), 0) * 100, 2
    )                                                        AS yoy_growth_pct,

    -- ▶ Running cumulative revenue across years
    SUM(total_revenue) OVER (ORDER BY sales_year
                             ROWS BETWEEN UNBOUNDED PRECEDING
                             AND CURRENT ROW)                AS cumulative_revenue

FROM yearly
ORDER BY sales_year;


-- ──────────────────────────────────────────────────────────────
-- SALES 02 · Month with the highest average revenue + seasonal pattern
-- Window: RANK() on monthly revenue + 3-month moving average
-- ──────────────────────────────────────────────────────────────
WITH monthly AS (
    SELECT
        t.the_year,
        t.month_of_year,
        t.the_month                          AS month_name,
        ROUND(SUM(s.store_sales), 2)         AS monthly_revenue,
        COUNT(*)                             AS total_transactions
    FROM (
        SELECT * FROM sales_fact_1997
        UNION ALL
        SELECT * FROM sales_fact_1998
    ) s
    JOIN time_by_day t ON s.time_id = t.time_id
    GROUP BY t.the_year, t.month_of_year, t.the_month
)
SELECT
    the_year,
    month_of_year,
    month_name,
    monthly_revenue,
    total_transactions,

    -- ▶ RANK: best revenue month within each year
    RANK() OVER (PARTITION BY the_year
                 ORDER BY monthly_revenue DESC)              AS revenue_rank_in_year,

    -- ▶ Overall rank across all months and years
    RANK() OVER (ORDER BY monthly_revenue DESC)              AS overall_revenue_rank,

    -- ▶ 3-month moving average (smooths seasonal noise)
    ROUND(AVG(monthly_revenue) OVER (
        PARTITION BY the_year
        ORDER BY month_of_year
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2)                                                    AS moving_avg_3month,

    -- ▶ Revenue share within that year
    ROUND(
        monthly_revenue * 100.0
        / SUM(monthly_revenue) OVER (PARTITION BY the_year), 2
    )                                                        AS pct_of_year_revenue,

    -- ▶ Difference from year's monthly average
    ROUND(
        monthly_revenue
        - AVG(monthly_revenue) OVER (PARTITION BY the_year), 2
    )                                                        AS diff_from_avg,

    -- ▶ Running cumulative revenue within each year
    SUM(monthly_revenue) OVER (
        PARTITION BY the_year
        ORDER BY month_of_year
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                        AS ytd_revenue

FROM monthly
ORDER BY the_year, month_of_year;


-- ──────────────────────────────────────────────────────────────
-- SALES 03 · Year-over-Year revenue growth % (1997 → 1998)
-- Window: LAG() + LEAD() on yearly totals
-- ──────────────────────────────────────────────────────────────
WITH yearly AS (
    SELECT
        t.the_year,
        ROUND(SUM(s.store_sales), 2)         AS total_revenue,
        COUNT(*)                             AS total_transactions,
        SUM(s.unit_sales)                    AS total_units
    FROM (
        SELECT * FROM sales_fact_1997
        UNION ALL
        SELECT * FROM sales_fact_1998
    ) s
    JOIN time_by_day t ON s.time_id = t.time_id
    GROUP BY t.the_year
)
SELECT
    the_year,
    total_revenue,
    total_transactions,
    total_units,

    -- ▶ LAG: prior year revenue
    LAG(total_revenue)  OVER (ORDER BY the_year)             AS prior_year_revenue,

    -- ▶ LEAD: next year revenue (forward-looking)
    LEAD(total_revenue) OVER (ORDER BY the_year)             AS next_year_revenue,

    -- ▶ Absolute growth
    ROUND(
        total_revenue
        - LAG(total_revenue) OVER (ORDER BY the_year), 2
    )                                                        AS revenue_growth,

    -- ▶ YoY Growth %
    ROUND(
        (total_revenue - LAG(total_revenue) OVER (ORDER BY the_year))
        / NULLIF(LAG(total_revenue) OVER (ORDER BY the_year), 0) * 100, 2
    )                                                        AS yoy_growth_pct,

    -- ▶ Share of total revenue across both years
    ROUND(
        total_revenue * 100.0
        / SUM(total_revenue) OVER (), 2
    )                                                        AS revenue_share_pct

FROM yearly
ORDER BY the_year;


-- ──────────────────────────────────────────────────────────────
-- SALES 04 · Transactions per quarter
-- Window: RANK() within year + LAG() for quarter-over-quarter growth
-- ──────────────────────────────────────────────────────────────
WITH quarterly AS (
    SELECT
        t.the_year,
        t.quarter,
        COUNT(*)                             AS total_transactions,
        SUM(s.unit_sales)                    AS total_units,
        ROUND(SUM(s.store_sales), 2)         AS quarterly_revenue
    FROM (
        SELECT * FROM sales_fact_1997
        UNION ALL
        SELECT * FROM sales_fact_1998
    ) s
    JOIN time_by_day t ON s.time_id = t.time_id
    GROUP BY t.the_year, t.quarter
)
SELECT
    the_year,
    quarter,
    total_transactions,
    total_units,
    quarterly_revenue,

    -- ▶ RANK: best quarter within each year
    RANK() OVER (PARTITION BY the_year
                 ORDER BY quarterly_revenue DESC)            AS quarter_rank,

    -- ▶ LAG: same quarter in previous year (QoQ same-period)
    LAG(quarterly_revenue) OVER (
        PARTITION BY quarter ORDER BY the_year
    )                                                        AS same_qtr_prev_year,

    -- ▶ Quarter-over-quarter growth % (same quarter YoY)
    ROUND(
        (quarterly_revenue
         - LAG(quarterly_revenue) OVER (PARTITION BY quarter ORDER BY the_year))
        / NULLIF(
            LAG(quarterly_revenue) OVER (PARTITION BY quarter ORDER BY the_year)
          , 0) * 100, 2
    )                                                        AS qtr_yoy_growth_pct,

    -- ▶ Running total within each year
    SUM(quarterly_revenue) OVER (
        PARTITION BY the_year
        ORDER BY quarter
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                        AS ytd_revenue,

    -- ▶ Quarter's share of annual revenue
    ROUND(
        quarterly_revenue * 100.0
        / SUM(quarterly_revenue) OVER (PARTITION BY the_year), 2
    )                                                        AS pct_of_annual_revenue

FROM quarterly
ORDER BY the_year, quarter;


-- ──────────────────────────────────────────────────────────────
-- SALES 05 · AOV overall and by store
-- Window: RANK() + comparison to global average
-- ──────────────────────────────────────────────────────────────
WITH store_aov AS (
    SELECT
        s.store_id,
        st.store_name,
        st.store_city,
        COUNT(*)                             AS total_orders,
        ROUND(SUM(s.store_sales), 2)         AS total_revenue,
        ROUND(SUM(s.store_sales)
              / COUNT(*), 2)                 AS aov
    FROM (
        SELECT * FROM sales_fact_1997
        UNION ALL
        SELECT * FROM sales_fact_1998
    ) s
    JOIN store st ON s.store_id = st.store_id
    GROUP BY s.store_id, st.store_name, st.store_city
)
SELECT
    store_id,
    store_name,
    store_city,
    total_orders,
    total_revenue,
    aov,

    -- ▶ RANK by AOV
    RANK() OVER (ORDER BY aov DESC)                          AS aov_rank,

    -- ▶ RANK by total revenue
    RANK() OVER (ORDER BY total_revenue DESC)                AS revenue_rank,

    -- ▶ Global average AOV for reference
    ROUND(AVG(aov) OVER (), 2)                               AS global_avg_aov,

    -- ▶ How much above/below global average
    ROUND(aov - AVG(aov) OVER (), 2)                         AS aov_vs_global_avg,

    -- ▶ Cumulative revenue (ranked by AOV)
    SUM(total_revenue) OVER (
        ORDER BY aov DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                        AS cumulative_revenue,

    -- ▶ NTILE: split stores into 4 performance tiers by AOV
    NTILE(4) OVER (ORDER BY aov DESC)                        AS aov_quartile

FROM store_aov
ORDER BY aov DESC;


-- ══════════════════════════════════════════════════════════════
--  SECTION 2 · PRODUCT
-- ══════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────
-- PRODUCT 01 · Top 10 products by total revenue
-- Window: ROW_NUMBER(), PERCENT_RANK(), cumulative revenue share
-- ──────────────────────────────────────────────────────────────
WITH product_revenue AS (
    SELECT
        p.product_id,
        p.product_name,
        p.brand_name,
        ROUND(SUM(s.store_sales), 2)         AS total_revenue,
        SUM(s.unit_sales)                    AS total_units_sold,
        ROUND(SUM(s.store_sales)
              - SUM(s.store_cost), 2)        AS total_profit
    FROM (
        SELECT * FROM sales_fact_1997
        UNION ALL
        SELECT * FROM sales_fact_1998
    ) s
    JOIN product p ON s.product_id = p.product_id
    GROUP BY p.product_id, p.product_name, p.brand_name
)
SELECT
    product_id,
    product_name,
    brand_name,
    total_revenue,
    total_units_sold,
    total_profit,

    -- ▶ ROW_NUMBER: strict ranking by revenue
    ROW_NUMBER() OVER (ORDER BY total_revenue DESC)          AS revenue_row_num,

    -- ▶ RANK: handles ties in revenue
    RANK() OVER (ORDER BY total_revenue DESC)                AS revenue_rank,

    -- ▶ DENSE_RANK: no gaps in rank sequence
    DENSE_RANK() OVER (ORDER BY total_revenue DESC)          AS dense_rank,

    -- ▶ PERCENT_RANK: where this product sits percentile-wise
    ROUND(PERCENT_RANK() OVER (ORDER BY total_revenue), 4)   AS percent_rank,

    -- ▶ CUME_DIST: cumulative distribution
    ROUND(CUME_DIST() OVER (ORDER BY total_revenue), 4)      AS cume_dist,

    -- ▶ Running % of total revenue (top products' contribution)
    ROUND(
        SUM(total_revenue) OVER (
            ORDER BY total_revenue DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) * 100.0 / SUM(total_revenue) OVER (), 2
    )                                                        AS cumulative_revenue_pct

FROM product_revenue
ORDER BY revenue_rank
LIMIT 10;


-- ──────────────────────────────────────────────────────────────
-- PRODUCT 02 · Brands with highest profit margin
-- Window: RANK() within brand + brand vs overall average margin
-- ──────────────────────────────────────────────────────────────
WITH brand_profit AS (
    SELECT
        p.brand_name,
        ROUND(SUM(s.store_sales), 2)         AS total_revenue,
        ROUND(SUM(s.store_cost), 2)          AS total_cost,
        ROUND(SUM(s.store_sales)
              - SUM(s.store_cost), 2)        AS total_profit,
        ROUND(
            (SUM(s.store_sales) - SUM(s.store_cost))
            / SUM(s.store_sales) * 100, 2
        )                                    AS profit_margin_pct
    FROM (
        SELECT * FROM sales_fact_1997
        UNION ALL
        SELECT * FROM sales_fact_1998
    ) s
    JOIN product p ON s.product_id = p.product_id
    GROUP BY p.brand_name
)
SELECT
    brand_name,
    total_revenue,
    total_cost,
    total_profit,
    profit_margin_pct,

    -- ▶ RANK by profit margin
    RANK() OVER (ORDER BY profit_margin_pct DESC)            AS margin_rank,

    -- ▶ RANK by absolute profit
    RANK() OVER (ORDER BY total_profit DESC)                 AS profit_rank,

    -- ▶ Average margin across ALL brands (global benchmark)
    ROUND(AVG(profit_margin_pct) OVER (), 2)                 AS avg_margin_all_brands,

    -- ▶ How much this brand beats/lags the average
    ROUND(profit_margin_pct
          - AVG(profit_margin_pct) OVER (), 2)               AS margin_vs_avg,

    -- ▶ NTILE: categorise brands into performance quartiles
    NTILE(4) OVER (ORDER BY profit_margin_pct DESC)          AS margin_quartile,

    -- ▶ Revenue share of this brand vs all brands
    ROUND(
        total_revenue * 100.0
        / SUM(total_revenue) OVER (), 2
    )                                                        AS revenue_share_pct

FROM brand_profit
ORDER BY margin_rank;


-- ──────────────────────────────────────────────────────────────
-- PRODUCT 03 · Products with highest return rate & net revenue impact
-- Window: RANK() on return rate + FIRST_VALUE() for worst offender
-- ──────────────────────────────────────────────────────────────
WITH product_returns AS (
    SELECT
        p.product_id,
        p.product_name,
        p.brand_name,
        SUM(s.unit_sales)                                    AS total_sold,
        COALESCE(SUM(r.units_returned), 0)                   AS total_returned,
        ROUND(SUM(s.store_sales), 2)                         AS gross_revenue,
        ROUND(
            COALESCE(SUM(r.units_returned), 0)
            * AVG(s.store_sales / NULLIF(s.unit_sales, 0)), 2
        )                                                    AS revenue_lost,
        ROUND(
            COALESCE(SUM(r.units_returned), 0) * 100.0
            / NULLIF(SUM(s.unit_sales), 0), 2
        )                                                    AS return_rate_pct
    FROM (
        SELECT * FROM sales_fact_1997
        UNION ALL
        SELECT * FROM sales_fact_1998
    ) s
    JOIN product p ON s.product_id = p.product_id
    LEFT JOIN (
        SELECT product_id, SUM(units_returned) AS units_returned
        FROM returns GROUP BY product_id
    ) r ON p.product_id = r.product_id
    GROUP BY p.product_id, p.product_name, p.brand_name
)
SELECT
    product_id,
    product_name,
    brand_name,
    total_sold,
    total_returned,
    gross_revenue,
    revenue_lost,
    return_rate_pct,

    -- ▶ RANK by return rate (worst first)
    RANK() OVER (ORDER BY return_rate_pct DESC)              AS return_rate_rank,

    -- ▶ RANK by absolute revenue lost
    RANK() OVER (ORDER BY revenue_lost DESC)                 AS revenue_lost_rank,

    -- ▶ Average return rate across all products
    ROUND(AVG(return_rate_pct) OVER (), 2)                   AS avg_return_rate,

    -- ▶ FIRST_VALUE: name of product with the highest return rate
    FIRST_VALUE(product_name) OVER (
        ORDER BY return_rate_pct DESC
    )                                                        AS worst_return_product,

    -- ▶ Cumulative revenue lost (running total, worst first)
    SUM(revenue_lost) OVER (
        ORDER BY revenue_lost DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                        AS cumulative_revenue_lost,

    -- ▶ Net revenue after returns
    ROUND(gross_revenue - revenue_lost, 2)                   AS net_revenue

FROM product_returns
ORDER BY return_rate_rank
LIMIT 20;


-- ──────────────────────────────────────────────────────────────
-- PRODUCT 04 · Low-fat / recyclable product segment analysis
-- Window: RANK() by segment + share of total revenue
-- ──────────────────────────────────────────────────────────────
WITH segments AS (
    SELECT
        p.low_fat,
        p.recyclable_package,
        COUNT(DISTINCT p.product_id)         AS product_count,
        SUM(s.unit_sales)                    AS total_units_sold,
        ROUND(SUM(s.store_sales), 2)         AS total_revenue,
        ROUND(AVG(s.store_sales), 2)         AS avg_sale_value
    FROM (
        SELECT * FROM sales_fact_1997
        UNION ALL
        SELECT * FROM sales_fact_1998
    ) s
    JOIN product p ON s.product_id = p.product_id
    GROUP BY p.low_fat, p.recyclable_package
)
SELECT
    CASE WHEN low_fat          = 1 THEN 'Low-Fat'     ELSE 'Regular'      END AS fat_type,
    CASE WHEN recyclable_package = 1 THEN 'Recyclable' ELSE 'Non-Recyclable' END AS packaging,
    product_count,
    total_units_sold,
    total_revenue,
    avg_sale_value,

    -- ▶ RANK by total revenue
    RANK() OVER (ORDER BY total_revenue DESC)                AS revenue_rank,

    -- ▶ Revenue share of each segment vs all segments
    ROUND(
        total_revenue * 100.0
        / SUM(total_revenue) OVER (), 2
    )                                                        AS revenue_share_pct,

    -- ▶ Units share
    ROUND(
        total_units_sold * 100.0
        / SUM(total_units_sold) OVER (), 2
    )                                                        AS units_share_pct,

    -- ▶ Avg revenue vs grand avg
    ROUND(
        avg_sale_value - AVG(avg_sale_value) OVER (), 2
    )                                                        AS avg_vs_grand_avg

FROM segments
ORDER BY revenue_rank;


-- ══════════════════════════════════════════════════════════════
--  SECTION 3 · CUSTOMER
-- ══════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────
-- CUSTOMER 01 · Income brackets driving the most revenue
-- Window: RANK() + NTILE() income tiers + cumulative revenue
-- ──────────────────────────────────────────────────────────────
WITH income_rev AS (
    SELECT
        c.yearly_income,
        COUNT(DISTINCT s.customer_id)        AS total_customers,
        COUNT(*)                             AS total_transactions,
        ROUND(SUM(s.store_sales), 2)         AS total_revenue,
        ROUND(AVG(s.store_sales), 2)         AS avg_spend
    FROM (
        SELECT * FROM sales_fact_1997
        UNION ALL
        SELECT * FROM sales_fact_1998
    ) s
    JOIN customer c ON s.customer_id = c.customer_id
    GROUP BY c.yearly_income
)
SELECT
    yearly_income,
    total_customers,
    total_transactions,
    total_revenue,
    avg_spend,

    -- ▶ RANK by revenue
    RANK() OVER (ORDER BY total_revenue DESC)                AS revenue_rank,

    -- ▶ Revenue share per income bracket
    ROUND(
        total_revenue * 100.0
        / SUM(total_revenue) OVER (), 2
    )                                                        AS revenue_share_pct,

    -- ▶ Cumulative revenue (Pareto view)
    SUM(total_revenue) OVER (
        ORDER BY total_revenue DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                        AS cumulative_revenue,

    -- ▶ Cumulative % of total revenue
    ROUND(
        SUM(total_revenue) OVER (
            ORDER BY total_revenue DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) * 100.0 / SUM(total_revenue) OVER (), 2
    )                                                        AS cumulative_pct,

    -- ▶ Average spend vs overall customer average
    ROUND(avg_spend - AVG(avg_spend) OVER (), 2)             AS spend_vs_overall_avg

FROM income_rev
ORDER BY revenue_rank;


-- ──────────────────────────────────────────────────────────────
-- CUSTOMER 02 · Revenue by loyalty card tier
-- Window: RANK() + share + avg spend deviation per tier
-- ──────────────────────────────────────────────────────────────
WITH loyalty AS (
    SELECT
        c.member_card,
        COUNT(DISTINCT s.customer_id)        AS total_customers,
        COUNT(*)                             AS total_transactions,
        ROUND(SUM(s.store_sales), 2)         AS total_revenue,
        ROUND(AVG(s.store_sales), 2)         AS avg_transaction_value
    FROM (
        SELECT * FROM sales_fact_1997
        UNION ALL
        SELECT * FROM sales_fact_1998
    ) s
    JOIN customer c ON s.customer_id = c.customer_id
    GROUP BY c.member_card
)
SELECT
    member_card                                              AS loyalty_tier,
    total_customers,
    total_transactions,
    total_revenue,
    avg_transaction_value,

    -- ▶ RANK by revenue
    RANK() OVER (ORDER BY total_revenue DESC)                AS tier_revenue_rank,

    -- ▶ Revenue share per tier
    ROUND(
        total_revenue * 100.0
        / SUM(total_revenue) OVER (), 2
    )                                                        AS revenue_share_pct,

    -- ▶ Customer share per tier
    ROUND(
        total_customers * 100.0
        / SUM(total_customers) OVER (), 2
    )                                                        AS customer_share_pct,

    -- ▶ Revenue per customer (loyalty ROI)
    ROUND(total_revenue / NULLIF(total_customers, 0), 2)     AS revenue_per_customer,

    -- ▶ How each tier's avg spend compares to the global avg
    ROUND(
        avg_transaction_value
        - AVG(avg_transaction_value) OVER (), 2
    )                                                        AS avg_spend_vs_global,

    -- ▶ Best-performing tier name (same for all rows — reference)
    FIRST_VALUE(member_card) OVER (
        ORDER BY total_revenue DESC
    )                                                        AS top_tier

FROM loyalty
ORDER BY tier_revenue_rank;


-- ──────────────────────────────────────────────────────────────
-- CUSTOMER 03 · Gender-based purchasing behaviour & avg spend
-- Window: RANK() + % share + per-customer spend comparison
-- ──────────────────────────────────────────────────────────────
WITH gender_stats AS (
    SELECT
        c.gender,
        COUNT(DISTINCT s.customer_id)        AS total_customers,
        COUNT(*)                             AS total_transactions,
        SUM(s.unit_sales)                    AS total_units,
        ROUND(SUM(s.store_sales), 2)         AS total_revenue,
        ROUND(AVG(s.store_sales), 2)         AS avg_spend_per_txn
    FROM (
        SELECT * FROM sales_fact_1997
        UNION ALL
        SELECT * FROM sales_fact_1998
    ) s
    JOIN customer c ON s.customer_id = c.customer_id
    GROUP BY c.gender
)
SELECT
    gender,
    total_customers,
    total_transactions,
    total_units,
    total_revenue,
    avg_spend_per_txn,

    -- ▶ Revenue per customer
    ROUND(total_revenue / NULLIF(total_customers, 0), 2)     AS revenue_per_customer,

    -- ▶ Transactions per customer
    ROUND(total_transactions * 1.0
          / NULLIF(total_customers, 0), 2)                   AS txns_per_customer,

    -- ▶ Revenue share by gender
    ROUND(
        total_revenue * 100.0
        / SUM(total_revenue) OVER (), 2
    )                                                        AS revenue_share_pct,

    -- ▶ RANK by revenue
    RANK() OVER (ORDER BY total_revenue DESC)                AS revenue_rank,

    -- ▶ Difference in avg spend between genders
    ROUND(
        avg_spend_per_txn
        - AVG(avg_spend_per_txn) OVER (), 2
    )                                                        AS spend_diff_from_avg

FROM gender_stats
ORDER BY revenue_rank;


-- ──────────────────────────────────────────────────────────────
-- CUSTOMER 04 · Countries contributing the most customers & revenue
-- Window: RANK() + CUME_DIST() + cumulative revenue
-- ──────────────────────────────────────────────────────────────
WITH country_stats AS (
    SELECT
        c.country,
        COUNT(DISTINCT c.customer_id)        AS total_customers,
        COUNT(*)                             AS total_transactions,
        ROUND(SUM(s.store_sales), 2)         AS total_revenue,
        ROUND(AVG(s.store_sales), 2)         AS avg_spend
    FROM (
        SELECT * FROM sales_fact_1997
        UNION ALL
        SELECT * FROM sales_fact_1998
    ) s
    JOIN customer c ON s.customer_id = c.customer_id
    WHERE c.country IN ('USA', 'Canada', 'Mexico')
    GROUP BY c.country
)
SELECT
    country,
    total_customers,
    total_transactions,
    total_revenue,
    avg_spend,

    -- ▶ RANK by revenue
    RANK() OVER (ORDER BY total_revenue DESC)                AS revenue_rank,

    -- ▶ RANK by customer count
    RANK() OVER (ORDER BY total_customers DESC)              AS customer_rank,

    -- ▶ Revenue share per country
    ROUND(
        total_revenue * 100.0
        / SUM(total_revenue) OVER (), 2
    )                                                        AS revenue_share_pct,

    -- ▶ Customer share per country
    ROUND(
        total_customers * 100.0
        / SUM(total_customers) OVER (), 2
    )                                                        AS customer_share_pct,

    -- ▶ CUME_DIST: cumulative % of countries ranked by revenue
    ROUND(CUME_DIST() OVER (ORDER BY total_revenue), 4)      AS cume_dist,

    -- ▶ Revenue per customer
    ROUND(total_revenue / NULLIF(total_customers, 0), 2)     AS revenue_per_customer

FROM country_stats
ORDER BY revenue_rank;


-- ══════════════════════════════════════════════════════════════
--  SECTION 4 · REGIONAL
-- ══════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────
-- REGIONAL 01 · Which region generates the highest total revenue?
-- Window: RANK() + revenue share + avg per store in region
-- ──────────────────────────────────────────────────────────────
WITH region_stats AS (
    SELECT
        r.sales_region,
        COUNT(DISTINCT st.store_id)          AS store_count,
        COUNT(*)                             AS total_transactions,
        ROUND(SUM(s.store_sales), 2)         AS total_revenue,
        ROUND(AVG(s.store_sales), 2)         AS avg_transaction_value
    FROM (
        SELECT * FROM sales_fact_1997
        UNION ALL
        SELECT * FROM sales_fact_1998
    ) s
    JOIN store st  ON s.store_id  = st.store_id
    JOIN region r  ON st.region_id = r.region_id
    GROUP BY r.sales_region
)
SELECT
    sales_region,
    store_count,
    total_transactions,
    total_revenue,
    avg_transaction_value,

    -- ▶ RANK by revenue
    RANK() OVER (ORDER BY total_revenue DESC)                AS region_revenue_rank,

    -- ▶ Revenue share per region
    ROUND(
        total_revenue * 100.0
        / SUM(total_revenue) OVER (), 2
    )                                                        AS revenue_share_pct,

    -- ▶ Average revenue per store in region
    ROUND(total_revenue / NULLIF(store_count, 0), 2)         AS avg_revenue_per_store,

    -- ▶ Cumulative revenue (Pareto: which regions cover 80%?)
    SUM(total_revenue) OVER (
        ORDER BY total_revenue DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                        AS cumulative_revenue,

    -- ▶ Top region name for reference (same in all rows)
    FIRST_VALUE(sales_region) OVER (
        ORDER BY total_revenue DESC
    )                                                        AS top_region

FROM region_stats
ORDER BY region_revenue_rank;


-- ──────────────────────────────────────────────────────────────
-- REGIONAL 02 · Top store by revenue AND transaction count
-- Window: RANK() + DENSE_RANK() + performance vs regional avg
-- ──────────────────────────────────────────────────────────────
WITH store_stats AS (
    SELECT
        st.store_id,
        st.store_name,
        st.store_city,
        st.store_state,
        r.sales_region,
        COUNT(*)                             AS total_transactions,
        ROUND(SUM(s.store_sales), 2)         AS total_revenue,
        ROUND(AVG(s.store_sales), 2)         AS avg_order_value
    FROM (
        SELECT * FROM sales_fact_1997
        UNION ALL
        SELECT * FROM sales_fact_1998
    ) s
    JOIN store st  ON s.store_id  = st.store_id
    JOIN region r  ON st.region_id = r.region_id
    GROUP BY st.store_id, st.store_name, st.store_city, st.store_state, r.sales_region
)
SELECT
    store_id,
    store_name,
    store_city,
    store_state,
    sales_region,
    total_transactions,
    total_revenue,
    avg_order_value,

    -- ▶ Global revenue rank
    RANK()       OVER (ORDER BY total_revenue DESC)          AS global_revenue_rank,

    -- ▶ Revenue rank within each region
    RANK()       OVER (PARTITION BY sales_region
                       ORDER BY total_revenue DESC)          AS regional_revenue_rank,

    -- ▶ Global transaction rank
    RANK()       OVER (ORDER BY total_transactions DESC)     AS global_txn_rank,

    -- ▶ DENSE_RANK to avoid gaps
    DENSE_RANK() OVER (ORDER BY total_revenue DESC)          AS dense_revenue_rank,

    -- ▶ Revenue vs average of its own region
    ROUND(
        total_revenue
        - AVG(total_revenue) OVER (PARTITION BY sales_region), 2
    )                                                        AS vs_region_avg,

    -- ▶ Store's revenue share within its region
    ROUND(
        total_revenue * 100.0
        / SUM(total_revenue) OVER (PARTITION BY sales_region), 2
    )                                                        AS region_revenue_share_pct,

    -- ▶ NTILE: classify stores into performance quartiles globally
    NTILE(4) OVER (ORDER BY total_revenue DESC)              AS performance_quartile

FROM store_stats
ORDER BY global_revenue_rank;


-- ──────────────────────────────────────────────────────────────
-- REGIONAL 03 · Stores with worst return rates + geographic clusters
-- Window: RANK() return rate globally + within region
-- ──────────────────────────────────────────────────────────────
WITH store_returns AS (
    SELECT
        st.store_id,
        st.store_name,
        st.store_city,
        st.store_state,
        r.sales_region,
        SUM(s.unit_sales)                    AS total_units_sold,
        COALESCE(SUM(ret.units_returned), 0) AS total_returned,
        ROUND(SUM(s.store_sales), 2)         AS total_revenue,
        ROUND(
            COALESCE(SUM(ret.units_returned), 0) * 100.0
            / NULLIF(SUM(s.unit_sales), 0), 2
        )                                    AS return_rate_pct
    FROM (
        SELECT * FROM sales_fact_1997
        UNION ALL
        SELECT * FROM sales_fact_1998
    ) s
    JOIN store st  ON s.store_id  = st.store_id
    JOIN region r  ON st.region_id = r.region_id
    LEFT JOIN (
        SELECT store_id, SUM(units_returned) AS units_returned
        FROM returns GROUP BY store_id
    ) ret ON st.store_id = ret.store_id
    GROUP BY st.store_id, st.store_name, st.store_city, st.store_state, r.sales_region
)
SELECT
    store_id,
    store_name,
    store_city,
    store_state,
    sales_region,
    total_units_sold,
    total_returned,
    total_revenue,
    return_rate_pct,

    -- ▶ Global rank by return rate (worst first)
    RANK() OVER (ORDER BY return_rate_pct DESC)              AS global_return_rank,

    -- ▶ Within-region rank by return rate
    RANK() OVER (PARTITION BY sales_region
                 ORDER BY return_rate_pct DESC)              AS regional_return_rank,

    -- ▶ Regional average return rate (detect clusters)
    ROUND(
        AVG(return_rate_pct) OVER (PARTITION BY sales_region), 2
    )                                                        AS region_avg_return_rate,

    -- ▶ How much worse/better vs the region average
    ROUND(
        return_rate_pct
        - AVG(return_rate_pct) OVER (PARTITION BY sales_region), 2
    )                                                        AS vs_region_avg_return,

    -- ▶ NTILE: group stores into return-rate risk tiers
    NTILE(4) OVER (ORDER BY return_rate_pct DESC)            AS return_risk_tier

FROM store_returns
ORDER BY global_return_rank;


-- ──────────────────────────────────────────────────────────────
-- REGIONAL 04 · Does store size (sqft) correlate with revenue?
-- Window: RANK() + revenue per sqft + size percentile
-- ──────────────────────────────────────────────────────────────
WITH store_sqft AS (
    SELECT
        st.store_id,
        st.store_name,
        st.store_sqft,
        ROUND(SUM(s.store_sales), 2)         AS total_revenue,
        ROUND(SUM(s.store_sales)
              / NULLIF(st.store_sqft, 0), 4) AS revenue_per_sqft
    FROM (
        SELECT * FROM sales_fact_1997
        UNION ALL
        SELECT * FROM sales_fact_1998
    ) s
    JOIN store st ON s.store_id = st.store_id
    WHERE st.store_sqft IS NOT NULL
    GROUP BY st.store_id, st.store_name, st.store_sqft
)
SELECT
    store_id,
    store_name,
    store_sqft,
    total_revenue,
    revenue_per_sqft,

    -- ▶ RANK by sqft (largest store)
    RANK() OVER (ORDER BY store_sqft DESC)                   AS size_rank,

    -- ▶ RANK by total revenue
    RANK() OVER (ORDER BY total_revenue DESC)                AS revenue_rank,

    -- ▶ RANK by efficiency (revenue per sqft)
    RANK() OVER (ORDER BY revenue_per_sqft DESC)             AS efficiency_rank,

    -- ▶ PERCENT_RANK: size percentile
    ROUND(PERCENT_RANK() OVER (ORDER BY store_sqft), 4)      AS size_percentile,

    -- ▶ Average revenue per sqft across all stores
    ROUND(AVG(revenue_per_sqft) OVER (), 4)                  AS avg_revenue_per_sqft,

    -- ▶ Whether this store is above/below average efficiency
    ROUND(revenue_per_sqft
          - AVG(revenue_per_sqft) OVER (), 4)                AS efficiency_vs_avg,

    -- ▶ NTILE: store size quartiles (Q1=smallest, Q4=largest)
    NTILE(4) OVER (ORDER BY store_sqft)                      AS size_quartile

FROM store_sqft
ORDER BY revenue_rank;


-- ──────────────────────────────────────────────────────────────
-- REGIONAL 05 · Most profitable store type
-- Window: RANK() + profit share + avg per store type
-- ──────────────────────────────────────────────────────────────
WITH type_profit AS (
    SELECT
        st.store_type,
        COUNT(DISTINCT st.store_id)          AS store_count,
        COUNT(*)                             AS total_transactions,
        ROUND(SUM(s.store_sales), 2)         AS total_revenue,
        ROUND(SUM(s.store_cost), 2)          AS total_cost,
        ROUND(SUM(s.store_sales)
              - SUM(s.store_cost), 2)        AS total_profit,
        ROUND(
            (SUM(s.store_sales) - SUM(s.store_cost))
            / SUM(s.store_sales) * 100, 2
        )                                    AS profit_margin_pct
    FROM (
        SELECT * FROM sales_fact_1997
        UNION ALL
        SELECT * FROM sales_fact_1998
    ) s
    JOIN store st ON s.store_id = st.store_id
    GROUP BY st.store_type
)
SELECT
    store_type,
    store_count,
    total_transactions,
    total_revenue,
    total_cost,
    total_profit,
    profit_margin_pct,

    -- ▶ RANK by profit
    RANK() OVER (ORDER BY total_profit DESC)                 AS profit_rank,

    -- ▶ RANK by margin %
    RANK() OVER (ORDER BY profit_margin_pct DESC)            AS margin_rank,

    -- ▶ Profit share vs all store types
    ROUND(
        total_profit * 100.0
        / SUM(total_profit) OVER (), 2
    )                                                        AS profit_share_pct,

    -- ▶ Revenue per store within each type
    ROUND(total_revenue / NULLIF(store_count, 0), 2)         AS avg_revenue_per_store,

    -- ▶ Avg revenue per store vs grand avg
    ROUND(
        total_revenue / NULLIF(store_count, 0)
        - AVG(total_revenue / NULLIF(store_count, 0)) OVER (), 2
    )                                                        AS efficiency_vs_avg,

    -- ▶ Best store type (reference column)
    FIRST_VALUE(store_type) OVER (
        ORDER BY total_profit DESC
    )                                                        AS top_store_type

FROM type_profit
ORDER BY profit_rank;


-- ══════════════════════════════════════════════════════════════
--  SECTION 5 · RETURNS
-- ══════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────
-- RETURNS 01 · Total returns & overall return rate (both years)
-- Window: LAG() for year comparison + running return rate
-- ──────────────────────────────────────────────────────────────
WITH yearly_returns AS (
    SELECT
        t.the_year,
        SUM(s.unit_sales)                    AS total_units_sold,
        COALESCE(SUM(r.units_returned), 0)   AS total_returned,
        COUNT(*)                             AS total_transactions,
        ROUND(
            COALESCE(SUM(r.units_returned), 0) * 100.0
            / NULLIF(SUM(s.unit_sales), 0), 2
        )                                    AS return_rate_pct
    FROM (
        SELECT * FROM sales_fact_1997
        UNION ALL
        SELECT * FROM sales_fact_1998
    ) s
    JOIN time_by_day t ON s.time_id = t.time_id
    LEFT JOIN returns r ON s.product_id = r.product_id
                        AND s.store_id  = r.store_id
                        AND s.time_id   = r.time_id
    GROUP BY t.the_year
)
SELECT
    the_year,
    total_units_sold,
    total_returned,
    total_transactions,
    return_rate_pct,

    -- ▶ LAG: previous year returns for comparison
    LAG(total_returned) OVER (ORDER BY the_year)             AS prev_year_returned,

    -- ▶ Change in returns vs prior year
    total_returned
    - LAG(total_returned) OVER (ORDER BY the_year)           AS return_count_change,

    -- ▶ Change in return rate vs prior year
    ROUND(
        return_rate_pct
        - LAG(return_rate_pct) OVER (ORDER BY the_year), 2
    )                                                        AS return_rate_change,

    -- ▶ Cumulative returns across years
    SUM(total_returned) OVER (
        ORDER BY the_year
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                        AS cumulative_returns,

    -- ▶ Returns as % of total returns across all years
    ROUND(
        total_returned * 100.0
        / SUM(total_returned) OVER (), 2
    )                                                        AS pct_of_all_returns

FROM yearly_returns
ORDER BY the_year;


-- ──────────────────────────────────────────────────────────────
-- RETURNS 02 · Revenue lost due to returns + category breakdown
-- Window: RANK() + cumulative lost revenue + % of gross
-- ──────────────────────────────────────────────────────────────
WITH category_returns AS (
    SELECT
        pc.product_family,
        pc.product_department,
        SUM(s.unit_sales)                    AS total_sold,
        COALESCE(SUM(r.units_returned), 0)   AS total_returned,
        ROUND(SUM(s.store_sales), 2)         AS gross_revenue,
        ROUND(
            COALESCE(SUM(r.units_returned), 0)
            * AVG(s.store_sales / NULLIF(s.unit_sales, 0)), 2
        )                                    AS revenue_lost,
        ROUND(
            COALESCE(SUM(r.units_returned), 0) * 100.0
            / NULLIF(SUM(s.unit_sales), 0), 2
        )                                    AS return_rate_pct
    FROM (
        SELECT * FROM sales_fact_1997
        UNION ALL
        SELECT * FROM sales_fact_1998
    ) s
    JOIN product p          ON s.product_id       = p.product_id
    JOIN product_class pc   ON p.product_class_id = pc.product_class_id
    LEFT JOIN returns r     ON s.product_id       = r.product_id
                           AND s.store_id         = r.store_id
                           AND s.time_id          = r.time_id
    GROUP BY pc.product_family, pc.product_department
)
SELECT
    product_family,
    product_department,
    total_sold,
    total_returned,
    gross_revenue,
    revenue_lost,
    return_rate_pct,

    -- ▶ Net revenue after losses
    ROUND(gross_revenue - revenue_lost, 2)                   AS net_revenue,

    -- ▶ RANK by revenue lost (worst first)
    RANK() OVER (ORDER BY revenue_lost DESC)                 AS lost_revenue_rank,

    -- ▶ RANK within product family
    RANK() OVER (PARTITION BY product_family
                 ORDER BY revenue_lost DESC)                 AS family_lost_rank,

    -- ▶ Revenue lost share vs total lost
    ROUND(
        revenue_lost * 100.0
        / NULLIF(SUM(revenue_lost) OVER (), 0), 2
    )                                                        AS pct_of_total_lost,

    -- ▶ Cumulative lost revenue (Pareto view)
    SUM(revenue_lost) OVER (
        ORDER BY revenue_lost DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                        AS cumulative_lost,

    -- ▶ Average revenue lost per department (family benchmark)
    ROUND(
        AVG(revenue_lost) OVER (PARTITION BY product_family), 2
    )                                                        AS family_avg_lost,

    -- ▶ FIRST_VALUE: worst department per family
    FIRST_VALUE(product_department) OVER (
        PARTITION BY product_family
        ORDER BY revenue_lost DESC
    )                                                        AS worst_dept_in_family

FROM category_returns
ORDER BY lost_revenue_rank;
