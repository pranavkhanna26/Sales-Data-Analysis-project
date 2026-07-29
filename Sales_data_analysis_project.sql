-- Table 1
CREATE TABLE calendar (
    "Date" DATE,
    "Year" INT,
    "Quarter" INT,
    "Quarter(Q)" VARCHAR(10),
    "Quarter_&_Year" VARCHAR(25),
    "Month" INT,
    "Month_Name" VARCHAR(20),
    "Month_&_Year" VARCHAR(20),
    "Week_of_Year" INT,
    "Week_of_Year(W)" VARCHAR(20),
    "Day_of_Week" INT,
    "Day_Name" VARCHAR(20)
);

-- 1. Tell PostgreSQL to expect Day-Month-Year format for this session
SET datestyle = 'ISO, DMY';

-- 2. Importing data from the PC
COPY calendar
FROM 'C:\temp\calender_file.csv'
DELIMITER ','
CSV HEADER
NULL '';

select * from calendar;

--3. Table 2

CREATE TABLE sales (
    row_id INT PRIMARY KEY,
    order_id VARCHAR(50),
    orderdate DATE,
    shipdate DATE,
    ship_mode VARCHAR(50),
    customer_id VARCHAR(50),
    customer_name VARCHAR(100),
    segment VARCHAR(50),
    country VARCHAR(50),
    city VARCHAR(100),
    state VARCHAR(100),
    postal_code VARCHAR(20),
    region VARCHAR(50),
    retail_sales_people VARCHAR(100),
    product_id VARCHAR(50),
    category VARCHAR(50),
    sub_category VARCHAR(50),
    product_name TEXT,
    returned VARCHAR(20),
    sales DECIMAL(10,2),
    quantity INT,
    discount DECIMAL(5,2),
    profit DECIMAL(10,2)
);

SET datestyle = 'ISO, DMY';

-- Importing data from the PC
SET datestyle = 'ISO, DMY';

COPY sales (
    "row_id", "order_id", "orderdate", "shipdate", "ship_mode", 
    "customer_id", "customer_name", "segment", "country", "city", 
    "state", "postal_code", "region", "retail_sales_people", 
    "product_id", "category", "sub_category", "product_name", 
    "returned", "sales", "quantity", "discount", "profit"
)
FROM 'C:\temp\sales_cleaned_final.csv'
DELIMITER ','
CSV HEADER
NULL '';

select * from sales;

SELECT 
    column_name, 
    data_type, 
    character_maximum_length
FROM 
    information_schema.columns
WHERE 
    table_name = 'sales';


-- CHECKING FORR ANT NULL VALUES IN CALENDER TABLE
SELECT * FROM calendar
WHERE 
"Date" IS NULL OR 
"Year" IS NULL OR
"Quarter" IS NULl OR
"Quarter(Q)" IS NULL OR
"Quarter_&_Year" IS NULL OR
"Month" IS NULL OR
"Month_Name" IS NULL OR
"Month_&_Year" IS NULL OR
"Week_of_Year" IS NULL OR
"Week_of_Year(W)" IS NULL OR
"Day_of_Week" IS NULL OR
"Day_Name" IS NULL;

-- CHECKING FORR ANT NULL VALUES IN SALES TABLE

SELECT * FROM sales
WHERE
    row_id IS NULL OR
    order_id IS NULL OR
    orderdate IS NULL OR
    shipdate IS NULL OR
    ship_mode IS NULL OR
    customer_id IS NULL OR
    customer_name IS NULL OR
    segment IS NULL OR
    country IS NULL OR
    city IS NULL OR
    state IS NULL OR
    postal_code IS NULL OR
    region IS NULL OR
    retail_sales_people IS NULL OR
    product_id IS NULL OR
    category IS NULL OR
    sub_category IS NULL OR
    product_name IS NULL OR
    returned IS NULL OR
    sales IS NULL OR
    quantity IS NULL OR
    discount IS NULL OR
    profit IS NULL
;


-- Year on Year(YoY) sales & profit growth

SELECT 
		c."Year",
		ROUND(Sum(s."sales"),2) as total_sales,
		ROUND(SUM(s."profit"),2) as total_profit
FROM sales s
JOIN calendar c
ON c."Date" = s."orderdate"
GROUP BY c."Year"
ORDER BY c."Year";

--Seasonality(The weekend effect)

SELECT c."Day_Name",
		ROUND(SUM(s."sales"),2) AS total_sales,
		SUM(CASE WHEN s."returned" = 'Yes' THEN 1 ELSE 0 END) AS total_returns
FROM sales s
JOIN calendar c
ON c."Date" = s."orderdate"
GROUP BY c."Day_Name"
ORDER BY total_sales

-- The Best Quater

SELECT c."Year",
		c."Quarter(Q)",
		ROUND(SUM(s."sales"),2) AS total_sales
FROM sales s
JOIN calendar c
ON c."Date" = s."orderdate"
GROUP BY c."Year",
		c."Quarter(Q)"		
ORDER BY total_sales DESC
LIMIT 1;

-- The discount trap
SELECT "category","sub_category",
		ROUND(SUM("sales"),2) AS total_sales,
		ROUND(AVG(discount)*100,2) AS avg_discount_pct,
		ROUND(SUM(profit),2) AS total_profit
FROM sales
GROUP BY "category","sub_category"
ORDER  BY total_profit ASC;

-- The return problem

SELECT "region",count(*) AS total_orders,
		SUM(CASE WHEN "returned" = 'Yes' THEN 1 ELSE 0 END) AS total_returns,
		ROUND((SUM(CASE WHEN "returned" = 'Yes' THEN 1 ELSE 0 END) / COUNT(*))*100,2) AS return_rate_pct
FROM sales
GROUP BY region
ORDER BY return_rate_pct DESC;

-- Top 10 loss making customers

SELECT "customer_id","customer_name",
		ROUND(SUM(sales),2) AS total_sales,
		ROUND(SUM(profit),2) AS total_loss
FROM sales
GROUP BY "customer_id","customer_name"
HAVING SUM("profit") <0
ORDER BY total_loss
LIMIT 10;

-- Shipping delay analysis
SELECT
	"ship_mode",
	ROUND(AVG("shipdate" - "orderdate"),2) AS avg_shipping_days
FROM sales
GROUP BY ship_mode
ORDER BY avg_shipping_days

--Late delivery impact

WITH shipingdata AS (
	SELECT "order_id","returned",
	("shipdate" - "orderdate") as delivery_days
FROM sales
)

SELECT
	CASE WHEN delivery_days > 3 THEN 'late ( > 3 Days)'
	ELSE 'On Time (<= 3 Days)' END AS delivery_status,
	COUNT(*) AS total_orders,
	SUM(CASE WHEN "returned" = 'Yes' THEN 1 ELSE 0 END) AS returned_orders,
	ROUND((SUM(CASE WHEN "returned" = 'Yes' THEN 1 ELSE 0 END) * 100 / COUNT(*)),1) AS return_rate_pct
	FROM shipingdata
	GROUP BY delivery_status;

-- Sales person performance

SELECT
		"retail_sales_people",
		ROUND(SUM("sales"),2) total_sales,
		ROUND(SUM("profit"),2)total_profit,
		ROUND((SUM("profit") / SUM("sales"))* 100,2) AS profit_margin_pct
FROM sales
GROUP BY "retail_sales_people"
ORDER BY "total_sales" DESC;

-- The pareto principle (Is our 80% of customers are bringing most of the sales)

WITH customers_sales AS(
	SELECT customer_id, SUM(sales) AS total_sales
	FROM sales
	GROUP BY customer_id
),

ranked_customers AS (
	SELECT "customer_id","total_sales",
	SUM(total_sales) 9OVER(ORDER BY "total_sales" DESC) AS
	running_total,
	(SELECT SUM(sales) FROM sales) AS grand_total
	FROM customers_sales
	)

SELECT COUNT("customer_id") AS top_customers_count,
	(SELECT COUNT(DISTINCT "customer_id") FROM sales) AS total_customers,
	ROUND((COUNT("customer_id") * 100 / (SELECT COUNT(DISTINCT "customer_id") FROM sales)),2) AS pct_of_cust_generating_80_pct_sales
	FROM ranked_customers
	WHERE running_total <= grand_total * 0.80;

-- Customers churn (cutomers those how have done shoping in 2015-16)

WITH customers_years AS (
	SELECT s."customer_id",c."Year"
	FROM sales s
	JOIN calendar c
	ON s."orderdate" = c."Date"
	GROUP BY s."customer_id",c."Year"
)
	
SELECT DISTINCT "customer_id" FROM customers_years
WHERE "customer_id" IN (SELECT customer_id FROM customers_years
WHERE "Year" IN (2015,2016))
AND "customer_id" NOT IN (SELECT customer_id from customers_years 
WHERE "Year" = 2017);


-- 30 day moving average

WITH daily_sales AS (
SELECT c."Date" AS order_date,
	SUM(s."sales") AS daily_sales
	FROM sales s
	JOIN calendar c
	ON s."orderdate" = c."Date"
	GROUP BY order_date
)

SELECT
	order_date,
	daily_sales,
	ROUND(AVG(daily_sales) OVER(ORDER BY order_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW),2) AS "30_days_moving_avg"
FROM daily_sales
ORDER BY order_date;

--Customers segment(mini RFM)

SELECT customer_id,customer_name,
		COUNT(DISTINCT order_id) AS total_orders,
		ROUND(SUM(sales),2) AS total_sales,
		CASE 
			WHEN COUNT(DISTINCT order_id) = 1 THEN 'One_time_buyer'
			WHEN SUM(sales) > 5000 THEN 'VIP'
			ELSE 'REGULAR' END AS customer_segment
		FROM sales
		GROUP BY customer_id,
				customer_name
		ORDER BY total_sales DESC;

-- Month-over-Month growth

WITH monthly_sales as(
	SELECT c."Year",c."Month",SUM(s."sales") AS current_month_sales
	FROM sales s
	JOIN calendar c
	ON c."Date" = s."orderdate"
	GROUP BY c."Year",c."Month"
)

SELECT 
    "Year",
    "Month",
    ROUND(current_month_sales, 2) AS current_sales,
    ROUND(LAG(current_month_sales) OVER (ORDER BY "Year", "Month"), 2) AS prev_month_sales,
    ROUND((current_month_sales - LAG(current_month_sales) OVER (ORDER BY "Year", "Month")) 
        / LAG(current_month_sales) OVER (ORDER BY "Year", "Month") * 100.0, 2) AS "MoM_growth_pct"
    
FROM monthly_sales;


--Most Profitable route

SELECT "state","city",
		COUNT("order_id") AS total_orders,
		ROUND(SUM("profit"),2) AS total_profit,
		ROUND(SUM("profit")/ COUNT("order_id"),2) AS profit_per_order
		FROM sales
		GROUP BY "state","city"
		HAVING COUNT("order_id") > 10
		ORDER BY profit_per_order DESC
		LIMIT 5