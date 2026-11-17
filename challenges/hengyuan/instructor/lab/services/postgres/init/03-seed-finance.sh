#!/bin/bash
# 财务交易/报销 + 员工表 (密码复用列, 喂 OA 登录 / AD 用户名枚举)。
set -e
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
	INSERT INTO finance (txn, amount, balance, note) VALUES
	 ('供应商付款-恒远云部署', 12800.00, 458200.00, '已审批'),
	 ('办公用品采购',           3600.50, 454599.50, '待财务总监审批'),
	 ('服务器配件采购',        45900.00, 408699.50, '已审批'),
	 ('差旅报销-上海展会',      8200.00, 400499.50, '待审批'),
	 ('季度营销服务费',        66000.00, 334499.50, '已审批');
	INSERT INTO employees (username, dept, password) VALUES
	 ('zhang_wei', '财务部', 'Zhangwei@2023'),
	 ('li_na',     '财务部', 'Lina@2023'),
	 ('wang_fang', '采购部', 'Wangfang@2023'),
	 ('liu_yang',  '信息技术部', 'Liuyang@2023'),
	 ('chen_jing', '人力资源部', 'Chenjing@2023'),
	 ('itadmin',   '信息技术部', 'ItAdmin@2023');
EOSQL