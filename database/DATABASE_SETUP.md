# 📘 DATABASE_SETUP.md

### Hướng dẫn cài đặt & khởi tạo MySQL cho dự án **Hãy Chọn Giá Đúng – GameShow**

Môi trường khuyến nghị:

* **Ubuntu 20.04+**,
* **WSL2 trên Windows**,
* MySQL Server **8.x**.

---

# 🧩 1. Cài đặt MySQL & thư viện cần thiết

Mở Terminal (Ubuntu/WSL):

```bash
sudo apt update

# Cài MySQL Server
sudo apt install -y mysql-server

# Thư viện MySQL để build server C
sudo apt install -y libmysqlclient-dev build-essential
```

Khởi động MySQL (với WSL, cần chạy lại mỗi lần mở máy):

```bash
sudo service mysql start
```

---

# 🗄️ 2. Khởi tạo Database & User MySQL

## 📍 Bước 1: chuyển đến thư mục database

```bash
cd database
```

## 📍 Bước 2: đăng nhập MySQL bằng quyền root

```bash
sudo mysql
```

## 📍 Bước 3: chạy script khởi tạo đầy đủ (copy & paste vào MySQL shell)

```sql
-- Xóa DB và User cũ (nếu có)
DROP DATABASE IF EXISTS hay_chon_gia_dung;
DROP USER IF EXISTS 'admin'@'%';
DROP USER IF EXISTS 'admin'@'localhost';

-- Tạo Database mới
CREATE DATABASE hay_chon_gia_dung;
USE hay_chon_gia_dung;

-- Tạo user quản trị DB cho server
CREATE USER 'admin'@'localhost' IDENTIFIED WITH mysql_native_password BY '123456';
CREATE USER 'admin'@'%' IDENTIFIED WITH mysql_native_password BY '123456';

-- Cấp toàn quyền
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'localhost' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;

-- Tải bảng + cấu trúc DB
SOURCE init.sql;

-- Tải dữ liệu mẫu (seed)
SOURCE seed_data.sql;

exit;
```

---

# 🔧 3. Cấu hình Server để kết nối MySQL

Mở file:

```bash
nano server/config.ini
```

Ghi đúng nội dung:

```ini
[database]
host=127.0.0.1
user=admin
password=123456
database=hay_chon_gia_dung

[network]
port=5555
```

Server C của bạn đọc `config.ini` để tự động kết nối DB khi chạy.

---

# 🧪 4. Kiểm tra kết nối Database

Chuyển sang thư mục server:

```bash
cd ../server
make
./bin/server
```

Nếu mọi thứ OK, bạn sẽ thấy log giống sau:

```
[DB] Connected to MySQL database 'hay_chon_gia_dung' as user 'admin'
[DB] Test query OK.
[SERVER] Listening on port 5555 ...
```

Nếu hiện như vậy → Database Setup **THÀNH CÔNG** 🎉

---

# 🖥️ 5. (Tùy chọn) Kết nối MySQL Workbench (Windows)

Nếu muốn mở DB bằng Workbench trên Windows, làm như sau:

### Bước 1: Lấy IP của WSL

```bash
hostname -I
```

Ví dụ: `172.25.224.1`

### Bước 2: Mở file cấu hình MySQL

```bash
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
```

Thay dòng:

```
bind-address = 127.0.0.1
```

→ thành:

```
bind-address = 0.0.0.0
```

### Bước 3: Restart MySQL

```bash
sudo service mysql restart
```

### Bước 4: Tạo connection trong Workbench

| Parameter | Value                   |
| --------- | ----------------------- |
| Hostname  | IP WSL (vd: 172.25.x.x) |
| Port      | 3306                    |
| Username  | admin                   |
| Password  | 123456                  |

---

# 🍀 6. Kiểm tra dữ liệu đã seed

Trong MySQL:

```sql
USE hay_chon_gia_dung;
SELECT * FROM users;
SELECT * FROM products;
SELECT * FROM rooms;
SELECT * FROM matches;
SELECT * FROM rounds;
SELECT * FROM round_answers;
SELECT * FROM match_events;
```

Nếu có dữ liệu mẫu → hoàn thành seed.

---

# 🎉 Hoàn tất
