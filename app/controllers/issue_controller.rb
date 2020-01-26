class IssueController < ApplicationController

  def index
  end

  #
  # ステータスを変更する
  #
  def update_status
    # POST値を取得
    card_id = params[:card_id]
    field_id = params[:field_id]
    comment = params[:comment]
    
    # チケットIDを取得
    issue_array = card_id.split("-")
    issue_id = issue_array[1].to_i

    # ステータスIDを取得
    field_array = field_id.split("-")
    status_id = field_array[1].to_i
    
    # ユーザIDを取得
    if field_array.length == 3 then 
      user_id = field_array[2].to_i
    else
      user_id = nil
    end

    # チケット取得
    issue = Issue.find(issue_id)

    # 変更可能なステータス
    allowd_statuses = issue.new_statuses_allowed_to
    allowd_statuses_array = []
    allowd_statuses.each {|status|
      allowd_statuses_array << status.id
    }

    # 返却値
    result_hash = {}

    # ステータス変更
    if allowd_statuses_array.include?(status_id) == true then
      if (issue.status_id != status_id) || (issue.assigned_to_id != user_id) then
        # ステータス変更を保存
        old_status_id = issue.status_id
        old_done_ratio = issue.done_ratio
        old_assigned_to_id = issue.assigned_to_id
        issue.status_id = status_id
        issue.assigned_to_id = user_id
        issue.save!
        # ノートを追加する
        note = Journal.new(:journalized => issue, :notes => comment, user: User.current)
        note.details << JournalDetail.new(:property => 'attr', :prop_key => 'status_id', :old_value => old_status_id,:value => status_id)
        note.details << JournalDetail.new(:property => 'attr', :prop_key => 'done_ratio', :old_value => old_done_ratio,:value => issue.done_ratio)
        note.details << JournalDetail.new(:property => 'attr', :prop_key => 'assigned_to_id', :old_value => old_assigned_to_id,:value => user_id)
        note.save!
        result_hash["result"] = "OK"
        result_hash["user_id"] = issue.assigned_to_id
      else
        result_hash["result"] = "NO"
      end
    else
      result_hash["result"] = "NG"
    end

    render json: result_hash
  end

end
