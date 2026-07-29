# 📦 Retail & Supply Chain Analytics (SQL Project)

An advanced SQL case study analyzing retail sales, shipping, and customer data to uncover growth trends, profit leaks, supply chain bottlenecks, and customer behavior patterns — built entirely with PostgreSQL window functions, CTEs, and aggregations.

---

## 📌 1. Business Problem

A retail company sells products across multiple categories, regions, and customer segments, shipped through various carriers/modes. Leadership wants to understand:

- Is the business actually growing year over year, and where does it peak seasonally?
- Where is the company **losing money** — through discounting, returns, or specific customers?
- Are **shipping delays** hurting customer satisfaction (via returns)?
- Which **salespeople, routes, and customer segments** are driving (or dragging down) profitability?
- Are we too dependent on a small set of top customers, and are we **losing customers over time**?

As the Data Analyst, the goal is to answer these questions using SQL alone — no BI tool, just raw queries against two core tables (`sales` and `calendar`) — and translate the results into insights leadership can act on.

This project was built around a 15-question **Retail & Supply Chain Analytics** practice worksheet, organized into 4 modules: Time Series, Profit Bleeding, Supply Chain & Logistics, and Window Functions/CTEs ("The WOW Factors").

---

## 🗂️ 2. Dataset

Two tables, imported from CSV into PostgreSQL via `COPY`.

### `calendar` — date dimension table
| Column               | Type          | Description                              |
|-----------------------|--------------|--------------------------------------------|
| Date                  | DATE         | Calendar date (join key to `sales.orderdate`) |
| Year                  | INT          | Year                                        |
| Quarter               | INT          | Quarter number (1–4)                        |
| Quarter(Q)            | VARCHAR(10)  | Quarter label (e.g. "Q4")                   |
| Quarter_&_Year        | VARCHAR(25)  | Combined quarter + year label               |
| Month                 | INT          | Month number (1–12)                         |
| Month_Name            | VARCHAR(20)  | Month name (e.g. "January")                 |
| Month_&_Year          | VARCHAR(20)  | Combined month + year label                 |
| Week_of_Year          | INT          | ISO week number                             |
| Week_of_Year(W)       | VARCHAR(20)  | Week label                                  |
| Day_of_Week           | INT          | Day number (1–7)                            |
| Day_Name              | VARCHAR(20)  | Day name (e.g. "Monday")                    |

### `sales` — transactional fact table
| Column                | Type           | Description                              |
|------------------------|---------------|--------------------------------------------|
| row_id                 | INT (PK)       | Unique row identifier                       |
| order_id               | VARCHAR(50)    | Order identifier                            |
| orderdate              | DATE           | Date the order was placed                   |
| shipdate               | DATE           | Date the order was shipped                  |
| ship_mode              | VARCHAR(50)    | Shipping method (Standard, First Class...)  |
| customer_id            | VARCHAR(50)    | Unique customer identifier                  |
| customer_name          | VARCHAR(100)   | Customer name                               |
| segment                | VARCHAR(50)    | Customer segment                            |
| country                | VARCHAR(50)    | Country                                     |
| city                   | VARCHAR(100)   | City                                        |
| state                  | VARCHAR(100)   | State                                       |
| postal_code            | VARCHAR(20)    | Postal code                                 |
| region                 | VARCHAR(50)    | Sales region                                |
| retail_sales_people    | VARCHAR(100)   | Salesperson name                            |
| product_id             | VARCHAR(50)    | Product identifier                          |
| category               | VARCHAR(50)    | Product category                            |
| sub_category           | VARCHAR(50)    | Product sub-category                        |
| product_name           | TEXT           | Product name                                |
| returned               | VARCHAR(20)    | 'Yes' if the order was returned             |
| sales                  | DECIMAL(10,2)  | Sale amount                                 |
| quantity               | INT            | Quantity ordered                            |
| discount               | DECIMAL(5,2)   | Discount applied                            |
| profit                 | DECIMAL(10,2)  | Profit (can be negative)                    |

**Relationship:** `sales.orderdate` joins to `calendar.Date` to enrich transactions with year/quarter/month/day-of-week attributes.

**Tools used:** PostgreSQL · SQL · CSV bulk import via `COPY`

---

## 🧠 3. SQL Analysis

### Module 1: The Basics & Time Series

**1. Year-over-Year (YoY) Sales & Profit Growth**
```sql
SELECT 
    c."Year",
    ROUND(SUM(s."sales"), 2)  AS total_sales,
    ROUND(SUM(s."profit"), 2) AS total_profit
FROM sales s
JOIN calendar c
    ON c."Date" = s."orderdate"
GROUP BY c."Year"
ORDER BY c."Year";
```

**2. Seasonality — The Weekend Effect**
```sql
SELECT 
    c."Day_Name",
    ROUND(SUM(s."sales"), 2) AS total_sales,
    SUM(CASE WHEN s."returned" = 'Yes' THEN 1 ELSE 0 END) AS total_returns
FROM sales s
JOIN calendar c
    ON c."Date" = s."orderdate"
GROUP BY c."Day_Name"
ORDER BY total_sales;
```

**3. The Best Quarter**
```sql
SELECT 
    c."Year",
    c."Quarter(Q)",
    ROUND(SUM(s."sales"), 2) AS total_sales
FROM sales s
JOIN calendar c
    ON c."Date" = s."orderdate"
GROUP BY c."Year", c."Quarter(Q)"		
ORDER BY total_sales DESC
LIMIT 1;
```

---

### Module 2: Profit Bleeding — Where Are We Losing Money?

**4. The Discount Trap**
```sql
SELECT 
    "category", "sub_category",
    ROUND(SUM("sales"), 2)      AS total_sales,
    ROUND(AVG(discount) * 100, 2) AS avg_discount_pct,
    ROUND(SUM(profit), 2)       AS total_profit
FROM sales
GROUP BY "category", "sub_category"
ORDER BY total_profit ASC;
```

**5. The Return Problem**
```sql
SELECT 
    "region", 
    COUNT(*) AS total_orders,
    SUM(CASE WHEN "returned" = 'Yes' THEN 1 ELSE 0 END) AS total_returns,
    ROUND((SUM(CASE WHEN "returned" = 'Yes' THEN 1 ELSE 0 END) / COUNT(*)) * 100, 2) AS return_rate_pct
FROM sales
GROUP BY region
ORDER BY return_rate_pct DESC;
```

**6. Top 10 Loss-Making Customers**
```sql
SELECT 
    "customer_id", "customer_name",
    ROUND(SUM(sales), 2)  AS total_sales,
    ROUND(SUM(profit), 2) AS total_loss
FROM sales
GROUP BY "customer_id", "customer_name"
HAVING SUM("profit") < 0
ORDER BY total_loss
LIMIT 10;
```

---

### Module 3: Advanced Supply Chain & Logistics

**7. Shipping Delay Analysis**
```sql
SELECT
    "ship_mode",
    ROUND(AVG("shipdate" - "orderdate"), 2) AS avg_shipping_days
FROM sales
GROUP BY ship_mode
ORDER BY avg_shipping_days;
```

**8. Late Delivery Impact**
```sql
WITH shipping_data AS (
    SELECT 
        "order_id", "returned",
        ("shipdate" - "orderdate") AS delivery_days
    FROM sales
)
SELECT
    CASE WHEN delivery_days > 3 THEN 'Late (> 3 Days)'
         ELSE 'On Time (<= 3 Days)' END AS delivery_status,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN "returned" = 'Yes' THEN 1 ELSE 0 END) AS returned_orders,
    ROUND((SUM(CASE WHEN "returned" = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*)), 1) AS return_rate_pct
FROM shipping_data
GROUP BY delivery_status;
```

**9. Salesperson Performance**
```sql
SELECT
    "retail_sales_people",
    ROUND(SUM("sales"), 2)  AS total_sales,
    ROUND(SUM("profit"), 2) AS total_profit,
    ROUND((SUM("profit") / SUM("sales")) * 100, 2) AS profit_margin_pct
FROM sales
GROUP BY "retail_sales_people"
ORDER BY total_sales DESC;
```

---

### Module 4: Window Functions & CTEs — "The WOW Factors"

**10. The Pareto Principle (80/20 Rule)**
```sql
WITH customer_sales AS (
    SELECT customer_id, SUM(sales) AS total_sales
    FROM sales
    GROUP BY customer_id
),
ranked_customers AS (
    SELECT 
        "customer_id", "total_sales",
        SUM(total_sales) OVER (ORDER BY "total_sales" DESC) AS running_total,
        (SELECT SUM(sales) FROM sales) AS grand_total
    FROM customer_sales
)
SELECT 
    COUNT("customer_id") AS top_customers_count,
    (SELECT COUNT(DISTINCT "customer_id") FROM sales) AS total_customers,
    ROUND((COUNT("customer_id") * 100.0 / (SELECT COUNT(DISTINCT "customer_id") FROM sales)), 2) AS pct_of_cust_generating_80_pct_sales
FROM ranked_customers
WHERE running_total <= grand_total * 0.80;
```
> ⚠️ **Fix needed:** the original script has a typo — `SUM(total_sales) 9OVER(...)` — remove the stray `9` before `OVER` or this query will fail to run.

**11. Customer Churn (active in 2015–16, gone by 2017)**
```sql
WITH customer_years AS (
    SELECT s."customer_id", c."Year"
    FROM sales s
    JOIN calendar c
        ON s."orderdate" = c."Date"
    GROUP BY s."customer_id", c."Year"
)
SELECT DISTINCT "customer_id" 
FROM customer_years
WHERE "customer_id" IN (
        SELECT customer_id FROM customer_years WHERE "Year" IN (2015, 2016)
    )
    AND "customer_id" NOT IN (
        SELECT customer_id FROM customer_years WHERE "Year" = 2017
    );
```

**12. 30-Day Moving Average**
```sql
WITH daily_sales AS (
    SELECT 
        c."Date" AS order_date,
        SUM(s."sales") AS daily_sales
    FROM sales s
    JOIN calendar c
        ON s."orderdate" = c."Date"
    GROUP BY order_date
)
SELECT
    order_date,
    daily_sales,
    ROUND(AVG(daily_sales) OVER (
        ORDER BY order_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    ), 2) AS "30_day_moving_avg"
FROM daily_sales
ORDER BY order_date;
```

**13. Customer Segmentation (Mini RFM)**
```sql
SELECT 
    customer_id, customer_name,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(SUM(sales), 2) AS total_sales,
    CASE 
        WHEN COUNT(DISTINCT order_id) = 1 THEN 'One_time_buyer'
        WHEN SUM(sales) > 5000 THEN 'VIP'
        ELSE 'Regular' 
    END AS customer_segment
FROM sales
GROUP BY customer_id, customer_name
ORDER BY total_sales DESC;
```

**14. Month-over-Month (MoM) Growth**
```sql
WITH monthly_sales AS (
    SELECT 
        c."Year", c."Month", 
        SUM(s."sales") AS current_month_sales
    FROM sales s
    JOIN calendar c
        ON c."Date" = s."orderdate"
    GROUP BY c."Year", c."Month"
)
SELECT 
    "Year",
    "Month",
    ROUND(current_month_sales, 2) AS current_sales,
    ROUND(LAG(current_month_sales) OVER (ORDER BY "Year", "Month"), 2) AS prev_month_sales,
    ROUND(
        (current_month_sales - LAG(current_month_sales) OVER (ORDER BY "Year", "Month")) 
        / LAG(current_month_sales) OVER (ORDER BY "Year", "Month") * 100.0, 2
    ) AS "MoM_growth_pct"
FROM monthly_sales;
```

**15. Most Profitable Route**
```sql
SELECT 
    "state", "city",
    COUNT("order_id") AS total_orders,
    ROUND(SUM("profit"), 2) AS total_profit,
    ROUND(SUM("profit") / COUNT("order_id"), 2) AS profit_per_order
FROM sales
GROUP BY "state", "city"
HAVING COUNT("order_id") > 10
ORDER BY profit_per_order DESC
LIMIT 5;
```

---

## 🧩 4. SQL Concepts & Functions Used

| Category                     | Functions / Concepts Used                                                                                     |
|-------------------------------|-----------------------------------------------------------------------------------------------------------------|
| **DDL (Schema Design)**       | `CREATE TABLE`, `PRIMARY KEY`, data types (`VARCHAR`, `DATE`, `DECIMAL`, `INT`, `TEXT`)                          |
| **Data Import**               | `COPY ... FROM`, `DELIMITER`, `CSV HEADER`, `NULL`, `SET datestyle`, explicit column-list `COPY`                 |
| **Data Quality Checks**       | `IS NULL` checks across all columns, `information_schema.columns` metadata query                                 |
| **Aggregate Functions**       | `SUM()`, `COUNT()`, `COUNT(DISTINCT ...)`, `AVG()`                                                                |
| **Window Functions**          | `SUM() OVER (ORDER BY ...)` (running total for Pareto analysis), `AVG() OVER (... ROWS BETWEEN 29 PRECEDING AND CURRENT ROW)` (30-day moving average), `LAG() OVER (ORDER BY ...)` (month-over-month growth) |
| **Common Table Expressions**  | `WITH ... AS (...)` — used in nearly every advanced query (Pareto, churn, moving average, MoM growth, late delivery) |
| **Conditional Logic**         | `CASE WHEN ... THEN ... ELSE ... END` — returns flags, delivery status buckets, customer segmentation             |
| **Joins**                     | `INNER JOIN` (sales ↔ calendar, on date)                                                                          |
| **Date/Time Functions & Arithmetic** | Date subtraction (`shipdate - orderdate`) for shipping delays, `Year`/`Quarter`/`Month`/`Day_Name` dimension lookups via `calendar` |
| **Subqueries**                 | Scalar subqueries (`SELECT SUM(sales) FROM sales`), `IN (SELECT ...)` / `NOT IN (SELECT ...)` (churn logic)      |
| **Numeric Functions**          | `ROUND()`                                                                                                          |
| **Filtering & Grouping**       | `WHERE`, `GROUP BY`, `HAVING` (filtering aggregated groups — loss-making customers, high-volume routes), `ORDER BY`, `LIMIT` |

---

## 📁 5. Repository Structure

```
├── sales_data_analysis.sql   # Full SQL script (schema + import + all 15 analysis queries)
└── README.md                 # Project documentation
```

---

## ▶️ 6. How to Run

1. Install [PostgreSQL](https://www.postgresql.org/download/) and a client such as pgAdmin or `psql`.
2. Create a new database:
   ```sql
   CREATE DATABASE retail_analytics;
   ```
3. Update the `COPY ... FROM` file paths to point to your local CSV files (`calender_file.csv`, `sales_cleaned_final.csv`).
4. Run the script section by section: schema creation → data import → null checks → analysis queries.
5. Fix the typo noted in Query 10 (`9OVER` → `OVER`) before running it.

> **Note:** `COPY` requires the CSV files to be accessible to the PostgreSQL server itself, not just your client machine. If you don't have server-side file access, use `psql`'s `\copy` command instead, which reads from your local machine.

---

## 💡 7. Key Insights *(fill in with your actual results once you run the queries)*

- Best-performing year: `___` | YoY growth trend: `___`
- Highest-sales day of week: `___` | Highest-return day: `___`
- Best quarter overall: `___`
- Category/sub-category with worst discount-driven losses: `___`
- Region with highest return rate: `___%`
- Top loss-making customer: `___`
- Slowest shipping mode: `___ days` on average
- Does late delivery increase returns? `___`
- Top salesperson by sales / worst by profit margin: `___`
- % of customers driving 80% of sales: `___%`
- Number of churned customers (active 2015–16, gone in 2017): `___`
- Best month-over-month growth: `___%`
- Most profitable state/city route: `___`

---

## 🔭 8. Future Scope

- Build a dashboard (Power BI / Tableau) on top of these query outputs for stakeholder consumption.
- Extend churn analysis beyond 2015–2017 to a rolling, year-agnostic definition (e.g. "no order in the last 12 months").
- Add cohort-based retention analysis alongside the existing Pareto and churn queries.
- Automate the null-value data quality checks into a reusable validation view.

---

## 📌 9. Notes on Data Cleaning & Known Issues

- Column names in the `calendar` table use special characters (`Quarter(Q)`, `Quarter_&_Year`, etc.) and therefore require double-quoting in every query — kept as-is to match the source CSV headers.
- `SET datestyle = 'ISO, DMY'` is set before each `COPY` to ensure dates are parsed as Day-Month-Year rather than the US default.
- **Bug in Query 10 (Pareto Principle):** the running-total window function has a stray character — `SUM(total_sales) 9OVER(...)` — this must be corrected to `SUM(total_sales) OVER (...)` before the query will execute.
- Division-based percentage calculations (return rate, MoM growth, profit margin) rely on PostgreSQL's automatic promotion to numeric when at least one operand is a `DECIMAL`; if adapting these queries for an all-integer column set, cast explicitly to avoid integer division truncation (e.g. `* 100.0` instead of `* 100`).

---

## 🙋‍♂️ Author

**Pranav Khanna**
📧 pranavkhanna2602@gmail.cm | 🔗  https://www.linkedin.com/in/pranav-khanna-057360346/(#) 

---

## 📄 License

This project is licensed under the MIT License — feel free to use and adapt it.
