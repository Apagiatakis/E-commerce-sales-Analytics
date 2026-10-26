-- E-Commerce Sales Analytics: starter analysis queries
USE ecommerce_analytics;

-- 1. Basic data-quality checks
SELECT COUNT(*) AS customer_count FROM customers;
SELECT COUNT(*) AS product_count FROM products;
SELECT COUNT(*) AS order_count FROM orders;
SELECT COUNT(*) AS order_item_count FROM order_items;

-- For revenue analysis, use delivered orders only.
-- Revenue after discount = quantity * unit_price * (1 - discount_pct).
-- Cost = quantity * unit_cost. Profit is revenue minus cost.

-- 2. Overall sales KPIs
SELECT 
    COUNT(DISTINCT o.order_id) AS delivered_orders,
    COUNT(DISTINCT o.customer_id) AS purchasing_customers,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)),2) AS revenue,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)) / COUNT(DISTINCT o.order_id),2) AS average_order_value
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status = 'Delivered';

-- 3. Monthly revenue (MySQL)
SELECT
    DATE_FORMAT(o.order_date, '%Y-%m') AS order_month,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)), 2) AS revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status = 'Delivered'
GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
ORDER BY order_month;

-- 4. Revenue and profit by category
SELECT
    p.category,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)), 2) AS revenue,
    ROUND(SUM(oi.quantity * (oi.unit_price * (1 - oi.discount_pct) - p.unit_cost)), 2) AS profit
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p ON p.product_id = oi.product_id
WHERE o.order_status = 'Delivered'
GROUP BY p.category
ORDER BY revenue DESC;

-- 5. Top 10 products by revenue
SELECT
    p.product_name,
    p.category,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)), 2) AS revenue,
    SUM(oi.quantity) AS units_sold
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p ON p.product_id = oi.product_id
WHERE o.order_status = 'Delivered'
GROUP BY p.product_id, p.product_name, p.category
ORDER BY revenue DESC
LIMIT 10;

-- 6. Top 10 customers by lifetime revenue
SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    COUNT(DISTINCT o.order_id) AS delivered_orders,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)), 2) AS lifetime_revenue
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status = 'Delivered'
GROUP BY c.customer_id, customer_name
ORDER BY lifetime_revenue DESC
LIMIT 10;

-- 7. Revenue by city
SELECT
    c.city,
    c.region,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)), 2) AS revenue
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status = 'Delivered'
GROUP BY c.city, c.region
ORDER BY revenue DESC;

-- 8. Repeat-purchase rate: share of purchasing customers with 2+ delivered orders
WITH customer_orders AS (
    SELECT o.customer_id, COUNT(DISTINCT o.order_id) AS order_count
    FROM orders o
    WHERE o.order_status = 'Delivered'
    GROUP BY o.customer_id
)
SELECT
    COUNT(*) AS purchasing_customers,
    SUM(order_count >= 2) AS repeat_customers,
    ROUND(100 * SUM(order_count >= 2) / COUNT(*), 3) AS repeat_customer_pct
FROM customer_orders;

-- 9. Rank products within each category (MySQL 8+)
WITH product_revenue AS (
    SELECT
        p.product_id, p.product_name, p.category,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)) AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    JOIN products p ON p.product_id = oi.product_id
    WHERE o.order_status = 'Delivered'
    GROUP BY p.product_id, p.product_name, p.category
)
SELECT *,
       DENSE_RANK() OVER (PARTITION BY category ORDER BY revenue DESC) AS category_rank
FROM product_revenue;

-- 10. Compare monthly revenue to previous month using LAG (MySQL 8+)
WITH monthly_revenue AS (
    SELECT
        DATE_FORMAT(o.order_date, '%Y-%m') AS order_month,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)) AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'Delivered'
    GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
)
SELECT
    order_month,
    ROUND(revenue, 2) AS revenue,
    ROUND(LAG(revenue) OVER (ORDER BY order_month), 2) AS previous_month_revenue,
    ROUND(revenue - LAG(revenue) OVER (ORDER BY order_month), 2) AS revenue_change
FROM monthly_revenue
ORDER BY order_month;

-- 11. Products with revenue above average product revenue (CTE)
WITH product_revenue AS (
    SELECT p.product_id, p.product_name,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)) AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    JOIN products p ON p.product_id = oi.product_id
    WHERE o.order_status = 'Delivered'
    GROUP BY p.product_id, p.product_name
)
SELECT *
FROM product_revenue
WHERE revenue > (SELECT AVG(revenue) FROM product_revenue)
ORDER BY revenue DESC;

-- 12. Optional challenge: calculate cancellation/return rate by month.
-- Hint: count orders by status, grouped by DATE_FORMAT(order_date, '%Y-%m').
