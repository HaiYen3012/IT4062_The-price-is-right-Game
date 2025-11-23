# 📘 DATABASE_SETUP.md

### Hướng dẫn cài đặt & khởi tạo MySQL cho dự án **Hãy Chọn Giá Đúng – GameShow**

Hỗ trợ **cả Ubuntu Native và WSL2** để tất cả thành viên nhóm đều chạy được.

Môi trường:
* **Ubuntu 20.04+ (Native hoặc WSL2)**
* **MySQL Server 8.x**

---

# 🧩 1. Cài đặt MySQL & thư viện cần thiết

## Bước 1.1: Cài đặt MySQL Server

Mở Terminal (Ubuntu/WSL):

```bash
sudo apt update

# Cài MySQL Server
sudo apt install -y mysql-server

# Thư viện MySQL để build server C
sudo apt install -y libmysqlclient-dev build-essential
```

## Bước 1.2: Khởi động MySQL

### 🖥️ Ubuntu Native:
```bash
# Kiểm tra status
sudo systemctl status mysql

# Khởi động nếu chưa chạy
sudo systemctl start mysql

# Enable auto-start khi boot
sudo systemctl enable mysql
```

### 🪟 WSL2:
```bash
# WSL không dùng systemd, dùng service command
sudo service mysql status

# Khởi động MySQL (phải chạy lại mỗi lần mở WSL)
sudo service mysql start

# Tạo script tự động start (optional)
echo 'sudo service mysql start' >> ~/.bashrc
```

## Bước 1.3: Kiểm tra MySQL đang chạy

```bash
# Cả Ubuntu và WSL đều dùng được
sudo mysql -e "SELECT VERSION();"
```

Nếu hiển thị version MySQL → Cài đặt thành công ✅

---

# 🗄️ 2. Khởi tạo Database & User MySQL

## 📍 Bước 2.1: Chuyển đến thư mục database của project

```bash
cd IT4062_The-price-is-right-Game/database
pwd  # Xác nhận đang ở đúng thư mục
```

## 📍 Bước 2.2: Đăng nhập MySQL bằng quyền root

```bash
sudo mysql
```
hoặc

```bash 
sudo mysql -u root -p
```
nếu bạn đã đặt password cho root trước đó.

**Lưu ý WSL**: Nếu lỗi "Can't connect to MySQL server", chạy `sudo service mysql start` trước.

## 📍 Bước 2.3: Chạy script khởi tạo đầy đủ

**Trong MySQL shell**, chạy từng lệnh sau:

```sql
-- Xóa DB và User cũ (nếu có)
DROP DATABASE IF EXISTS hay_chon_gia_dung;
DROP USER IF EXISTS 'admin'@'%';
DROP USER IF EXISTS 'admin'@'localhost';

-- Tạo Database mới với UTF-8
CREATE DATABASE hay_chon_gia_dung 
    CHARACTER SET utf8mb4 
    COLLATE utf8mb4_unicode_ci;

USE hay_chon_gia_dung;

-- Tạo user quản trị DB cho server
CREATE USER 'admin'@'localhost' IDENTIFIED WITH mysql_native_password BY '123456';
CREATE USER 'admin'@'%' IDENTIFIED WITH mysql_native_password BY '123456';

-- Cấp toàn quyền trên database
GRANT ALL PRIVILEGES ON hay_chon_gia_dung.* TO 'admin'@'localhost' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON hay_chon_gia_dung.* TO 'admin'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;

-- Import schema (thay đổi path tuyệt đối nếu cần)
SOURCE init.sql;

-- Import seed data
SOURCE seed_data.sql;

-- Kiểm tra kết quả
SELECT COUNT(*) as total_users FROM users;
SELECT COUNT(*) as total_products FROM products;

exit;
```

**✅ Nếu thấy:**
- `total_users: 5` 
- `total_products: > 0`

→ Database setup thành công!

---

# 🔧 3. Cấu hình Server để kết nối MySQL

## Bước 3.1: Tạo hoặc sửa file config

```bash
cd ../server
nano config
```

**Hoặc dùng editor khác:**
```bash
code config      # VS Code
gedit config     # Ubuntu Desktop
vim config       # Terminal editor
```

## Bước 3.2: Nội dung file config

```ini
[database]
host=127.0.0.1
user=admin
password=123456
database=hay_chon_gia_dung

[network]
port=5555
```

**Lưu file** (nano: `Ctrl+O`, `Enter`, `Ctrl+X`)

## Bước 3.3: Kiểm tra MySQL socket path

MySQL Server thông thường dùng socket `/var/run/mysqld/mysqld.sock`.

Để kiểm tra:
```bash
mysql_config --socket
# Output: /var/run/mysqld/mysqld.sock
```

**Lưu ý**: Server C code đã được config sẵn cho cả Ubuntu và WSL.

---

# 🧪 4. Build & Test Server với Database

## Bước 4.1: Build server

```bash
cd ../server
make clean && make
```

**Expected output:**
```
mkdir -p bin
gcc src/main.c src/server.c src/database.c -o bin/server -Iinclude -Wall -Wextra -O2 -lmysqlclient
```

Một số warnings về array bounds là bình thường, không ảnh hưởng.

## Bước 4.2: Chạy server

```bash
./bin/server
```

**✅ Nếu thành công, bạn sẽ thấy:**

```
=== HayChonGiaDung C Server ===
[DB] Detected MySQL socket: /var/run/mysqld/mysqld.sock
[DB] Connected to MySQL database 'hay_chon_gia_dung' as user 'admin'
[DB] Test query OK.
[DB] Current users in DB: 5
[SERVER] Listening on port 5555...
[SERVER] Press Ctrl+C to stop
```

**❌ Nếu lỗi "Can't connect to local MySQL server":**

```bash
# Kiểm tra MySQL có chạy không
sudo service mysql status

# Nếu stopped, khởi động lại
sudo service mysql start

# Chạy lại server
./bin/server
```

**❌ Nếu lỗi "Access denied for user 'admin'@'localhost'":**

- Quay lại Bước 2 và chạy lại script tạo user
- Hoặc kiểm tra: `sudo mysql -u admin -p123456 -e "USE hay_chon_gia_dung; SELECT COUNT(*) FROM users;"`

## Bước 4.3: Test client connection (terminal khác)

Mở terminal mới:

```bash
cd client
./client 127.0.0.1 5555
```

Nếu client hiện UI và server log:
```
[SERVER] New client [5] from 127.0.0.1:xxxxx
[5] Client added to list
[5] Client handler started
```

→ **HOÀN TẤT SETUP** 🎉

---

# 🌐 5. Setup cho Teamwork (4 người)

## 🎯 Scenario 1: Tất cả làm việc trên máy riêng (Local Development)

**Mỗi người:**
1. Clone repo: `git clone https://github.com/HaiYen3012/IT4062_The-price-is-right-Game.git`
2. Follow Bước 1-4 ở trên
3. Mỗi người có database riêng trên máy mình
4. Test local: `./client 127.0.0.1 5555`

✅ **Phù hợp cho**: Development, testing riêng lẻ

## 🎯 Scenario 2: Connect client → server của người khác (Multiplayer Testing)

### Người chạy Server (ví dụ: Duyên):

```bash
# 1. Lấy IP của máy
hostname -I     # Ubuntu
ip addr         # WSL

# Output ví dụ: 192.168.1.100 (Ubuntu) hoặc 172.x.x.x (WSL)
```

**Ubuntu Native**: IP là IP máy trong LAN (192.168.x.x)

**WSL**: 
- Lấy IP WSL: `hostname -I` → 172.x.x.x
- **Hoặc** lấy IP Windows: `ipconfig` trong PowerShell → 192.168.x.x (khuyến nghị)

```bash
# 2. Chạy server
cd server
./bin/server

# Server listen trên 0.0.0.0:5555 (accept connections từ mọi IP)
```

### Người khác chạy Client (ví dụ: Hà, Yến, Nhung):

```bash
# Thay YOUR_SERVER_IP bằng IP của người chạy server
cd client
./client 192.168.1.100 5555

# Ví dụ:
# ./client 192.168.1.100 5555    (nếu server Ubuntu)
# ./client 172.25.32.1 5555      (nếu server WSL, dùng WSL IP)
```

**Lưu ý**: Cả 4 người phải cùng mạng WiFi/LAN.

## 🎯 Scenario 3: WSL Port Forwarding (cho người dùng WSL làm server)

Nếu bạn dùng WSL và muốn bạn khác connect vào, cần forward port:

### Trong PowerShell (Windows) với quyền Admin:

```powershell
# Forward port 5555 từ Windows → WSL
netsh interface portproxy add v4tov4 listenport=5555 listenaddress=0.0.0.0 connectport=5555 connectaddress=172.x.x.x

# (Thay 172.x.x.x bằng IP WSL từ lệnh hostname -I trong WSL)
```

### Xóa port forward (sau khi xong):
```powershell
netsh interface portproxy delete v4tov4 listenport=5555 listenaddress=0.0.0.0
```

Sau đó bạn khác dùng IP Windows (192.168.x.x) để connect.

## 🖥️ Bonus: MySQL Workbench (Windows) → WSL Database

Nếu muốn dùng GUI để xem database trong WSL:

### Bước 1: Config MySQL accept remote connection

```bash
# Trong WSL
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
```

Sửa dòng:
```ini
bind-address = 127.0.0.1
```
→ thành:
```ini
bind-address = 0.0.0.0
```

### Bước 2: Restart MySQL
```bash
sudo service mysql restart
```

### Bước 3: Connect từ Workbench

| Parameter | Value                            |
| --------- | -------------------------------- |
| Hostname  | 172.x.x.x (IP WSL) hoặc 127.0.0.1|
| Port      | 3306                             |
| Username  | admin                            |
| Password  | 123456                           |
| Database  | hay_chon_gia_dung                |

✅ **Lưu ý**: Chỉ nên mở remote access trong môi trường development, không dùng trên production!

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
