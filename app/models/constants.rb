#
# 定数クラス
#
class Constants < ActiveRecord::Base
  
  # クエリ結果の最大値
  SELECT_LIMIT = 250 
  
  # デフォルト値
  DEFAULT_VALUE_UPDATED_WITHIN = "31"
  DEFAULT_VALUE_DONE_WITHIN = "14"
  DEFAULT_VALUE_WIP_MAX = "2"

  # デフォルト値
  # 1:新規
  # 2:進行中
  # 3:レビュー
  # 4:フィードバック
  # 5:終了
  # 7:リリース待ち
  DEFAULT_STATUS_FIELD_VALUE_ARRAY = [1,2,3,4,7,5]

  # WIP制限するフィールド
  WIP_COUNT_STATUS_FIELD = 2

  # ノートの最大バイト数
  MAX_NOTES_BYTESIZE = 350
end
