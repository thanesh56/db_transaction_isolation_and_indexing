-- Setup: Create Sample Table and Data
-- set cmd output length
echo $COLUMNS

mysql -uroot -p
--inside mysql hit bellow command along with output of above command, below 158 is output of above command it may very in your system
pager cut -c -158

-- Create test database (optional)
CREATE DATABASE IF NOT EXISTS thanesh_db;


-- Create table
DROP TABLE IF EXISTS `products`;
CREATE TABLE `products` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(60) NOT NULL DEFAULT ' ',
  `unit` int NOT NULL DEFAULT '0',
  `price` double NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
)

-- insert statement
INSERT INTO `products` VALUES (2,'Pen',20,10),(4,'Marker',12,56.45),(5,'Pencil',100,10.45),(6,'book',20,1000),(7,'IPhone16',25,123000),(11,'abc',10,142000),(12,'Ipad',10,142000),(13,'watch',10,140000),(14,'macbook',10,150),(15,'macbook m4',10,200);



use thanesh_db;
-- Default
start transaction;
select * from products;

-- delete from products where name = 'IPad' or name = 'Book';
update products set price=50 where name='Pen';
commit;
select * from products;
select @@transaction_isolation;


-- Read uncommitted
set session transaction isolation level read uncommitted;
start transaction;
select @@transaction_isolation;
select * from products;
update products set price=10 where name='Pen';
select * from products;
select name, (unit*price) total_cost from products where name='Pen';
rollback;
commit;



--Read committed
set session transaction isolation level read committed;
select @@transaction_isolation;
start transaction;
--solution of dirty read
select * from products;
update products set price=10 where name='Pen';
select * from products;
commit;
--problem of repeatable read
select * from products;
select name, (unit*price) total_cost from products where name='Pen';
update products set price=100 where name='Pen';
select * from products;
commit;



-- Repeatable read;
set session transaction isolation level repeatable read;
start transaction;
select @@transaction_isolation;
-- solution
select * from products;
select name, (unit * price) total_cost from products where name='Pen';
update products set price=10 where name='Pen';
select * from products;
-- problem of phantom read
--T1
start transaction;
select @@transaction_isolation;
select * from products; do sleep(10); update products set price = 140000.0 where name = 'IPad'; select * from products;

--T2
insert into products(name, unit, price) values('IPad', 10, 142000.0); commit; select * from products;


-- Serializable;
set session transaction isolation level serializable;
start transaction;
select @@transaction_isolation;
select * from products;
--t1
select * from products; do sleep(10); update products set price = 100.0 where name = 'Book'; select * from products;
--t2
insert into products(name, unit, price) values('Book', 10, 500.0); commit; select * from products;

-- SS Details
-- t_13 to t_28 read uncommitted
-- t_29 to t_51 read committed
-- t_52 to t_71 repeatable read
-- t_72 to serializable