CREATE TABLE amazon_sales (
    index               SERIAL PRIMARY KEY,
    order_id            VARCHAR(50),
    date                DATE,
    status              VARCHAR(100),
    fulfilment          VARCHAR(50),
    sales_channel       VARCHAR(50),
    ship_service_level  VARCHAR(50),
    style               VARCHAR(100),
    sku                 VARCHAR(100),
    category            VARCHAR(100),
    size                VARCHAR(50),
    asin                VARCHAR(20),
    courier_status      VARCHAR(100),
    qty                 INT,
    currency            VARCHAR(10),
    amount              NUMERIC(10,2),
    ship_city           VARCHAR(100),
    ship_state          VARCHAR(100),
    ship_postal_code    VARCHAR(20),
    ship_country        VARCHAR(10),
    promotion_ids       TEXT,
    b2b                 BOOLEAN,
    fulfilled_by        VARCHAR(50)
);

show datestyle;


-- Cleaning Data

SELECT COUNT(*) FROM amazon_sales;   -- Count of Rows = 128975



-- Handling null values

SELECT COUNT(*)
FROM amazon_sales
WHERE amount IS NULL OR sku IS NULL;  -- Count of Rows = 7795

CREATE TABLE amazon_clean AS
SELECT * FROM amazon_sales
WHERE amount IS NOT NULL AND sku IS NOT NULL;

SELECT COUNT(*) FROM amazon_clean;


-- Removing Duplicates

WITH cte AS
(SELECT ctid,*, ROW_NUMBER() OVER(PARTITION BY "order_id","sku" ORDER BY "date") AS row_num
FROM amazon_clean)
DELETE FROM amazon_clean
where ctid in (SELECT ctid FROM cte WHERE row_num > 1);


-- Standardizing Categorical Data

SELECT DISTINCT ship_state FROM amazon_clean WHERE ship_state IS NOT NULL;

UPDATE amazon_clean
SET
    "ship_state" = UPPER(TRIM("ship_state")),
    "ship_city"  = INITCAP(TRIM("ship_city"));


SELECT DISTINCT ship_city FROM amazon_clean;


select * from amazon_clean;




-- Create the products table
CREATE TABLE products (
    sku VARCHAR(255) PRIMARY KEY,
    category VARCHAR(255),
    size VARCHAR(50),
    style VARCHAR(255)
);

-- Create the orders table
CREATE TABLE orders (
    order_id VARCHAR(255),
    order_date DATE,
    status VARCHAR(50),
    amount NUMERIC(10, 2),
    customer_type VARCHAR(10), -- Will derive from the 'b2b' column
    ship_city VARCHAR(255),
    ship_state VARCHAR(255),
    sku VARCHAR(255),
    FOREIGN KEY (sku) REFERENCES products(sku)
);

INSERT INTO products (sku, category, size, style)
SELECT DISTINCT
    sku,
    category,
    size,
    style
FROM
    amazon_clean;


INSERT INTO orders (order_id, order_date, status, amount, customer_type, ship_city, ship_state, sku)
SELECT
    order_id,
    date,
    status,
    amount,
    CASE
        WHEN b2b = TRUE THEN 'B2B'
        ELSE 'B2C'
    END AS customer_type,
    ship_city,
    ship_state,
    sku
FROM
    amazon_clean;

SELECT * FROM products;

SELECT * FROM orders;


-- 1: Top 10 States by Sales Revenue
-- Identifies the most valuable regions, helping to prioritize logistics and marketing.

SELECT ship_state,round(SUM(amount),2) AS revenue
FROM orders
WHERE status ='Shipped'
GROUP BY ship_state
ORDER BY 2 DESC
LIMIT 10

SELECT * FROM products;

-- 2: Top 5 Best-Selling Product Categories
-- Helps the business understand consumer demand and manage inventory for popular units

SELECT p.category,
COUNT(o.order_id) AS num_of_orders,
round(SUM(amount),2) AS total_revenue
FROM orders o JOIN products p
ON o.sku = p.sku
WHERE o.status = 'Shipped'
GROUP BY p.category
ORDER BY total_revenue DESC
LIMIT 5;
-- here the maximum number of orders are for kurta, and max revenue for set

-- 3.Sales Comparison: B2B vs. B2C
-- This analysis can inform different marketing strategies for business clients versus individual customers.

SELECT customer_type,
round(AVG(amount),2) AS avg_revenue,
round(SUM(amount),2) AS total_revenue
FROM orders 
WHERE status = 'Shipped'
GROUP BY customer_type;

-- 4.Order Status Breakdown
-- Understanding the cancellation rate is crucial for identifying potential issues in the supply chain 
-- or with product availability.

SELECT status,
COUNT(order_id) AS number_of_orders,
ROUND(COUNT(order_id) * 100.0 / (SELECT COUNT(*) FROM orders), 2) AS percentage_of_total
FROM orders
GROUP BY status
ORDER BY number_of_orders DESC;


-- 5: What is the monthly sales growth?
-- This helps to understand sales trends over time, identify seasonal peaks (like festivals), 
-- and measure overall business performance month-over-month.

SELECT to_char(order_date, 'YYYY-MM') as sales_month,
round(SUM(amount),2) AS monthly_revenue
FROM orders
WHERE status = 'Shipped'
GROUP BY 1
ORDER BY 1;
-- APR had peak performance


-- 6: For the top-selling category, what are the most popular sizes?
-- This is crucial for inventory management. If you know that "Set" is the top category, 
-- you need to know whether to stock more "M" (Medium) or "XXL" sizes to meet demand and avoid overstocking unpopular sizes.

SELECT p.size as size,count(o.order_id) AS num_of_orders
FROM orders o join products p
ON o.sku = p.sku
WHERE o.status = 'Shipped' AND p.category = 'Set'
GROUP BY 1
ORDER BY 2 DESC;


-- 7: Who are the top 5 cities within the top-performing state?
-- This allows for more targeted marketing. Instead of a statewide campaign in Maharashtra, you could focus 
-- your budget on the top 5 cities like Mumbai, Pune, etc., where you have the most customers.

SELECT DISTINCT ship_city from orders
order by 1 

SELECT ship_city,
ROUND(SUM(amount),2) AS revenue
FROM orders
WHERE status = 'Shipped' AND ship_state = 'MAHARASHTRA'
GROUP BY 1
ORDER BY 2 DESC
LIMIT 5;