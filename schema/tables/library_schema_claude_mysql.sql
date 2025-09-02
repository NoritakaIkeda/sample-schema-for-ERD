-- =================================================================
-- Claude Generated Library Database Schema (MySQL)
-- 図書館システム データベース設計
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

-- =================================================================
-- ストアドプロシージャ
-- =================================================================

-- 書籍貸出処理
DELIMITER //
CREATE PROCEDURE checkout_book(
    IN p_member_id INT,
    IN p_book_id INT,
    IN p_staff_id INT,
    OUT p_result VARCHAR(100)
)
BEGIN
    DECLARE v_available_copies INT;
    DECLARE v_member_status VARCHAR(20);
    DECLARE v_loan_limit INT DEFAULT 5;
    DECLARE v_current_loans INT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_result = 'エラー: 貸出処理に失敗しました';
    END;
    
    START TRANSACTION;
    
    -- 会員ステータス確認
    SELECT status INTO v_member_status 
    FROM members WHERE member_id = p_member_id;
    
    IF v_member_status != 'active' THEN
        SET p_result = 'エラー: 会員ステータスが無効です';
        ROLLBACK;
    ELSE
        -- 在庫確認
        SELECT available_copies INTO v_available_copies 
        FROM books WHERE book_id = p_book_id;
        
        -- 現在の貸出数確認
        SELECT COUNT(*) INTO v_current_loans
        FROM loans 
        WHERE member_id = p_member_id AND status = 'active';
        
        IF v_available_copies <= 0 THEN
            SET p_result = 'エラー: 在庫がありません';
            ROLLBACK;
        ELSEIF v_current_loans >= v_loan_limit THEN
            SET p_result = 'エラー: 貸出上限に達しています';
            ROLLBACK;
        ELSE
            -- 貸出記録作成
            INSERT INTO loans (member_id, book_id, loan_date, due_date)
            VALUES (p_member_id, p_book_id, CURRENT_DATE, DATE_ADD(CURRENT_DATE, INTERVAL 14 DAY));
            
            -- 在庫数更新
            UPDATE books 
            SET available_copies = available_copies - 1 
            WHERE book_id = p_book_id;
            
            -- ログ記録
            INSERT INTO transaction_log (transaction_type, member_id, book_id, staff_id, details)
            VALUES ('loan', p_member_id, p_book_id, p_staff_id, 
                   JSON_OBJECT('loan_id', LAST_INSERT_ID()));
            
            SET p_result = '成功: 貸出処理が完了しました';
            COMMIT;
        END IF;
    END IF;
END //
DELIMITER ;

-- 書籍返却処理
DELIMITER //
CREATE PROCEDURE return_book(
    IN p_loan_id INT,
    IN p_staff_id INT,
    OUT p_result VARCHAR(100)
)
BEGIN
    DECLARE v_book_id INT;
    DECLARE v_member_id INT;
    DECLARE v_due_date DATE;
    DECLARE v_fine_amount DECIMAL(10,2) DEFAULT 0;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_result = 'エラー: 返却処理に失敗しました';
    END;
    
    START TRANSACTION;
    
    -- 貸出情報取得
    SELECT book_id, member_id, due_date 
    INTO v_book_id, v_member_id, v_due_date
    FROM loans 
    WHERE loan_id = p_loan_id AND status = 'active';
    
    IF v_book_id IS NULL THEN
        SET p_result = 'エラー: 有効な貸出記録が見つかりません';
        ROLLBACK;
    ELSE
        -- 延滞料金計算
        IF CURRENT_DATE > v_due_date THEN
            SET v_fine_amount = DATEDIFF(CURRENT_DATE, v_due_date) * 10; -- 1日10円
            
            INSERT INTO fines (member_id, loan_id, amount, reason, fine_date)
            VALUES (v_member_id, p_loan_id, v_fine_amount, '延滞料金', CURRENT_DATE);
        END IF;
        
        -- 返却処理
        UPDATE loans 
        SET return_date = CURRENT_DATE, status = 'returned'
        WHERE loan_id = p_loan_id;
        
        -- 在庫数更新
        UPDATE books 
        SET available_copies = available_copies + 1 
        WHERE book_id = v_book_id;
        
        -- ログ記録
        INSERT INTO transaction_log (transaction_type, member_id, book_id, staff_id, details)
        VALUES ('return', v_member_id, v_book_id, p_staff_id, 
               JSON_OBJECT('loan_id', p_loan_id, 'fine_amount', v_fine_amount));
        
        IF v_fine_amount > 0 THEN
            SET p_result = CONCAT('成功: 返却完了（延滞料金: ¥', v_fine_amount, '）');
        ELSE
            SET p_result = '成功: 返却処理が完了しました';
        END IF;
        
        COMMIT;
    END IF;
END //
DELIMITER ;

-- 書籍更新処理
DELIMITER //
CREATE PROCEDURE renew_book(
    IN p_loan_id INT,
    IN p_staff_id INT,
    OUT p_result VARCHAR(100)
)
BEGIN
    DECLARE v_renewal_count INT;
    DECLARE v_max_renewals INT DEFAULT 2;
    DECLARE v_member_id INT;
    DECLARE v_book_id INT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_result = 'エラー: 更新処理に失敗しました';
    END;
    
    START TRANSACTION;
    
    SELECT renewal_count, member_id, book_id
    INTO v_renewal_count, v_member_id, v_book_id
    FROM loans 
    WHERE loan_id = p_loan_id AND status = 'active';
    
    IF v_renewal_count >= v_max_renewals THEN
        SET p_result = 'エラー: 更新上限に達しています';
        ROLLBACK;
    ELSE
        UPDATE loans 
        SET due_date = DATE_ADD(due_date, INTERVAL 14 DAY),
            renewal_count = renewal_count + 1
        WHERE loan_id = p_loan_id;
        
        INSERT INTO transaction_log (transaction_type, member_id, book_id, staff_id, details)
        VALUES ('renewal', v_member_id, v_book_id, p_staff_id, 
               JSON_OBJECT('loan_id', p_loan_id, 'renewal_count', v_renewal_count + 1));
        
        SET p_result = '成功: 貸出期間を延長しました';
        COMMIT;
    END IF;
END //
DELIMITER ;

-- =================================================================
-- トリガー作成
-- =================================================================

-- 在庫数自動更新トリガー
DELIMITER //
CREATE TRIGGER update_book_availability
AFTER UPDATE ON loans
FOR EACH ROW
BEGIN
    IF OLD.status = 'active' AND NEW.status = 'returned' THEN
        UPDATE books 
        SET available_copies = available_copies + 1 
        WHERE book_id = NEW.book_id;
    END IF;
END //
DELIMITER ;

-- 延滞ステータス自動更新トリガー
DELIMITER //
CREATE TRIGGER update_overdue_status
BEFORE UPDATE ON loans
FOR EACH ROW
BEGIN
    IF NEW.status = 'active' AND NEW.due_date < CURRENT_DATE THEN
        SET NEW.status = 'overdue';
    END IF;
END //
DELIMITER ;

-- =================================================================
-- サンプルデータ挿入
-- =================================================================

-- カテゴリサンプル
INSERT INTO categories (category_name, description) VALUES
('文学', '小説、詩、戯曲など'),
('科学技術', 'コンピュータ、工学、自然科学'),
('歴史', '日本史、世界史、伝記'),
('芸術', '美術、音楽、映画'),
('ビジネス', '経営、マーケティング、自己啓発'),
('語学', '英語、中国語、その他外国語'),
('児童書', '絵本、児童文学'),
('参考書', '辞書、百科事典、専門書');

-- 著者サンプル
INSERT INTO authors (first_name, last_name, nationality) VALUES
('夏目', '漱石', '日本'),
('村上', '春樹', '日本'),
('太宰', '治', '日本'),
('ジョージ', 'オーウェル', 'イギリス'),
('アガサ', 'クリスティ', 'イギリス'),
('スティーブン', 'キング', 'アメリカ');

-- 書籍サンプル
INSERT INTO books (isbn, title, publication_date, publisher, pages, category_id, location_shelf, total_copies, available_copies) VALUES
('9784101010014', 'こころ', '2003-05-10', '新潮社', 280, 1, 'A-01', 3, 2),
('9784062748681', 'ノルウェイの森', '2004-09-15', '講談社', 560, 1, 'A-02', 2, 1),
('9784101006048', '人間失格', '2006-02-20', '新潮社', 180, 1, 'A-03', 2, 2),
('9780141182704', '1984', '2008-03-01', 'Penguin Classics', 400, 1, 'B-01', 1, 0),
('9780007119318', 'そして誰もいなくなった', '2010-04-15', 'HarperCollins', 320, 1, 'B-02', 2, 1);

-- 書籍-著者関連サンプル
INSERT INTO book_authors (book_id, author_id, author_role) VALUES
(1, 1, 'primary'),
(2, 2, 'primary'),
(3, 3, 'primary'),
(4, 4, 'primary'),
(5, 5, 'primary');

-- 会員サンプル
INSERT INTO members (first_name, last_name, email, phone, address, registration_date, membership_type) VALUES
('田中', '太郎', 'tanaka@example.com', '090-1234-5678', '東京都渋谷区1-1-1', '2024-01-15', 'regular'),
('佐藤', '花子', 'sato@example.com', '090-2345-6789', '東京都新宿区2-2-2', '2024-02-20', 'student'),
('山田', '次郎', 'yamada@example.com', '090-3456-7890', '東京都港区3-3-3', '2024-03-10', 'premium');

-- スタッフサンプル
INSERT INTO staff (employee_id, first_name, last_name, email, role, hire_date) VALUES
('EMP001', '図書', '管理子', 'librarian@library.com', 'librarian', '2023-04-01'),
('EMP002', '図書館', '長', 'manager@library.com', 'manager', '2023-01-15'),
('EMP003', 'システム', '管理者', 'admin@library.com', 'admin', '2023-01-01');

-- =================================================================
-- 有用なクエリ（コメント形式で記載）
-- =================================================================

/*
-- 1. 会員の現在の貸出状況
SELECT 
    m.first_name,
    m.last_name,
    b.title,
    l.loan_date,
    l.due_date,
    CASE 
        WHEN l.due_date < CURRENT_DATE THEN '延滞'
        WHEN DATEDIFF(l.due_date, CURRENT_DATE) <= 3 THEN '返却期限間近'
        ELSE '正常'
    END AS status
FROM loans l
JOIN members m ON l.member_id = m.member_id
JOIN books b ON l.book_id = b.book_id
WHERE l.status = 'active'
ORDER BY l.due_date;

-- 2. 人気書籍ランキング（過去1年）
SELECT 
    b.title,
    CONCAT(a.first_name, ' ', a.last_name) AS author_name,
    COUNT(l.loan_id) AS loan_count,
    AVG(DATEDIFF(COALESCE(l.return_date, CURRENT_DATE), l.loan_date)) AS avg_loan_days
FROM books b
JOIN book_authors ba ON b.book_id = ba.book_id AND ba.author_role = 'primary'
JOIN authors a ON ba.author_id = a.author_id
JOIN loans l ON b.book_id = l.book_id
WHERE l.loan_date >= DATE_SUB(CURRENT_DATE, INTERVAL 1 YEAR)
GROUP BY b.book_id, a.author_id
ORDER BY loan_count DESC
LIMIT 20;

-- 3. 延滞者リスト
SELECT 
    m.member_id,
    CONCAT(m.first_name, ' ', m.last_name) AS member_name,
    m.email,
    m.phone,
    COUNT(l.loan_id) AS overdue_books,
    SUM(DATEDIFF(CURRENT_DATE, l.due_date) * 10) AS total_fine
FROM members m
JOIN loans l ON m.member_id = l.member_id
WHERE l.status IN ('active', 'overdue') 
AND l.due_date < CURRENT_DATE
GROUP BY m.member_id
ORDER BY total_fine DESC;

-- 4. 月別貸出統計
SELECT 
    YEAR(loan_date) AS year,
    MONTH(loan_date) AS month,
    COUNT(*) AS total_loans,
    COUNT(DISTINCT member_id) AS unique_members,
    COUNT(DISTINCT book_id) AS unique_books
FROM loans
WHERE loan_date >= DATE_SUB(CURRENT_DATE, INTERVAL 1 YEAR)
GROUP BY YEAR(loan_date), MONTH(loan_date)
ORDER BY year DESC, month DESC;

-- 5. 書籍検索（タイトルまたは著者名）
SELECT 
    b.book_id,
    b.title,
    CONCAT(a.first_name, ' ', a.last_name) AS author_name,
    c.category_name,
    b.available_copies,
    b.location_shelf
FROM books b
LEFT JOIN book_authors ba ON b.book_id = ba.book_id AND ba.author_role = 'primary'
LEFT JOIN authors a ON ba.author_id = a.author_id
LEFT JOIN categories c ON b.category_id = c.category_id
WHERE b.title LIKE '%検索キーワード%' 
   OR CONCAT(a.first_name, ' ', a.last_name) LIKE '%検索キーワード%'
ORDER BY b.title;

-- 6. 予約待ちリスト
SELECT 
    r.reservation_id,
    CONCAT(m.first_name, ' ', m.last_name) AS member_name,
    b.title,
    r.reservation_date,
    r.expiry_date,
    ROW_NUMBER() OVER (PARTITION BY r.book_id ORDER BY r.reservation_date) AS queue_position
FROM reservations r
JOIN members m ON r.member_id = m.member_id
JOIN books b ON r.book_id = b.book_id
WHERE r.status = 'active'
ORDER BY r.book_id, r.reservation_date;
*/

-- =================================================================
-- ユーザー権限設定
-- =================================================================

-- ロール作成
CREATE ROLE IF NOT EXISTS 'librarian_role';
CREATE ROLE IF NOT EXISTS 'admin_role';
CREATE ROLE IF NOT EXISTS 'readonly_role';

-- 司書用権限
GRANT SELECT, INSERT, UPDATE ON members TO 'librarian_role';
GRANT SELECT, INSERT, UPDATE ON loans TO 'librarian_role';
GRANT SELECT, INSERT, UPDATE ON reservations TO 'librarian_role';
GRANT SELECT, INSERT, UPDATE ON fines TO 'librarian_role';
GRANT SELECT ON books TO 'librarian_role';
GRANT SELECT ON authors TO 'librarian_role';
GRANT SELECT ON categories TO 'librarian_role';
GRANT EXECUTE ON PROCEDURE checkout_book TO 'librarian_role';
GRANT EXECUTE ON PROCEDURE return_book TO 'librarian_role';
GRANT EXECUTE ON PROCEDURE renew_book TO 'librarian_role';

-- 管理者用権限
GRANT ALL PRIVILEGES ON library_system.* TO 'admin_role';

-- 読み取り専用権限
GRANT SELECT ON books TO 'readonly_role';
GRANT SELECT ON authors TO 'readonly_role';
GRANT SELECT ON categories TO 'readonly_role';
GRANT SELECT ON available_books TO 'readonly_role';

-- =================================================================
-- メンテナンス用クエリ
-- =================================================================

/*
-- 統計情報更新
ANALYZE TABLE books, members, loans, reservations, fines;

-- インデックス最適化
OPTIMIZE TABLE loans, transaction_log;

-- 古いログデータのアーカイブ（1年以上前）
CREATE TABLE transaction_log_archive LIKE transaction_log;

INSERT INTO transaction_log_archive 
SELECT * FROM transaction_log 
WHERE transaction_date < DATE_SUB(CURRENT_DATE, INTERVAL 1 YEAR);

DELETE FROM transaction_log 
WHERE transaction_date < DATE_SUB(CURRENT_DATE, INTERVAL 1 YEAR);

-- 期限切れ予約の自動キャンセル
UPDATE reservations 
SET status = 'expired' 
WHERE status = 'active' 
AND expiry_date < CURRENT_DATE;
*/

-- =================================================================
-- 実行完了
-- =================================================================
SELECT 'Library Database System created successfully!' AS message;