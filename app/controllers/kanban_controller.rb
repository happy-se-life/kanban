class KanbanController < ApplicationController
  unloadable
  before_action :global_authorize
  #
  # インデックス
  #
  def index 
    # ブラウザバックでキャッシュさせない設定
    response.headers['Cache-Control'] = 'no-store, no-cache, must-revalidate, max-age=0, post-check=0, pre-check=0'
    response.headers['Pragma'] = 'no-cache'
    
    # セッション破棄
    if params[:clear].to_i == 1 then
      discard_session
    end

    # セッション復元
    restore_session

    # 各種パラメータの初期化とセッション保存
    initialize_params_and_store_session

    # ユーザー情報を取得(アバター用)
    @user = User.find(@user_id.to_i)

    # 全ユーザーを取得する(SELECT作成用)
    @all_users = User.where(type: "User")
                     .where(status: 1)
                     .where("login <> 'admin'")

    # 全ステータスを取得（表示順）
    @issue_statuses = IssueStatus.all.order("position ASC")
    @issue_statuses_hash = {}
    @issue_statuses.each {|issue_status|
      @issue_statuses_hash[issue_status.id.to_i] = issue_status.name
    }

    # 終了ステータスを取得
    @done_issue_statuses = IssueStatus.where(is_closed: 1)
    @done_issue_statuses_array = []
    @done_issue_statuses.each {|issue_status|
      @done_issue_statuses_array << issue_status.id
    }

    # 更新日 updated_within 日前
    time_from = Time.now - 3600 * 24 * @updated_within.to_i
    updated_from = time_from.strftime("%Y-%m-%d 00:00:00")

    # 終了日 done_within 日前
    time_from = Time.now - 3600 * 24 * @done_within.to_i
    closed_from = time_from.strftime("%Y-%m-%d 00:00:00")

    # ユーザーに関連したチケットを取得
    issues_for_projects = Issue.where(assigned_to_id: @user_id_array)
                               .where("updated_on >= '" + updated_from + "'")
                               .where(is_private: 0)
                               .limit(Constants::SELECT_LIMIT)

    # ユニークプロジェクトID配列を作成
    unique_project_id_array = []
    if @project_all == "1" then
      issues_for_projects.each {|issue|
        if unique_project_id_array.include?(issue.project.id.to_i) == false then
          unique_project_id_array << issue.project.id.to_i
        end
      }
    else
      # 単一のプロジェクトの場合
      unique_project_id_array << @project.id.to_i
    end

    # Not assigned ユーザーを追加
    @user_id_array << nil;

    # チケットを取得
    @issues_hash = {}
    @wip_hash = {}
    @over_wip = 0
    # ステータスでループ
    @status_fields_array.each {|status_id|
      if @done_issue_statuses_array.include?(status_id) == false then
        # 終了以外のステータス
        @issues_hash[status_id] = Issue.where(assigned_to_id: @user_id_array)
                                      .where(project_id: unique_project_id_array)
                                      .where(status: status_id)
                                      .where("updated_on >= '" + updated_from + "'")
                                      .where(is_private: 0)
                                      .limit(Constants::SELECT_LIMIT)
                                      .order("CASE assigned_to_id WHEN '" + @user_id.to_s + "' THEN 1 ELSE 2 END, assigned_to_id DESC")  # @user_id を先頭にソート
        # WIP制限
        if status_id == Constants::WIP_COUNT_STATUS_FIELD then
          # WIPカウント
          @user_id_array.each {|uid|
            wip_counter = 0
              @issues_hash[status_id].each {|issue|
              if issue.assigned_to_id == uid then
                wip_counter += 1
              end
            }
            # カウント値を保存
            if uid != nil then
              @wip_hash[uid] = wip_counter
              # 超過判定
              if wip_counter > @wip_max.to_i then
                @over_wip = 1
              end
            end
          }
        end
      else
        # 終了のステータス
        @issues_hash[status_id] = Issue.where(assigned_to_id: @user_id_array)
                                      .where(project_id: unique_project_id_array)
                                      .where(status: status_id)
                                      .where("updated_on >= '" + closed_from + "'")
                                      .where(is_private: 0)
                                      .limit(Constants::SELECT_LIMIT)
                                      .order("CASE assigned_to_id WHEN '" + @user_id.to_s + "' THEN 1 ELSE 2 END, assigned_to_id DESC")  # @user_id を先頭にソート
      end
    }

  end
  
  private

  #
  # セッションを破棄する
  #
  def discard_session
    session[:kanban] = nil
  end

  #
  # セッションを復元する
  #
  def restore_session
    # セッションを復元
    session_hash = session[:kanban]
    
    # 更新日（セッション復元）
    if !session_hash.blank? && params[:updated_within].blank?
      @updated_within = session_hash["updated_within"]
    else
      @updated_within = params[:updated_within]
    end

    # 終了日（セッション復元）
    if !session_hash.blank? && params[:done_within].blank?
      @done_within = session_hash["done_within"]
    else
      @done_within = params[:done_within]
    end

    # 担当者（セッション復元）
    if !session_hash.blank? && params[:user_id].blank?
      @user_id = session_hash["user_id"]
    else
      @user_id = params[:user_id]
    end

    # グループ（セッション復元）
    if !session_hash.blank? && params[:group_id].blank?
      @group_id = session_hash["group_id"]
    else
      @group_id = params[:group_id]
    end

    # ステータス列（セッション復元）
    if !session_hash.blank? && params[:status_fields].blank?
      @status_fields = session_hash["status_fields"]
    else
      @status_fields = params[:status_fields]
    end

    # プロジェクト選択（セッション復元）
    if !session_hash.blank? && params[:project_all].blank?
      @project_all = session_hash["project_all"]
    else
      @project_all = params[:project_all]
    end

    # WIP最大値（セッション復元）
    if !session_hash.blank? && params[:wip_max].blank?
      @wip_max = session_hash["wip_max"]
    else
      @wip_max = params[:wip_max]
    end
  end

  #
  # 各種パラメータの初期化とセッション保存
  #
  def initialize_params_and_store_session
    # セッション保存用ハッシュ
    session_hash = {}

    # Default更新日
    if @updated_within == nil || @updated_within.to_i == 0 then
      @updated_within = Constants::DEFAULT_VALUE_UPDATED_WITHIN
    end
    session_hash["updated_within"] = @updated_within
    
    # Default終了日
    if @done_within == nil || @done_within.to_i == 0 then
      @done_within = Constants::DEFAULT_VALUE_DONE_WITHIN
    end
    session_hash["done_within"] = @done_within

    # Default担当者
    if @user_id == nil || @user_id.to_i == 0 then
      @user_id = @current_user.id
    end
    session_hash["user_id"] = @user_id
    
    # Defaultプロジェクト
    @project_id = params[:project_id]
    # プロジェクト識別子
    if @project_id.blank? == true then
      @project = nil
    else
      @project = Project.find(@project_id)
    end
    
    # 全グループを取得する
    @all_groups = Group.where(type: "Group")

    # グループに属するユーザーID配列を作成
    @user_id_array = []
    if @group_id == nil || @group_id.to_i == 0 then
      # グループが指定されていない場合
      # 自分
      @user_id_array << @user_id.to_i
      @group_id = "all"
    else
      # グループが指定されている場合
      @all_groups.each {|group|
        if group.id == @group_id.to_i
          @user_id_array = group.user_ids
        end
      }
    end
    session_hash["group_id"] = @group_id

    # 画面セレクトの選択でプロジェクト「全体」
    if @project_id.blank? == true then
      @project_all = "1"
    else
      if @project_all.blank? == true then
        @project_all = "0"
      end
    end
    session_hash["project_all"] = @project_all

    # チェックの付いているステータスID配列を作成
    @status_fields_array = []
    if !@status_fields.blank? then
      @status_fields.each {|id,chk|
        if chk == "1"
          @status_fields_array << id.to_i
        end
      }
    else
      # Defaultは定数ファイルから取得
      @status_fields_array = Constants::DEFAULT_STATUS_FIELD_VALUE_ARRAY
    end
    session_hash["status_fields"] = @status_fields

    # Default WIP最大値
    if @wip_max == nil || @wip_max.to_i == 0 then
      @wip_max = Constants::DEFAULT_VALUE_WIP_MAX
    end
    session_hash["wip_max"] = @wip_max

    # セッション保存
    session[:kanban] = session_hash
  end


  #
  # ログインユーザーを取得する
  #
  def set_user
    @current_user ||= User.current
  end

  #
  # ログインユーザーでなければエラー
  #
  def global_authorize
    set_user
    render_403 unless @current_user.type == 'User'
  end

end
