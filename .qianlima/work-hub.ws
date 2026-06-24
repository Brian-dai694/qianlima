hub:
  name: qianlima_work_hub
  display_name: 千里马跨场景索引
  status: draft

scenarios:
  - id: ad_ops
    name: 广告运营
    related_scenarios:
      - sales_ledger
      - inventory_monitor
      - profit_review

shared_rules:
  - id: no_auto_external_write
    name: 默认不自动写入外部系统
  - id: cite_data_source
    name: 报告必须标注数据来源

events: []

