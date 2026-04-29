# 🍽️ Swiggy Sales Analysis — MySQL Project

> **End-to-end SQL project covering data cleaning, star schema dimensional modelling, and deep-dive KPI analysis on a real-world Swiggy food delivery dataset.**

---

![Swiggy Sales Analysis Banner](./banner.png)

---

## 📌 Table of Contents

- [Project Overview](#-project-overview)
- [Dataset Description](#-dataset-description)
- [Project Architecture](#-project-architecture)
- [Phase 1 — Data Cleaning & Validation](#-phase-1--data-cleaning--validation)
- [Phase 2 — Dimensional Modelling (Star Schema)](#-phase-2--dimensional-modelling-star-schema)
- [Phase 3 — KPI Development & Business Analysis](#-phase-3--kpi-development--business-analysis)
- [Key Insights](#-key-insights)
- [Tools Used](#-tools-used)
- [How to Run](#-how-to-run)
- [Folder Structure](#-folder-structure)
- [Author](#-author)

---

## 📖 Project Overview

This project performs a **full analytical lifecycle** on a Swiggy food delivery dataset using **MySQL**. The workflow starts from raw, unclean data and progresses through validation, dimensional modelling, and business intelligence reporting.

The project answers critical business questions such as:

- Which cities and states drive the most orders and revenue?
- What are the top-performing restaurants, cuisines, and dishes?
- How does order volume trend across months, quarters, and days of the week?
- What does the customer spending distribution look like?
- How are dish ratings distributed across the platform?

---

## 📦 Dataset Description

The raw source table `swiggy_data` contains food delivery transaction records with the following fields:

| Column | Description |
|---|---|
| `State` | Indian state where the order was placed |
| `City` | City of delivery |
| `Order_Date` | Date the order was placed |
| `Restaurant_Name` | Name of the restaurant |
| `Location` | Specific locality/area within the city |
| `Category` | Cuisine category (e.g., Indian, Chinese, Italian) |
| `Dish_Name` | Name of the dish ordered |
| `Price_INR` | Price of the dish in Indian Rupees |
| `Rating` | Dish/restaurant rating (1–5 scale) |
| `Rating_Count` | Number of ratings received |

---

## 🏗️ Project Architecture

```
Raw Data (swiggy_data)
        │
        ▼
┌─────────────────────┐
│  Phase 1            │
│  Data Cleaning &    │
│  Validation         │
│  - Null Checks      │
│  - Blank Checks     │
│  - Duplicate Find   │
│  - Duplicate Remove │
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│  Phase 2            │
│  Star Schema        │
│  Dimensional Model  │
│  - dim_date         │
│  - dim_location     │
│  - dim_restaurant   │
│  - dim_category     │
│  - dim_dish         │
│  - fact_swiggy_orders│
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│  Phase 3            │
│  KPI Analysis &     │
│  Business Insights  │
└─────────────────────┘
```

---

## 🧹 Phase 1 — Data Cleaning & Validation

### 1.1 Null Check
Identified missing values across all business-critical columns:
```sql
SELECT
    SUM(CASE WHEN State IS NULL THEN 1 ELSE 0 END)           AS null_state,
    SUM(CASE WHEN City IS NULL THEN 1 ELSE 0 END)            AS null_city,
    SUM(CASE WHEN Order_Date IS NULL THEN 1 ELSE 0 END)      AS null_order_date,
    SUM(CASE WHEN Restaurant_Name IS NULL THEN 1 ELSE 0 END) AS null_restaurant,
    SUM(CASE WHEN Location IS NULL THEN 1 ELSE 0 END)        AS null_location,
    SUM(CASE WHEN Category IS NULL THEN 1 ELSE 0 END)        AS null_category,
    SUM(CASE WHEN Dish_Name IS NULL THEN 1 ELSE 0 END)       AS null_dish,
    SUM(CASE WHEN Price_INR IS NULL THEN 1 ELSE 0 END)       AS null_price,
    SUM(CASE WHEN Rating IS NULL THEN 1 ELSE 0 END)          AS null_rating,
    SUM(CASE WHEN Rating_Count IS NULL THEN 1 ELSE 0 END)    AS null_rating_count
FROM swiggy_data;
```

### 1.2 Blank / Empty String Check
Detected fields containing blank values that could silently distort aggregations:
```sql
SELECT *
FROM swiggy_data
WHERE TRIM(State) = ''
   OR TRIM(City) = ''
   OR TRIM(Restaurant_Name) = ''
   OR TRIM(Location) = ''
   OR TRIM(Category) = ''
   OR TRIM(Dish_Name) = '';
```

### 1.3 Duplicate Detection
Grouped on all business-critical columns to surface exact duplicate records:
```sql
SELECT
    State, City, Order_Date, Restaurant_Name, Location,
    Category, Dish_Name, Price_INR, Rating, Rating_Count,
    COUNT(*) AS duplicate_count
FROM swiggy_data
GROUP BY
    State, City, Order_Date, Restaurant_Name, Location,
    Category, Dish_Name, Price_INR, Rating, Rating_Count
HAVING COUNT(*) > 1;
```

### 1.4 Duplicate Removal
Used `ROW_NUMBER()` to retain exactly one clean copy of each unique record and delete all surplus duplicates:
```sql
WITH ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY State, City, Order_Date, Restaurant_Name,
                            Location, Category, Dish_Name, Price_INR,
                            Rating, Rating_Count
               ORDER BY (SELECT NULL)
           ) AS rn
    FROM swiggy_data
)
DELETE FROM swiggy_data
WHERE id IN (
    SELECT id FROM ranked WHERE rn > 1
);
```

---

## ⭐ Phase 2 — Dimensional Modelling (Star Schema)

A **Star Schema** was built to organize data for fast, reliable analytical queries and BI reporting. Descriptive attributes are separated into small, focused dimension tables, while all measurable values sit in a central fact table.

### Why Star Schema?
- Reduces data duplication across tables
- Makes aggregations faster and more accurate
- Seamlessly integrates with BI tools (Power BI, Tableau, Looker)
- Provides a clean, scalable foundation for any reporting layer

---

### ERD — Star Schema

```
                    ┌──────────────┐
                    │   dim_date   │
                    │──────────────│
                    │ date_id (PK) │
                    │ order_date   │
                    │ year         │
                    │ month        │
                    │ quarter      │
                    │ week         │
                    └──────┬───────┘
                           │
┌───────────────┐          │          ┌──────────────────┐
│ dim_location  │          │          │  dim_restaurant  │
│───────────────│          │          │──────────────────│
│location_id(PK)│          │          │restaurant_id(PK) │
│ state         │          │          │ restaurant_name  │
│ city          │◄─────────┼─────────►│                  │
│ location      │          │          └──────────────────┘
└───────────────┘          │
                    ┌──────┴──────────────┐
                    │  fact_swiggy_orders │
                    │─────────────────────│
                    │ order_id (PK)       │
                    │ date_id (FK)        │
                    │ location_id (FK)    │
                    │ restaurant_id (FK)  │
                    │ category_id (FK)    │
                    │ dish_id (FK)        │
                    │ price_inr           │
                    │ rating              │
                    │ rating_count        │
                    └──────┬──────────────┘
                           │
        ┌──────────────────┼────────────────┐
        │                  │                │
┌───────┴──────┐   ┌───────┴──────┐         │
│ dim_category │   │   dim_dish   │         │
│──────────────│   │──────────────│         │
│category_id(PK│   │ dish_id (PK) │         │
│ category     │   │ dish_name    │         │
└──────────────┘   └──────────────┘         │
```

### Dimension Tables

```sql
-- dim_date
CREATE TABLE dim_date AS
SELECT DISTINCT
    ROW_NUMBER() OVER () AS date_id,
    Order_Date,
    YEAR(Order_Date)    AS year,
    MONTH(Order_Date)   AS month,
    QUARTER(Order_Date) AS quarter,
    WEEK(Order_Date)    AS week
FROM swiggy_data;

-- dim_location
CREATE TABLE dim_location AS
SELECT DISTINCT
    ROW_NUMBER() OVER () AS location_id,
    State, City, Location
FROM swiggy_data;

-- dim_restaurant
CREATE TABLE dim_restaurant AS
SELECT DISTINCT
    ROW_NUMBER() OVER () AS restaurant_id,
    Restaurant_Name
FROM swiggy_data;

-- dim_category
CREATE TABLE dim_category AS
SELECT DISTINCT
    ROW_NUMBER() OVER () AS category_id,
    Category
FROM swiggy_data;

-- dim_dish
CREATE TABLE dim_dish AS
SELECT DISTINCT
    ROW_NUMBER() OVER () AS dish_id,
    Dish_Name
FROM swiggy_data;
```

### Fact Table

```sql
CREATE TABLE fact_swiggy_orders AS
SELECT
    s.Price_INR,
    s.Rating,
    s.Rating_Count,
    d.date_id,
    l.location_id,
    r.restaurant_id,
    c.category_id,
    di.dish_id
FROM swiggy_data s
JOIN dim_date       d  ON s.Order_Date       = d.Order_Date
JOIN dim_location   l  ON s.State = l.State AND s.City = l.City AND s.Location = l.Location
JOIN dim_restaurant r  ON s.Restaurant_Name  = r.Restaurant_Name
JOIN dim_category   c  ON s.Category         = c.Category
JOIN dim_dish       di ON s.Dish_Name        = di.Dish_Name;
```

---

## 📊 Phase 3 — KPI Development & Business Analysis

### 3.1 Basic KPIs

```sql
SELECT
    COUNT(*)                          AS total_orders,
    ROUND(SUM(price_inr)/1000000, 2)  AS total_revenue_million_inr,
    ROUND(AVG(price_inr), 2)          AS avg_dish_price,
    ROUND(AVG(rating), 2)             AS avg_rating
FROM fact_swiggy_orders;
```

---

### 3.2 Date-Based Analysis

**Monthly Order Trends**
```sql
SELECT month, COUNT(*) AS total_orders
FROM fact_swiggy_orders f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY month ORDER BY month;
```

**Quarterly Order Trends**
```sql
SELECT quarter, COUNT(*) AS total_orders
FROM fact_swiggy_orders f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY quarter ORDER BY quarter;
```

**Year-wise Growth**
```sql
SELECT year, COUNT(*) AS total_orders
FROM fact_swiggy_orders f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY year ORDER BY year;
```

**Day-of-Week Patterns**
```sql
SELECT DAYNAME(d.Order_Date) AS day_name, COUNT(*) AS total_orders
FROM fact_swiggy_orders f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY day_name ORDER BY FIELD(day_name,'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday');
```

---

### 3.3 Location-Based Analysis

**Top 10 Cities by Order Volume**
```sql
SELECT l.city, COUNT(*) AS total_orders
FROM fact_swiggy_orders f
JOIN dim_location l ON f.location_id = l.location_id
GROUP BY l.city ORDER BY total_orders DESC LIMIT 10;
```

**Revenue Contribution by State**
```sql
SELECT l.state, ROUND(SUM(f.price_inr)/1000000, 2) AS revenue_million_inr
FROM fact_swiggy_orders f
JOIN dim_location l ON f.location_id = l.location_id
GROUP BY l.state ORDER BY revenue_million_inr DESC;
```

---

### 3.4 Food Performance

**Top 10 Restaurants by Orders**
```sql
SELECT r.restaurant_name, COUNT(*) AS total_orders
FROM fact_swiggy_orders f
JOIN dim_restaurant r ON f.restaurant_id = r.restaurant_id
GROUP BY r.restaurant_name ORDER BY total_orders DESC LIMIT 10;
```

**Top Cuisine Categories**
```sql
SELECT c.category, COUNT(*) AS total_orders
FROM fact_swiggy_orders f
JOIN dim_category c ON f.category_id = c.category_id
GROUP BY c.category ORDER BY total_orders DESC;
```

**Most Ordered Dishes**
```sql
SELECT d.dish_name, COUNT(*) AS total_orders
FROM fact_swiggy_orders f
JOIN dim_dish d ON f.dish_id = d.dish_id
GROUP BY d.dish_name ORDER BY total_orders DESC LIMIT 10;
```

**Cuisine Performance — Orders + Avg Rating**
```sql
SELECT
    c.category,
    COUNT(*)           AS total_orders,
    ROUND(AVG(f.rating), 2) AS avg_rating
FROM fact_swiggy_orders f
JOIN dim_category c ON f.category_id = c.category_id
GROUP BY c.category ORDER BY total_orders DESC;
```

---

### 3.5 Customer Spending Insights

```sql
SELECT
    CASE
        WHEN price_inr < 100             THEN 'Under ₹100'
        WHEN price_inr BETWEEN 100 AND 199 THEN '₹100–₹199'
        WHEN price_inr BETWEEN 200 AND 299 THEN '₹200–₹299'
        WHEN price_inr BETWEEN 300 AND 499 THEN '₹300–₹499'
        ELSE '₹500+'
    END AS spend_bucket,
    COUNT(*) AS total_orders
FROM fact_swiggy_orders
GROUP BY spend_bucket
ORDER BY FIELD(spend_bucket,'Under ₹100','₹100–₹199','₹200–₹299','₹300–₹499','₹500+');
```

---

### 3.6 Ratings Distribution

```sql
SELECT
    FLOOR(rating) AS rating_band,
    COUNT(*)      AS total_dishes
FROM fact_swiggy_orders
GROUP BY rating_band
ORDER BY rating_band;
```

---

## 💡 Key Insights

| Insight | Finding |
|---|---|
| 📍 **Top City** | Identified the city with highest order volume |
| 🏆 **Best Cuisine** | Indian food dominates order share |
| 💰 **Revenue Leader** | Top state contributes majority of INR revenue |
| 📅 **Peak Day** | Weekends show significantly higher order volume |
| ⭐ **Avg Platform Rating** | Computed across all dishes on the platform |
| 🛒 **Most Popular Spend** | Majority of orders fall in the ₹100–₹299 range |

---

## 🛠️ Tools Used

| Tool | Purpose |
|---|---|
| **MySQL 8.0** | All SQL queries, data cleaning, schema creation |
| **MySQL Workbench** | Query execution and ERD visualization |
| **GitHub** | Version control and project showcase |

---

## ▶️ How to Run

1. **Clone this repository**
   ```bash
   git clone https://github.com/your-username/swiggy-sales-analysis.git
   cd swiggy-sales-analysis
   ```

2. **Import the raw data**
   ```bash
   mysql -u root -p your_database < data/swiggy_data.sql
   ```

3. **Run scripts in order**
   ```
   sql/01_data_cleaning.sql
   sql/02_star_schema.sql
   sql/03_kpi_analysis.sql
   ```

4. **Explore the results** in MySQL Workbench or any compatible SQL client.

---

## 📁 Folder Structure

```
swiggy-sales-analysis/
│
├── data/
│   └── swiggy_data.sql          # Raw dataset import file
│
├── sql/
│   ├── 01_data_cleaning.sql     # Null checks, blank checks, deduplication
│   ├── 02_star_schema.sql       # Dimension & fact table creation
│   └── 03_kpi_analysis.sql      # All KPI and business analysis queries
│
├── images/
│   └── banner.png               # Project banner / ERD screenshot
│
└── README.md
```

---

## 👤 Author

**Your Name**
- 💼 [LinkedIn](https://linkedin.com/in/your-profile)
- 🐙 [GitHub](https://github.com/your-username)
- 📧 your.email@example.com

---

> ⭐ *If you found this project helpful, consider giving it a star on GitHub!*
