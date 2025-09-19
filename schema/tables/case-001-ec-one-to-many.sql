-- Generated SQL Schema from case-001-ec-one-to-many.json
-- Simple e-commerce schema with categories and products (one-to-many relationship)

CREATE TABLE categories (
    id INT NOT NULL,
    name VARCHAR(100) NOT NULL,
    CONSTRAINT pk_categories PRIMARY KEY (id)
);
COMMENT ON TABLE categories IS 'Product categories';
COMMENT ON COLUMN categories.id IS 'Category ID';
COMMENT ON COLUMN categories.name IS 'Category name';

CREATE TABLE products (
    id INT NOT NULL,
    name VARCHAR(150) NOT NULL,
    category_id INT NOT NULL,
    CONSTRAINT pk_products PRIMARY KEY (id),
    CONSTRAINT fk_products_category FOREIGN KEY (category_id) REFERENCES categories(id) ON UPDATE CASCADE ON DELETE RESTRICT
);
COMMENT ON TABLE products IS 'Products managed in the catalog';
COMMENT ON COLUMN products.id IS 'Product ID';
COMMENT ON COLUMN products.name IS 'Product name';
COMMENT ON COLUMN products.category_id IS 'FK to categories.id';
