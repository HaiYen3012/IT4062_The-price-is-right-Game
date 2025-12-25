DROP DATABASE IF EXISTS hay_chon_gia_dung;
CREATE DATABASE hay_chon_gia_dung;

USE hay_chon_gia_dung;

-- =========================================================
-- 1. USERS & SESSIONS
-- =========================================================

CREATE TABLE users (
    user_id       INT AUTO_INCREMENT PRIMARY KEY,
    username      VARCHAR(50)  NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login_at DATETIME     NULL,
    is_online     TINYINT(1)   NOT NULL DEFAULT 0
) ;

-- =========================================================
-- 2. ROOMS, ROOM MEMBERS, INVITATIONS
-- =========================================================

CREATE TABLE rooms (
    room_id      INT AUTO_INCREMENT PRIMARY KEY,
    room_code    VARCHAR(10) NOT NULL UNIQUE,
    host_user_id INT NOT NULL,
    status       ENUM('LOBBY','PLAYING','FINISHED','CLOSED') NOT NULL DEFAULT 'LOBBY',
    max_players  INT NOT NULL DEFAULT 6,
    created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_rooms_host_user
        FOREIGN KEY (host_user_id) REFERENCES users(user_id)
        ON DELETE CASCADE
);

CREATE TABLE room_members (
    room_id    INT NOT NULL,
    user_id    INT NOT NULL,
    role       ENUM('PLAYER','SPECTATOR') NOT NULL DEFAULT 'PLAYER',
    joined_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    left_at    DATETIME NULL,
    PRIMARY KEY (room_id, user_id),
    CONSTRAINT fk_room_members_room
        FOREIGN KEY (room_id) REFERENCES rooms(room_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_room_members_user
        FOREIGN KEY (user_id) REFERENCES users(user_id)
        ON DELETE CASCADE
);

CREATE TABLE invitations (
    invitation_id INT AUTO_INCREMENT PRIMARY KEY,
    room_id       INT NOT NULL,
    from_user_id  INT NOT NULL,
    to_user_id    INT NOT NULL,
    status        ENUM('PENDING','ACCEPTED','DECLINED','EXPIRED') NOT NULL DEFAULT 'PENDING',
    created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    responded_at  DATETIME NULL,
    CONSTRAINT fk_invitations_room
        FOREIGN KEY (room_id) REFERENCES rooms(room_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_invitations_from_user
        FOREIGN KEY (from_user_id) REFERENCES users(user_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_invitations_to_user
        FOREIGN KEY (to_user_id) REFERENCES users(user_id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- =========================================================
-- 3. QUESTIONS (CÂU HỎI TRẮC NGHIỆM CHO ROUND 1)
-- =========================================================

CREATE TABLE questions (
    question_id   INT AUTO_INCREMENT PRIMARY KEY,
    question_text TEXT NOT NULL,
    option_a      VARCHAR(255) NOT NULL,
    option_b      VARCHAR(255) NOT NULL,
    option_c      VARCHAR(255) NOT NULL,
    option_d      VARCHAR(255) NOT NULL,
    correct_answer ENUM('A','B','C','D') NOT NULL,
    created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- =========================================================
-- 4. PRODUCTS (SẢN PHẨM DÙNG CHO V1–V4)
-- =========================================================

CREATE TABLE products (
    product_id  INT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(255) NOT NULL,
    description TEXT NULL,
    image_url   VARCHAR(500) NULL,
    base_price  INT NOT NULL,             
    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- =========================================================
-- 5. MATCHES & ROUNDS (V1–V4)
-- =========================================================

CREATE TABLE matches (
    match_id       INT AUTO_INCREMENT PRIMARY KEY,
    room_id        INT NOT NULL,
    started_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ended_at       DATETIME NULL,
    winner_user_id INT NULL,
    current_round  INT NOT NULL DEFAULT 0,
    CONSTRAINT fk_matches_room
        FOREIGN KEY (room_id) REFERENCES rooms(room_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_matches_winner_user
        FOREIGN KEY (winner_user_id) REFERENCES users(user_id)
        ON DELETE SET NULL
);

CREATE TABLE rounds (
    round_id       INT AUTO_INCREMENT PRIMARY KEY,
    match_id       INT NOT NULL,
    round_number   INT NOT NULL DEFAULT 1,
    round_type     ENUM('ROUND1','V1','V2','V3','V4') NOT NULL,
    question_id    INT NULL,
    time_limit_sec INT NOT NULL DEFAULT 15,
    threshold_pct  DECIMAL(5,2) NULL,
    started_at     DATETIME NULL,
    ended_at       DATETIME NULL,
    CONSTRAINT fk_rounds_match
        FOREIGN KEY (match_id) REFERENCES matches(match_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_rounds_question
        FOREIGN KEY (question_id) REFERENCES questions(question_id)
        ON DELETE SET NULL
);

-- =========================================================
-- 6. ROUND_PRODUCTS (SẢN PHẨM TRONG MỖI VÒNG)
-- =========================================================

CREATE TABLE round_products (
    round_product_id INT AUTO_INCREMENT PRIMARY KEY,
    round_id         INT NOT NULL,
    product_id       INT NOT NULL,
    display_order    INT NOT NULL DEFAULT 1,          -- thứ tự hiển thị
    correct_rank     INT NULL,                        -- dùng cho V2: thứ hạng đúng (rẻ->đắt)
    CONSTRAINT fk_round_products_round
        FOREIGN KEY (round_id) REFERENCES rounds(round_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_round_products_product
        FOREIGN KEY (product_id) REFERENCES products(product_id)
        ON DELETE CASCADE
); 

-- =========================================================
-- 7. ROUND_ANSWERS (KẾT QUẢ TRẢ LỜI THEO VÒNG)
-- =========================================================

CREATE TABLE round_answers (
    answer_id           INT AUTO_INCREMENT PRIMARY KEY,
    round_id            INT NOT NULL,
    user_id             INT NOT NULL,
    answer_choice       VARCHAR(50) NULL, -- ROUND1: A/B/C/D, V3: ô quay
    answer_price        INT NULL,         -- V1, V4
    answer_order_json   JSON NULL,        -- V2: thứ tự sản phẩm
    is_correct          TINYINT(1) NOT NULL DEFAULT 0,
    score_awarded       INT NOT NULL DEFAULT 0,
    time_ms             INT NOT NULL DEFAULT 0,
    answer_timestamp    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_eliminated_after TINYINT(1) NOT NULL DEFAULT 0,
    created_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_round_answers_round
        FOREIGN KEY (round_id) REFERENCES rounds(round_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_round_answers_user
        FOREIGN KEY (user_id) REFERENCES users(user_id)
        ON DELETE CASCADE,
    CONSTRAINT uq_round_answers_round_user
        UNIQUE KEY (round_id, user_id)   -- mỗi người 1 answer / vòng
);

-- =========================================================
-- 8. MATCH_EVENTS (LOG & REPLAY)
-- =========================================================

CREATE TABLE match_events (
    event_id    INT AUTO_INCREMENT PRIMARY KEY,
    match_id    INT NOT NULL,
    round_id    INT NULL,
    user_id     INT NULL,
    event_type  VARCHAR(50) NOT NULL,
    event_data  JSON NULL,
    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_match_events_match
        FOREIGN KEY (match_id) REFERENCES matches(match_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_match_events_round
        FOREIGN KEY (round_id) REFERENCES rounds(round_id)
        ON DELETE SET NULL,
    CONSTRAINT fk_match_events_user
        FOREIGN KEY (user_id) REFERENCES users(user_id)
        ON DELETE SET NULL
);

-- =========================================================
-- 9. VIEW THỐNG KÊ NGƯỜI CHƠI (UC33)
-- =========================================================
CREATE OR REPLACE VIEW user_stats AS
SELECT 
    u.user_id,
    u.username,
    COUNT(DISTINCT m.match_id) AS total_matches,
    SUM(CASE WHEN m.winner_user_id = u.user_id THEN 1 ELSE 0 END) AS total_wins,
    COALESCE(SUM(ra.score_awarded), 0) AS total_score
FROM users u
LEFT JOIN round_answers ra ON ra.user_id = u.user_id
LEFT JOIN rounds r ON r.round_id = ra.round_id
LEFT JOIN matches m ON m.match_id = r.match_id
GROUP BY u.user_id, u.username;
ALTER TABLE round_answers ADD UNIQUE INDEX unique_round_user (round_id, user_id);

