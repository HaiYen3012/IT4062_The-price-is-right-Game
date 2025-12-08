USE hay_chon_gia_dung;

-- =========================================================
-- 0. XÓA DỮ LIỆU CŨ (nếu có) ĐỂ SEED LẠI CHO SẠCH
-- =========================================================
SET FOREIGN_KEY_CHECKS = 0;

TRUNCATE TABLE match_events;
TRUNCATE TABLE round_answers;
TRUNCATE TABLE round_products;
TRUNCATE TABLE rounds;
TRUNCATE TABLE matches;
TRUNCATE TABLE invitations;
TRUNCATE TABLE room_members;
TRUNCATE TABLE rooms;
TRUNCATE TABLE products;
TRUNCATE TABLE users;

SET FOREIGN_KEY_CHECKS = 1;

-- =========================================================
-- 1. USERS
-- =========================================================
-- Giả sử mật khẩu lưu dạng plain '123456' (sau này bạn hash sau cũng được)
INSERT INTO users (user_id, username, password_hash, is_online, created_at)
VALUES 
  (1, 'nhung', '123456', 0, NOW()),
  (2, 'duyen', '123456', 0, NOW()),
  (3, 'ha',    '123456', 0, NOW()),
  (4, 'yen',   '123456', 0, NOW()),
  (5, 'guest1','123456', 0, NOW());

-- =========================================================
-- 2. ROOMS
-- =========================================================
-- ROOM01: 1 trận đã chơi xong
-- ROOM02: đang ở LOBBY, chưa chơi
INSERT INTO rooms (room_id, room_code, host_user_id, status, max_players, created_at)
VALUES 
  (1, 'ROOM01', 1, 'FINISHED', 4, NOW()),
  (2, 'ROOM02', 2, 'LOBBY',    6, NOW());

-- =========================================================
-- 3. ROOM_MEMBERS
-- =========================================================
-- Room 1: 4 người đã từng tham gia
INSERT INTO room_members (room_id, user_id, role, joined_at, left_at)
VALUES
  (1, 1, 'PLAYER',    NOW(), NOW()),
  (1, 2, 'PLAYER',    NOW(), NOW()),
  (1, 3, 'PLAYER',    NOW(), NOW()),
  (1, 4, 'PLAYER',    NOW(), NOW());

-- Room 2: 3 người đang ngồi trong phòng
INSERT INTO room_members (room_id, user_id, role, joined_at, left_at)
VALUES
  (2, 2, 'PLAYER',    NOW(), NULL),
  (2, 3, 'PLAYER',    NOW(), NULL),
  (2, 5, 'SPECTATOR', NOW(), NULL);

-- =========================================================
-- 4. INVITATIONS
-- =========================================================
INSERT INTO invitations (invitation_id, room_id, from_user_id, to_user_id, status, created_at, responded_at)
VALUES 
  (1, 2, 2, 1, 'PENDING',  NOW(), NULL),       -- Duyên mời Nhung vào ROOM02
  (2, 2, 2, 4, 'ACCEPTED', NOW(), NOW());      -- mời Yến, đã accept

-- =========================================================
-- 5. QUESTIONS (CÂU HỎI TRẮC NGHIỆM CHO ROUND 1)
-- =========================================================
INSERT INTO questions (question_id, question_text, option_a, option_b, option_c, option_d, correct_answer, created_at)
VALUES
  (1, 'Chiếc tủ lạnh Samsung Inverter 236L có giá bao nhiêu?', '6.990.000đ', '8.990.000đ', '10.990.000đ', '12.990.000đ', 'B', NOW()),
  (2, 'Bộ bàn ăn gỗ cao cấp 6 ghế giá là bao nhiêu?', '3.500.000đ', '5.500.000đ', '7.500.000đ', '9.500.000đ', 'C', NOW()),
  (3, 'Xe máy Honda Vision 2024 có giá bao nhiêu?', '28.990.000đ', '30.990.000đ', '32.990.000đ', '34.990.000đ', 'D', NOW()),
  (4, 'Smart TV Samsung 43 inch 4K có giá bao nhiêu?', '7.990.000đ', '9.990.000đ', '11.990.000đ', '13.990.000đ', 'A', NOW()),
  (5, 'Máy giặt LG Inverter 9kg giá là bao nhiêu?', '5.990.000đ', '7.990.000đ', '9.990.000đ', '11.990.000đ', 'B', NOW()),
  (6, 'Điện thoại iPhone 15 Pro Max 256GB có giá bao nhiêu?', '29.990.000đ', '32.990.000đ', '34.990.000đ', '36.990.000đ', 'C', NOW()),
  (7, 'Laptop Dell Inspiron 15 core i5 giá là bao nhiêu?', '13.990.000đ', '15.990.000đ', '17.990.000đ', '19.990.000đ', 'B', NOW()),
  (8, 'Nồi cơm điện cao tần Hitachi 1.8L có giá bao nhiêu?', '2.990.000đ', '3.990.000đ', '4.990.000đ', '5.990.000đ', 'C', NOW()),
  (9, 'Máy lạnh Daikin Inverter 1.5HP giá là bao nhiêu?', '10.990.000đ', '12.990.000đ', '14.990.000đ', '16.990.000đ', 'A', NOW()),
  (10, 'Bộ sofa da thật 3 chỗ ngồi có giá bao nhiêu?', '12.990.000đ', '15.990.000đ', '18.990.000đ', '21.990.000đ', 'D', NOW());

-- =========================================================
-- 6. PRODUCTS (SẢN PHẨM DÙNG CHO V1–V4)
-- =========================================================
INSERT INTO products (product_id, name, description, image_url, base_price, created_at)
VALUES
  (1, 'Nồi cơm điện',       'Nồi cơm điện 1.8L',                 NULL, 1200000, NOW()),
  (2, 'Máy sấy tóc',        'Máy sấy tóc mini công suất 1200W', NULL,  250000, NOW()),
  (3, 'Bình đun siêu tốc',  'Dung tích 1.7L, inox',              NULL,  400000, NOW()),
  (4, 'Quạt cây',           'Quạt cây 3 tốc độ',                 NULL,  900000, NOW()),
  (5, 'Tủ lạnh mini',       'Tủ lạnh mini 90L',                  NULL, 3200000, NOW());

-- =========================================================
-- 7. MATCHES
-- =========================================================
-- match 1: đã hoàn thành ở ROOM01, winner là Nhung (user_id=1)
-- match 2: vừa start ở ROOM02, chưa kết thúc
INSERT INTO matches (match_id, room_id, started_at, ended_at, winner_user_id, current_round)
VALUES
  (1, 1, NOW() - INTERVAL 1 DAY, NOW() - INTERVAL 1 DAY + INTERVAL 10 MINUTE, 1, 0),
  (2, 2, NOW(), NULL, NULL, 0);

-- =========================================================
-- 8. ROUNDS
-- =========================================================
-- Match 1 có 3 vòng:
--   Round 1: V1 - đoán giá
--   Round 2: V2 - xếp rẻ -> đắt
--   Round 3: V4 - đoán giá, không lệch quá X%
INSERT INTO rounds (round_id, match_id, round_number, round_type, question_id, time_limit_sec, threshold_pct, started_at, ended_at)
VALUES
  (1, 1, 1, 'V1', NULL, 20, NULL, NULL, NULL),
  (2, 1, 2, 'V2', NULL, 25, NULL, NULL, NULL),
  (3, 1, 3, 'V4', NULL, 30, 10.00, NULL, NULL),

-- Match 2 mới tạo, chưa chơi: tạo sẵn 1 round V1
  (4, 2, 1, 'V1', NULL, 20, NULL, NULL, NULL);

-- =========================================================
-- 9. ROUND_PRODUCTS
-- =========================================================
-- Round 1 (V1): 1 sản phẩm (Nồi cơm điện)
INSERT INTO round_products (round_product_id, round_id, product_id, display_order, correct_rank)
VALUES
  (1, 1, 1, 1, NULL);

-- Round 2 (V2): 3 sản phẩm, cần xếp rẻ -> đắt
INSERT INTO round_products (round_product_id, round_id, product_id, display_order, correct_rank)
VALUES
  (2, 2, 2, 1, 1),  -- rẻ nhất: Máy sấy tóc
  (3, 2, 3, 2, 2),  -- giữa: Bình siêu tốc
  (4, 2, 4, 3, 3);  -- đắt nhất: Quạt cây

-- Round 3 (V4): 1 sản phẩm (Tủ lạnh mini)
INSERT INTO round_products (round_product_id, round_id, product_id, display_order, correct_rank)
VALUES
  (5, 3, 5, 1, NULL);

-- Round 4 (Match 2, V1): dùng lại Nồi cơm điện
INSERT INTO round_products (round_product_id, round_id, product_id, display_order, correct_rank)
VALUES
  (6, 4, 1, 1, NULL);

-- =========================================================
-- 10. ROUND_ANSWERS
-- =========================================================
-- Round 1 (V1): đoán giá Nồi cơm điện (giá đúng 1.200.000)
INSERT INTO round_answers (
    answer_id, round_id, user_id,
    answer_price, answer_order_json, answer_choice,
    is_correct, score_awarded, time_ms, is_eliminated_after, created_at
) VALUES
  (1, 1, 1, 1150000, NULL, NULL, 1, 100, 5000, 0, NOW()),  -- Nhung đoán khá chuẩn
  (2, 1, 2, 1500000, NULL, NULL, 0,  60, 7000, 0, NOW()),
  (3, 1, 3,  900000, NULL, NULL, 0,  40, 8000, 0, NOW()),
  (4, 1, 4, 2000000, NULL, NULL, 0,  10, 9000, 0, NOW());

-- Round 2 (V2): xếp thứ tự 3 sản phẩm: 2 < 3 < 4
-- Giả sử JSON lưu mảng product_id theo thứ tự người chơi chọn
INSERT INTO round_answers (
    answer_id, round_id, user_id,
    answer_price, answer_order_json, answer_choice,
    is_correct, score_awarded, time_ms, is_eliminated_after, created_at
) VALUES
  (5, 2, 1, NULL, JSON_ARRAY(2,3,4), NULL, 1, 100, 6000, 0, NOW()),
  (6, 2, 2, NULL, JSON_ARRAY(2,4,3), NULL, 0,  50, 6500, 0, NOW()),
  (7, 2, 3, NULL, JSON_ARRAY(3,2,4), NULL, 0,  50, 7000, 1, NOW()), -- bị loại sau round 2
  (8, 2, 4, NULL, JSON_ARRAY(2,3,4), NULL, 1,  90, 7500, 0, NOW());

-- Round 3 (V4): đoán giá tủ lạnh mini (3.200.000, lệch không quá 10% ~ 320.000)
INSERT INTO round_answers (
    answer_id, round_id, user_id,
    answer_price, answer_order_json, answer_choice,
    is_correct, score_awarded, time_ms, is_eliminated_after, created_at
) VALUES
  (9,  3, 1, 3100000, NULL, NULL, 1, 120, 5000, 0, NOW()), -- Nhung thắng
  (10, 3, 2, 3800000, NULL, NULL, 0,  30, 6000, 1, NOW()),
  (11, 3, 4, 2500000, NULL, NULL, 0,  20, 7000, 1, NOW());

-- Round 4 (match 2, mới tạo, chưa có ai trả lời)
-- (có thể để trống round_answers cho round 4)

-- =========================================================
-- 11. MATCH_EVENTS (LOG & REPLAY)
-- =========================================================
INSERT INTO match_events (
    event_id, match_id, round_id, user_id,
    event_type, event_data, created_at
) VALUES
  (1, 1, NULL, NULL, 'MATCH_START',
     JSON_OBJECT('room_id', 1, 'mode', 'SCORE'), 
     NOW() - INTERVAL 1 DAY),

  (2, 1, 1, NULL, 'ROUND_START',
     JSON_OBJECT('round_type', 'V1', 'product_id', 1),
     NOW() - INTERVAL 1 DAY),

  (3, 1, 1, 1, 'ANSWER_SUBMIT',
     JSON_OBJECT('answer_price', 1150000),
     NOW() - INTERVAL 1 DAY),

  (4, 1, 1, NULL, 'ROUND_END',
     JSON_OBJECT('correct_price', 1200000),
     NOW() - INTERVAL 1 DAY + INTERVAL 1 MINUTE),

  (5, 1, 2, NULL, 'ROUND_START',
     JSON_OBJECT('round_type', 'V2'),
     NOW() - INTERVAL 1 DAY + INTERVAL 2 MINUTE),

  (6, 1, 3, NULL, 'ROUND_START',
     JSON_OBJECT('round_type', 'V4', 'product_id', 5),
     NOW() - INTERVAL 1 DAY + INTERVAL 4 MINUTE),

  (7, 1, 3, 1, 'MATCH_WIN',
     JSON_OBJECT('winner_user_id', 1),
     NOW() - INTERVAL 1 DAY + INTERVAL 10 MINUTE);
