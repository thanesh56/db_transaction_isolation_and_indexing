-- Setup: Create Sample Table and Data
-- set cmd output length
echo $COLUMNS
--inside mysql hit bellow command along with output of above command, below 158 is output of above command it may very in your system
pager cut -c -158

-- Create test database (optional)
CREATE DATABASE IF NOT EXISTS indexing_demo;
USE indexing_demo;

-- Create products table
CREATE TABLE products (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255),
    price DECIMAL(10, 2),
    category VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Insert 100,000 sample records (takes about 10-20 seconds)
DELIMITER //
CREATE PROCEDURE insert_sample_data()
BEGIN
    DECLARE i INT DEFAULT 0;
    WHILE i < 100000 DO
        INSERT INTO products (name, price, category)
        VALUES (
            CONCAT('Product_', FLOOR(RAND() * 1000)),
            RAND() * 100,
            ELT(FLOOR(RAND() * 5) + 1, 'Electronics', 'Clothing', 'Books', 'Home', 'Other')
        );
        SET i = i + 1;
        IF i % 1000 = 0 THEN
            COMMIT;
        END IF;
    END WHILE;
END //
DELIMITER ;

CALL insert_sample_data();
DROP PROCEDURE insert_sample_data;

-- just verify total rows
SELECT COUNT(*) FROM products;
SELECT * FROM products LIMIT 500;



-- Explain query without indexing the with indexing
SHOW INDEX IN products;
EXPLAIN SELECT id FROM products WHERE category = 'Electronics';
CREATE INDEX idx_category ON products(category);
SHOW INDEX IN products;
EXPLAIN SELECT id FROM products WHERE category = 'Electronics';



-- Decide Index prefix size
SELECT
COUNT(DISTINCT(LEFT(name, 1))) as '1',
COUNT(DISTINCT(LEFT(name, 3))) as '3',
COUNT(DISTINCT(LEFT(name, 5))) as '5',
COUNT(DISTINCT(LEFT(name, 10))) as '10',
COUNT(DISTINCT(LEFT(name, 30))) as '30',
COUNT(DISTINCT(LEFT(name, 50))) as '50',
COUNT(DISTINCT(LEFT(name, 100))) as '100',
COUNT(DISTINCT(LEFT(name, 150))) as '150',
COUNT(DISTINCT(LEFT(name, 200))) as '200',
COUNT(DISTINCT(LEFT(name, 250))) as '250'
FROM products;


--Now create index and then explain
CREATE INDEX idx_name ON products(name(30));
EXPLAIN SELECT id FROM products WHERE name LIKE 'Product_16%';


-- Composit index
EXPLAIN SELECT id FROM products WHERE category = 'Electronics' AND price > 50;
CREATE INDEX idx_price_category ON products(price, category);
EXPLAIN SELECT id FROM products USE index(idx_price_category)  WHERE category = 'Electronics' AND price > 50;
CREATE INDEX idx_category_price ON products(category, price);
EXPLAIN SELECT id FROM products USE index(idx_category_price)  WHERE category = 'Electronics' AND price > 50;
DROP INDEX idx_category ON products;

-- When index are ignored
-- case 1
EXPLAIN SELECT id FROM products WHERE price + 50 > 100;
-- slight change
EXPLAIN SELECT id FROM products WHERE price > 50;
-- EXPLAIN SELECT id FROM products USE index(idx_price_category)  WHERE price  > 50;
-- case 2
    EXPLAIN SELECT id FROM products WHERE UPPER(category) = 'ELECTRONICS';
-- slight change
EXPLAIN SELECT id FROM products WHERE category = UPPER('Electronics');

-- Good thing
EXPLAIN SELECT id, category, price FROM products;
EXPLAIN SELECT id, category, price, name FROM products;

-- Now we know that indexes can dramatically speed up the query but too much of the good thing can become bad, so it is important that to watch out the duplicate and redundant indexes
-- Before creating new indexes check existing ones
-- Duplicate Index:
-- (x, y, z), (x, y, z)
-- Redundant index:
-- (x, y), (x) here x is redundant because first one can cover x task




DROP INDEX idx_category ON products;
DROP INDEX idx_price_category ON products;





-- Part 1: Baseline Performance Without Indexes
-- Enable performance measurement
SET profiling = 1;

-- Query 1: Filter on non-indexed column
SELECT * FROM products WHERE category = 'Electronics' LIMIT 1000;

-- Query 2: Range query on non-indexed column
SELECT * FROM products WHERE price BETWEEN 50 AND 60 LIMIT 1000;

-- Query 3: Combined conditions
SELECT * FROM products WHERE category = 'Electronics' AND price > 50 LIMIT 1000;

-- Show performance results
SHOW PROFILES;




-- Part 2: Create Indexes and Test Again
-- Create single-column index

CREATE INDEX idx_category ON products(category);

-- Create composite index
CREATE INDEX idx_price_category ON products(price, category);

-- Rerun the same queries with indexing
-- Query 1 (now uses idx_category)
SELECT * FROM products WHERE category = 'Electronics' LIMIT 1000;

-- Query 2 (now uses idx_price_category)
SELECT * FROM products WHERE price BETWEEN 50 AND 60 LIMIT 1000;

-- Query 3 (now uses composite index)
SELECT * FROM products WHERE category = 'Electronics' AND price > 50 LIMIT 1000;

-- Show comparison
SHOW PROFILES;




-- Part 3: Analyze Index Usage
-- View which indexes are being used
EXPLAIN SELECT * FROM products WHERE category = 'Electronics' AND price > 50;
EXPLAIN SELECT id FROM products USE index(idx_category_price)  WHERE category = 'Electronics' AND price > 50;

-- Check index statistics
SELECT
    table_name,
    index_name,
    stat_value AS pages,
    stat_value * @@innodb_page_size / 1024 / 1024 AS size_mb
FROM
    mysql.innodb_index_stats
WHERE
    database_name = 'indexing_demo'
    AND table_name = 'products'
    AND stat_name = 'size';



-- Part 4: Write Performance Comparison
-- Test insert performance without indexes
DROP INDEX idx_category ON products;
DROP INDEX idx_price_category ON products;

SET @start_time = CURRENT_TIMESTAMP(6);
INSERT INTO products (name, price, category)
SELECT
    CONCAT('New_Product_', FLOOR(RAND() * 1000)),
    RAND() * 100,
    ELT(FLOOR(RAND() * 5) + 1, 'Electronics', 'Clothing', 'Books', 'Home', 'Other')
FROM (SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5) t1,
     (SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5) t2,
     (SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5) t3,
     (SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5) t4
LIMIT 1000;
SET @end_time = CURRENT_TIMESTAMP(6);


    SELECT TIMESTAMPDIFF(MICROSECOND, @start_time, @end_time)/1000 AS 'Insert Time (ms) without indexes';

-- Recreate indexes
CREATE INDEX idx_category ON products(category);
CREATE INDEX idx_price_category ON products(price, category);

-- Test insert performance with indexes
SET @start_time = CURRENT_TIMESTAMP(6);
INSERT INTO products (name, price, category)
SELECT
    CONCAT('New_Product_', FLOOR(RAND() * 1000)),
    RAND() * 100,
    ELT(FLOOR(RAND() * 5) + 1, 'Electronics', 'Clothing', 'Books', 'Home', 'Other')
FROM (SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5) t1,
     (SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5) t2,
     (SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5) t3,
     (SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5) t4
LIMIT 1000;
SET @end_time = CURRENT_TIMESTAMP(6);


SELECT TIMESTAMPDIFF(MICROSECOND, @start_time, @end_time)/1000 AS 'Insert Time (ms) with indexes';


-- my personal host for poc in AWS RDS thaneshdb.clkam4euuhgc.eu-north-1.rds.amazonaws.com
--Part 5: Cleanup
-- Drop the test database (optional)
        DROP DATABASE IF EXISTS indexing_demo;



