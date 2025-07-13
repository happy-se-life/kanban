class WidgetController < ApplicationController
  before_action :find_user
  before_action :authorize_global

  def index
    # 最低限の実装 - ビューを表示するだけ
  end

  private

  def find_user
    @user = User.current
  end
end 