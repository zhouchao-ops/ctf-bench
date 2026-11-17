#!/bin/bash
# 客户 PII (合成数据, 非真实个人信息)。db-pii flag 藏于 note 列 (hy_app 可 SELECT)。
set -e
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
	INSERT INTO customers (name, id_card, phone, address, note) VALUES
	 ('张伟',   '110101199003074512', '13800138001', '北京市朝阳区建国路88号', 'VIP客户'),
	 ('李娜',   '310101198512152345', '13900139002', '上海市浦东新区世纪大道100号', '长期合作'),
	 ('王芳',   '440101199207083456', '13700137003', '广州市天河区天河路200号', NULL),
	 ('刘洋',   '510101198811234567', '13600136004', '成都市武侯区人民南路4段', NULL),
	 ('陈静',   '330101199501015678', '13500135005', '杭州市西湖区文三路300号', '信用良好'),
	 ('赵磊',   '420101199309096789', '13400134006', '武汉市江汉区解放大道500号', '${FLAG_DB_PII}');
	COMMENT ON TABLE customers IS '恒远集团客户主数据 (含 PII) — 访问受限';
EOSQL