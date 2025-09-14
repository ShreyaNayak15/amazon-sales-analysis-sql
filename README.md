# E-commerce Sales Analysis for Amazon India using SQL

![Amazon Logo](https://github.com/ShreyaNayak15/amazon-sales-analysis-sql/blob/main/amazon-rebrand-2025_dezeen_2364_col_1-1.webp)

## Overview
This repository contains a comprehensive SQL-based analysis of an Amazon India sales dataset. The project demonstrates a full data analysis workflow, starting from raw data cleaning and preprocessing, moving to database normalization, and culminating in the extraction of actionable business insights. The analysis was performed entirely within PostgreSQL, showcasing how to leverage SQL for powerful data manipulation and business intelligence. The dataset comprises over 128,000 sales records.

## Objective
The primary objective of this project is to analyze transactional sales data to identify patterns and trends that can inform strategic business decisions. The goal is to move beyond raw data to provide clear, data-driven answers to critical questions about market performance, product strategy, and customer behavior.

## Dataset

The data for this project is sourced from from Kaggle Dataset:
- **Dataset Link:** [https://www.kaggle.com/datasets/thedevastator/unlock-profits-with-e-commerce-sales-data]

## Schema
```sql
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
```

### Cleaning Data

SELECT COUNT(*) FROM amazon_sales;   -- Count of Rows = 128975

**Handling null values**
```sql
SELECT COUNT(*)
FROM amazon_sales
WHERE amount IS NULL OR sku IS NULL;  -- Count of Rows = 7795

CREATE TABLE amazon_clean AS
SELECT * FROM amazon_sales
WHERE amount IS NOT NULL AND sku IS NOT NULL;

SELECT COUNT(*) FROM amazon_clean;
```

 **Removing Duplicates**
```sql
WITH cte AS
(SELECT ctid,*, ROW_NUMBER() OVER(PARTITION BY "order_id","sku" ORDER BY "date") AS row_num
FROM amazon_clean)
DELETE FROM amazon_clean
where ctid in (SELECT ctid FROM cte WHERE row_num > 1);
```

**Standardizing Categorical Data**
```sql
SELECT DISTINCT ship_state FROM amazon_clean WHERE ship_state IS NOT NULL;

UPDATE amazon_clean
SET
    "ship_state" = UPPER(TRIM("ship_state")),
    "ship_city"  = INITCAP(TRIM("ship_city"));


SELECT DISTINCT ship_city FROM amazon_clean;
```

```sql
select * from amazon_clean;
```


### Create the products table
```sql
CREATE TABLE products (
    sku VARCHAR(255) PRIMARY KEY,
    category VARCHAR(255),
    size VARCHAR(50),
    style VARCHAR(255)
);
```

### Create the orders table
```sql
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
```

- 1: Top 10 States by Sales Revenue
  
    Identifies the most valuable regions, helping to prioritize logistics and marketing.
```sql
SELECT ship_state,round(SUM(amount),2) AS revenue
FROM orders
WHERE status ='Shipped'
GROUP BY ship_state
ORDER BY 2 DESC
LIMIT 10
```

- 2: Top 5 Best-Selling Product Categories
  
     Helps the business understand consumer demand and manage inventory for popular units
```sql
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
```

- 3.Sales Comparison: B2B vs. B2C
  
    This analysis can inform different marketing strategies for business clients versus individual customers.
```sql
SELECT customer_type,
round(AVG(amount),2) AS avg_revenue,
round(SUM(amount),2) AS total_revenue
FROM orders 
WHERE status = 'Shipped'
GROUP BY customer_type;
```

- 4.Order Status Breakdown
  
    Understanding the cancellation rate is crucial for identifying potential issues in the supply chain or with product availability.
```sql
SELECT status,
COUNT(order_id) AS number_of_orders,
ROUND(COUNT(order_id) * 100.0 / (SELECT COUNT(*) FROM orders), 2) AS percentage_of_total
FROM orders
GROUP BY status
ORDER BY number_of_orders DESC;
```

- 5: What is the monthly sales growth?
  
     This helps to understand sales trends over time, identify seasonal peaks (like festivals),and measure overall business performance month-over-month.
```sql
SELECT to_char(order_date, 'YYYY-MM') as sales_month,
round(SUM(amount),2) AS monthly_revenue
FROM orders
WHERE status = 'Shipped'
GROUP BY 1
ORDER BY 1;
-- APR had peak performance
```

- 6: For the top-selling category, what are the most popular sizes?
  
    This is crucial for inventory management. If you know that "Set" is the top category, you need to know whether to stock more "M" (Medium) or "XXL" sizes to meet demand and avoid overstocking unpopular sizes.
```sql
SELECT p.size as size,count(o.order_id) AS num_of_orders
FROM orders o join products p
ON o.sku = p.sku
WHERE o.status = 'Shipped' AND p.category = 'Set'
GROUP BY 1
ORDER BY 2 DESC;
```

- 7: Who are the top 5 cities within the top-performing state?
  
    This allows for more targeted marketing. Instead of a statewide campaign in Maharashtra, you could focus your budget on the top 5 cities like Mumbai, Pune, etc., where you have the most customers.
```sql
SELECT DISTINCT ship_city from orders
order by 1 

SELECT ship_city,
ROUND(SUM(amount),2) AS revenue
FROM orders
WHERE status = 'Shipped' AND ship_state = 'MAHARASHTRA'
GROUP BY 1
ORDER BY 2 DESC
LIMIT 5;
```

## Business Problems Explored
The analysis was structured to answer several key business questions:

Geographic Performance: Which states and cities are the most significant drivers of sales revenue?

Product Strategy: What are the best-selling product categories, and what are the most popular sizes within those categories?

Customer Segmentation: How does the purchasing behavior of B2B (business-to-business) customers compare to that of B2C (business-to-consumer) customers?

Operational Efficiency: What is the order cancellation rate, and what does it suggest about the sales pipeline?

Temporal Trends: Are there seasonal peaks or monthly patterns in sales performance that can inform inventory and marketing calendars?

## Key Findings & Insights
The SQL queries uncovered several critical insights:

Top Markets Identified: Maharashtra emerged as the top-performing state, with Mumbai and Pune being the most lucrative cities within it. This suggests that marketing and logistics efforts could be profitably concentrated in this region.

High-Value Products: While "Kurta" was the most frequently ordered item, the "Set" category generated the highest total revenue, indicating it has a higher average price point and is a key driver of profitability.

B2B Customer Value: The analysis revealed that B2B customers have a significantly higher average transaction value than B2C customers, identifying them as a crucial segment for targeted outreach and retention campaigns.

Seasonal Sales Peak: A distinct sales peak was observed in the month of April, pointing to a potential seasonal trend that can be anticipated for future inventory management and promotional activities.

Inventory Optimization: Within the top-selling "Set" category, sizes M, L, and XL were the most popular, providing clear direction on which sizes to prioritize in stock to meet consumer demand and minimize waste.


## Conclusion & Strategic Recommendations
This SQL-based analysis successfully transformed a raw dataset into a source of strategic business intelligence. The findings provide a clear path forward for optimizing the e-commerce business's operations.

Based on the analysis, the following actions are recommended:

Focus Marketing Spend: Concentrate digital marketing campaigns and resources on top-performing states, particularly Maharashtra.

Optimize Inventory: Prioritize stock for the high-revenue "Set" category and ensure sufficient inventory of the most popular sizes (M, L, XL) to prevent stockouts.

Develop B2B Relations: Create a dedicated strategy for B2B customers, potentially offering bulk discounts or loyalty programs to capitalize on their higher average order value.

Plan for Seasonality: Prepare for the annual sales peak in April by increasing stock levels and launching targeted marketing campaigns in the preceding weeks.

By implementing these data-driven strategies, the business can enhance its marketing ROI, improve inventory management, and foster growth in its most valuable customer segments.

#### THANK YOU!

#### Shreya Nayak
**Linkedin:** [https://www.linkedin.com/in/shreyanayak15]
**Email:** [shreyanayak1505@gmail.com]
