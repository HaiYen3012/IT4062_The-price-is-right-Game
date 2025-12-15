USE hay_chon_gia_dung;

-- Update image URLs for all products
UPDATE products SET image_url = 'https://cdn.tgdd.vn/Products/Images/1922/236273/noi-com-dien-tu-sharp-18-lit-ks-ih191v-rd-thumb-600x600.jpg' WHERE product_id = 1;
UPDATE products SET image_url = 'https://cdn.tgdd.vn/Products/Images/1988/236065/may-say-toc-kangaroo-kg616-thumb-600x600.jpg' WHERE product_id = 2;
UPDATE products SET image_url = 'https://cdn.tgdd.vn/Products/Images/1920/107836/binh-dun-sieu-toc-philips-hd9318-17-lit-1-1-600x600.jpg' WHERE product_id = 3;
UPDATE products SET image_url = 'https://cdn.tgdd.vn/Products/Images/7498/271652/quat-cay-asia-d16023-rd-thumb-600x600.jpg' WHERE product_id = 4;
UPDATE products SET image_url = 'https://cdn.tgdd.vn/Products/Images/1943/313107/tu-lanh-mini-aqua-90-lit-aqr-d99fa-bs-thumb-600x600.jpg' WHERE product_id = 5;

-- Verify the update
SELECT product_id, name, image_url FROM products;
