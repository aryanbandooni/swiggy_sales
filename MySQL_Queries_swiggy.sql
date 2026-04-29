
use swiggydb;

SELECT * FROM swiggy;

-- DATA VALIDATION
-- ORDER DATE FORMAT CHANGE
UPDATE swiggy
SET orderdate = STR_TO_DATE(orderdate, '%d-%m-%Y')
WHERE orderdate IS NOT NULL;

ALTER TABLE swiggy
MODIFY orderdate DATE;


-- NULL CHECK
SELECT 
	SUM(CASE WHEN state IS NULL THEN 1 ELSE 0 END) AS null_state,
    SUM(CASE WHEN city IS NULL THEN 1 ELSE 0 END) AS null_city,
	SUM(CASE WHEN orderdate IS NULL THEN 1 ELSE 0 END) AS null_orderdate,
    SUM(CASE WHEN restaurantname IS NULL THEN 1 ELSE 0 END) AS null_restaurantname,
    SUM(CASE WHEN location IS NULL THEN 1 ELSE 0 END) AS null_location,
    SUM(CASE WHEN category IS NULL THEN 1 ELSE 0 END) AS null_category,
    SUM(CASE WHEN dishname IS NULL THEN 1 ELSE 0 END) AS null_dishname,
    SUM(CASE WHEN price IS NULL THEN 1 ELSE 0 END) AS null_price,
    SUM(CASE WHEN rating IS NULL THEN 1 ELSE 0 END) AS null_rating,
    SUM(CASE WHEN ratingcount IS NULL THEN 1 ELSE 0 END) AS null_ratingcount
FROM swiggy;


-- BLANK OR EMPTY STRINGS
SELECT * 
FROM swiggy
WHERE
state='' OR city='' OR restaurantname='' OR location='' OR category='' OR dishname='';


-- DUPLICATE DETECTION
SELECT *, COUNT(*) as CNT 
FROM swiggy
GROUP BY
state, city, orderdate, restaurantname, location, category, dishname, price, rating, ratingcount
HAVING count(*)>1;


-- DELETE DUPLICATION
WITH CTE AS (
SELECT *, ROW_NUMBER() Over(
	PARTITION BY state, city, orderdate, restaurantname, location, category, dishname, price, rating, ratingcount
    ORDER BY (SELECT NULL)
    ) AS rn
FROM swiggy
)
DELETE FROM CTE WHERE rn>1;


-- CREATING SCHEMA
-- DIMENSION TABLES 

-- DIMENSION TABLE - DATE 
CREATE TABLE dim_date(
	date_id INT AUTO_INCREMENT PRIMARY KEY,
    full_date DATE,
    year INT,
    month INT,
    month_name varchar(20),
    quarter INT,
    day INT,
    week INT
);

-- DIMENSION TABLE - LOCATION
CREATE TABLE dim_location(
	location_id INT auto_increment PRIMARY KEY,
    state VARCHAR(100),
    city VARCHAR(100),
    location VARCHAR(200)
);

-- DIMENSION TABLE - 
CREATE TABLE dim_location(
	location_id INT auto_increment PRIMARY KEY,
    state VARCHAR(100),
    city VARCHAR(100),
    location VARCHAR(200)
);

-- DIMENSION TABLE - RESTAURANT
CREATE TABLE dim_restaurant(
	restaurant_id_id INT auto_increment PRIMARY KEY,
    restaurant_name VARCHAR(200)
);

-- DIMENSION TABLE - CATEGORY
CREATE TABLE dim_category(
	category_id INT auto_increment PRIMARY KEY,
    category VARCHAR(200)
);


-- DIMENSION TABLE - DISH
CREATE TABLE dim_dish(
	dish_id INT auto_increment PRIMARY KEY,
    dish_name VARCHAR(200)
);


-- FACT TABLE
CREATE TABLE fact_swiggy_orders(
	order_id INT AUTO_INCREMENT PRIMARY KEY,
    
    date_id INT,
    price_inr DECIMAL(10,2),
    rating DECIMAL(4,2),
    rating_count INT,
    
    location_id INT,
    restaurant_id INT,
    category_id INT,
    dish_id INT,
    
    FOREIGN KEY (date_id) REFERENCES dim_date(date_id),
    FOREIGN KEY (location_id) REFERENCES dim_location(location_id),
    FOREIGN KEY (restaurant_id) REFERENCES dim_restaurant(restaurant_id),
    FOREIGN KEY (category_id) REFERENCES dim_category(category_id),
    FOREIGN KEY (dish_id) REFERENCES dim_dish(dish_id)
);

SELECT * FROM fact_swiggy_orders;
SELECT * FROM swiggy;

-- INSERT DATA IN DIMENSION TABLES
-- DIM_DATE
INSERT INTO dim_date (full_date, year, month, month_name, quarter, day, week)
SELECT DISTINCT
    orderdate,
    YEAR(orderdate),
    MONTH(orderdate),
    MONTHNAME(orderdate),
    QUARTER(orderdate),
    DAY(orderdate),
    WEEK(orderdate)
FROM swiggy
WHERE orderdate IS NOT NULL;

SELECT * FROM dim_date;

-- DIM_LOCATION
INSERT INTO dim_location (state, city, location)
SELECT DISTINCT
    state,
    city,
    location
FROM swiggy;

SELECT * FROM dim_location;

-- DIM_RESTAURANT
INSERT INTO dim_restaurant (restaurant_name)
SELECT DISTINCT
	restaurantname
FROM swiggy;

SELECT * FROM dim_restaurant;

-- DIM_CATEGORY
INSERT INTO dim_category (category)
SELECT DISTINCT
	category
FROM swiggy;

SELECT * FROM dim_category;

-- DIM_DISH
INSERT INTO dim_dish (dish_name)
SELECT DISTINCT
	dishname
FROM swiggy;

SELECT * FROM dim_dish;

-- INSERTING DATA INTO FACT TABLE
INSERT INTO fact_swiggy_orders
(	date_id,
	price_inr,
	rating, 
    rating_count,
	location_id,
    restaurant_id,
	category_id,
	dish_id)
SELECT
	dd.date_id,
    s.price,
    s.rating,
    s.ratingcount,
	dl.location_id,
	dr.restaurant_id,
    dc.category_id,
    dsh.dish_id
FROM swiggy s

JOIN dim_date dd
	ON dd.full_date = s.orderdate
JOIN dim_location dl
	ON dl.state = s.state
    AND dl.city = s.city
    AND dl.location = s.location
JOIN dim_restaurant dr
	ON dr.restaurant_name = s.restaurantname
JOIN dim_category dc
	ON dc.category = s.category    
JOIN dim_dish dsh
	ON dsh.dish_name=s.dishname;
    
-- VIEWING EVERYTHING IN A TABLE
SELECT * from fact_swiggy_orders f
JOIN dim_date d ON f.date_id = d.date_id
JOIN dim_location l ON f.location_id = l.location_id
JOIN dim_restaurant r ON f.restaurant_id = r.restaurant_id
JOIN dim_category c ON f.category_id = c.category_id
JOIN dim_dish di ON f.dish_id = di.dish_id;


-- KPIs
-- TOTAL ORDERS
SELECT COUNT(*) AS TOTAL_ORDERS 
FROM fact_swiggy_orders;

-- TOTAL REVENUE (INR MILLIONS)
SELECT 
CONCAT(
    FORMAT(SUM(price_inr) / 1000000, 2),
    ' INR MILLION'
) AS total_revenue
FROM fact_swiggy_orders;

-- AVERAGE DISH PRICE
SELECT 
CONCAT(
    FORMAT(AVG(price_inr), 2), ' INR'
) AS AVERAGE_DISH_PRICE
FROM fact_swiggy_orders;

-- AVERAGE RATING
SELECT
AVG(rating)
FROM fact_swiggy_orders;


-- DEEP-DIVE BUSINESS ANALYSIS
-- DATE-BASED ANALYSIS 
-- Monthly Order Trends
SELECT 
d.year,
d.month,
d.month_name,
count(*) as Total_orders
FROM fact_swiggy_orders f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY d.year, d.month, d.month_name
ORDER BY d.month;

-- Quaterly Trends
 SELECT 
d.year,
d.quarter,
count(*) as Total_orders
FROM fact_swiggy_orders f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY d.year, d.quarter
ORDER BY d.quarter;

-- Yearly Trends
SELECT 
d.year,
count(*) as Total_orders
FROM fact_swiggy_orders f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY d.year;

-- Orders by Day of Week (Mon-Sun)
SELECT 
    DAYNAME(d.full_date) AS day_name,
    COUNT(*) AS total_orders
FROM fact_swiggy_orders f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY 
    DAYNAME(d.full_date),
    WEEKDAY(d.full_date)
ORDER BY 
    WEEKDAY(d.full_date);
    

-- LOCATION-BASED ANALYSIS
-- Top 10 cities by order volume
SELECT 
    l.city,
    SUM(f.price_inr) AS total_revenue
FROM fact_swiggy_orders f
JOIN dim_location l
ON l.location_id = f.location_id
GROUP BY l.city
ORDER BY SUM(f.price_inr) DESC
LIMIT 10;

-- Revenue Contribution by states
SELECT 
    l.state,
    SUM(f.price_inr) AS total_revenue
FROM fact_swiggy_orders f
JOIN dim_location l
ON l.location_id = f.location_id
GROUP BY l.city
ORDER BY SUM(f.price_inr) DESC
LIMIT 10;


-- FOOD PERFORMANCE
-- Top 10 restaurants by orders
SELECT 
    r.restaurant_name,
    SUM(f.price_inr) AS total_revenue
FROM fact_swiggy_orders f
JOIN dim_restaurant r
ON r.restaurant_id = f.restaurant_id
GROUP BY r.restaurant_name
ORDER BY SUM(f.price_inr) DESC
LIMIT 10;

-- Top Categories by order volume
SELECT 
    c.category AS category_name,
    COUNT(*) AS total_orders
FROM fact_swiggy_orders AS f
JOIN dim_category AS c
    ON f.category_id = c.category_id
GROUP BY c.category
ORDER BY total_orders DESC
LIMIT 10;

-- Most Ordered dish
SELECT 
    d.dish_name,
    COUNT(*) AS total_orders
FROM fact_swiggy_orders f
JOIN dim_dish d
    ON f.dish_id = d.dish_id
GROUP BY d.dish_name
ORDER BY total_orders DESC
LIMIT 10;

-- Cuisine Performance (Orders/Avg Rating)
SELECT 
    c.category AS category_name,
    COUNT(*) AS total_orders,
    ROUND(AVG(f.rating), 2) AS avg_rating
FROM fact_swiggy_orders AS f
JOIN dim_category c
    ON f.category_id = c.category_id
GROUP BY c.category
ORDER BY total_orders DESC
LIMIT 10;


-- CUSTOMER SPENDING INSIGHTS
-- Total Orders by Price Range
SELECT 
    CASE 
        WHEN price_inr < 100 THEN 'Under 100'
        WHEN price_inr BETWEEN 100 AND 199 THEN '100 - 199'
        WHEN price_inr BETWEEN 200 AND 299 THEN '200 - 299'
        WHEN price_inr BETWEEN 300 AND 499 THEN '300 - 499'
        ELSE '500+'
    END AS price_range,
    COUNT(*) AS total_orders
FROM fact_swiggy_orders
GROUP BY price_range
ORDER BY total_orders DESC;


-- RATING ANALYSIS
SELECT
	rating,
    COUNT(*) AS rating_count
FROM fact_swiggy_orders
GROUP BY rating
ORDER BY rating DESC;