-- =================================================================
-- 図書館システム スキーマ定義
-- 作成日: 2025年9月2日
-- =================================================================

-- データベース作成
CREATE DATABASE IF NOT EXISTS library_system 
CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE library_system;

-- =================================================================
-- テーブル作成
-- =================================================================

-- 1. 会員テーブル
CREATE TABLE members (
    member_id INT PRIMARY KEY AUTO_INCREMENT,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20),
    address TEXT,
    registration_date DATE NOT NULL,
    membership_type ENUM('regular', 'student', 'senior', 'premium') DEFAULT 'regular',
    status ENUM('active', 'suspended', 'expired') DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- 2. 著者テーブル
CREATE TABLE authors (
    author_id INT PRIMARY KEY AUTO_INCREMENT,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    birth_date DATE,
    nationality VARCHAR(50),
    biography TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. カテゴリテーブル
CREATE TABLE categories (
    category_id INT PRIMARY KEY AUTO_INCREMENT,
    category_name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    parent_category_id INT,
    FOREIGN KEY (parent_category_id) REFERENCES categories(category_id)
);

-- 4. 書籍テーブル
CREATE TABLE books (
    book_id INT PRIMARY KEY AUTO_INCREMENT,
    isbn VARCHAR(13) UNIQUE,
    title VARCHAR(200) NOT NULL,
    subtitle VARCHAR(200),
    publication_date DATE,
    publisher VARCHAR(100),
    pages INT,
    language VARCHAR(50) DEFAULT 'Japanese',
    category_id INT,
    description TEXT,
    location_shelf VARCHAR(20),
    total_copies INT DEFAULT 1,
    available_copies INT DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(category_id)
);

-- 5. 書籍-著者関連テーブル
CREATE TABLE book_authors (
    book_id INT,
    author_id INT,
    author_role ENUM('primary', 'co-author', 'editor', 'translator') DEFAULT 'primary',
    PRIMARY KEY (book_id, author_id),
    FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE,
    FOREIGN KEY (author_id) REFERENCES authors(author_id) ON DELETE CASCADE
);

-- 6. 貸出記録テーブル
CREATE TABLE loans (
    loan_id INT PRIMARY KEY AUTO_INCREMENT,
    member_id INT NOT NULL,
    book_id INT NOT NULL,
    loan_date DATE NOT NULL,
    due_date DATE NOT NULL,
    return_date DATE,
    renewal_count INT DEFAULT 0,
    status ENUM('active', 'returned', 'overdue', 'lost') DEFAULT 'active',
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (member_id) REFERENCES members(member_id),
    FOREIGN KEY (book_id) REFERENCES books(book_id)
);

-- 7. 予約テーブル
CREATE TABLE reservations (
    reservation_id INT PRIMARY KEY AUTO_INCREMENT,
    member_id INT NOT NULL,
    book_id INT NOT NULL,
    reservation_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expiry_date DATE NOT NULL,
    status ENUM('active', 'fulfilled', 'cancelled', 'expired') DEFAULT 'active',
    priority_order INT,
    FOREIGN KEY (member_id) REFERENCES members(member_id),
    FOREIGN KEY (book_id) REFERENCES books(book_id)
);

-- 8. 延滞料金テーブル
CREATE TABLE fines (
    fine_id INT PRIMARY KEY AUTO_INCREMENT,
    member_id INT NOT NULL,
    loan_id INT,
    amount DECIMAL(10,2) NOT NULL,
    reason VARCHAR(100) NOT NULL,
    fine_date DATE NOT NULL,
    paid_date DATE,
    status ENUM('unpaid', 'paid', 'waived') DEFAULT 'unpaid',
    FOREIGN KEY (member_id) REFERENCES members(member_id),
    FOREIGN KEY (loan_id) REFERENCES loans(loan_id)
);

-- 9. スタッフテーブル
CREATE TABLE staff (
    staff_id INT PRIMARY KEY AUTO_INCREMENT,
    employee_id VARCHAR(20) UNIQUE NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    role ENUM('librarian', 'assistant', 'manager', 'admin') NOT NULL,
    hire_date DATE NOT NULL,
    status ENUM('active', 'inactive') DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 10. 取引ログテーブル
CREATE TABLE transaction_log (
    log_id INT PRIMARY KEY AUTO_INCREMENT,
    transaction_type ENUM('loan', 'return', 'renewal', 'reservation', 'fine_payment') NOT NULL,
    member_id INT,
    book_id INT,
    staff_id INT,
    transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    details JSON,
    FOREIGN KEY (member_id) REFERENCES members(member_id),
    FOREIGN KEY (book_id) REFERENCES books(book_id),
    FOREIGN KEY (staff_id) REFERENCES staff(staff_id)
);

-- =================================================================
-- インデックス作成
-- =================================================================

-- 書籍関連インデックス
CREATE INDEX idx_books_isbn ON books(isbn);
CREATE INDEX idx_books_title ON books(title);
CREATE INDEX idx_books_category ON books(category_id);

-- 貸出関連インデックス
CREATE INDEX idx_loans_member_status ON loans(member_id, status);
CREATE INDEX idx_loans_due_date ON loans(due_date);
CREATE INDEX idx_loans_loan_date ON loans(loan_date);

-- 会員関連インデックス
CREATE INDEX idx_members_email ON members(email);

-- 予約関連インデックス
CREATE INDEX idx_reservations_book_status ON reservations(book_id, status);
CREATE INDEX idx_reservations_member ON reservations(member_id);

-- 延滞料金関連インデックス
CREATE INDEX idx_fines_member_status ON fines(member_id, status);

-- ログ関連インデックス
CREATE INDEX idx_transaction_log_type_date ON transaction_log(transaction_type, transaction_date);
CREATE INDEX idx_transaction_log_member ON transaction_log(member_id);

-- =================================================================
-- ビュー作成
-- =================================================================

-- 利用可能な書籍ビュー
CREATE VIEW available_books AS
SELECT 
    b.book_id,
    b.title,
    b.isbn,
    CONCAT(a.first_name, ' ', a.last_name) AS author_name,
    c.category_name,
    b.available_copies,
    b.location_shelf
FROM books b
LEFT JOIN book_authors ba ON b.book_id = ba.book_id AND ba.author_role = 'primary'
LEFT JOIN authors a ON ba.author_id = a.author_id
LEFT JOIN categories c ON b.category_id = c.category_id
WHERE b.available_copies > 0;

-- 延滞書籍ビュー
CREATE VIEW overdue_books AS
SELECT 
    l.loan_id,
    CONCAT(m.first_name, ' ', m.last_name) AS member_name,
    m.email,
    b.title,
    l.due_date,
    DATEDIFF(CURRENT_DATE, l.due_date) AS days_overdue
FROM loans l
JOIN members m ON l.member_id = m.member_id
JOIN books b ON l.book_id = b.book_id
WHERE l.status = 'active' 
AND l.due_date < CURRENT_DATE;

-- 会員貸出状況ビュー
CREATE VIEW member_loan_status AS
SELECT 
    m.member_id,
    CONCAT(m.first_name, ' ', m.last_name) AS member_name,
    m.email,
    COUNT(CASE WHEN l.status = 'active' THEN 1 END) AS active_loans,
    COUNT(CASE WHEN l.status = 'active' AND l.due_date < CURRENT_DATE THEN 1 END) AS overdue_loans,
    COALESCE(SUM(f.amount), 0) AS unpaid_fines
FROM members m
LEFT JOIN loans l ON m.member_id = l.member_id
LEFT JOIN fines f ON m.member_id = f.member_id AND f.status = 'unpaid'
WHERE m.status = 'active'
GROUP BY m.member_id;