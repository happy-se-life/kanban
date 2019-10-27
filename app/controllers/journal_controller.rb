class JournalController < ApplicationController
  
  def index
  end
  
  #
  # ジャーナルを取得する
  #
  def get_journal
    # POST値を取得
    card_id = params[:card_id]
    
    # チケットIDを取得する
    issue_array = card_id.split("-")
    issue_id = issue_array[1].to_i

    # 返却値
    result_hash = {}

    # チケットの取得
    issue = Issue.find(issue_id);

    # ヘッダ表示
    notes_string ="<p><b>#" + issue_id.to_s + "</b></p>"
    notes_string ="<a href=\"../issues/" + issue_id.to_s + "\"><p><b>#" + issue_id.to_s + "</b><p></a>"

    # 説明欄
    if !issue.description.blank? then
      user = User.find(issue.author_id)
      notes_string += "<table class=\"my-journal-table\">"
      notes_string += "<tr>"
      notes_string += "<th>"
      notes_string += "<a href=\"../issues/" + issue_id.to_s + "\">"
      notes_string += issue.created_on.strftime("%Y-%m-%d %H:%M:%S")
      notes_string += "</a>"
      notes_string += "　"
      notes_string += user.lastname
      notes_string += "さん"
      notes_string += "</th>"
      notes_string += "</tr>"
      notes_string += "<tr>"
      notes_string += "<td>"
      notes_string += CGI.escapeHTML(trim_notes(issue.description))
      notes_string += "</td>"
      notes_string += "</tr>"
      notes_string += "</table>"
    end

    # ノートを取得（新しいものから3件）
    notes = Journal.where(journalized_id: issue_id)
                   .where(journalized_type: "Issue")
                   .where(private_notes: 0)
                   .where("notes IS NOT NULL")
                   .where("notes <> ''")
                   .limit(3)
                   .order("created_on DESC")

    # ヘッダ表示
    if !notes.blank? then
      notes_string +="<p><b>最新の履歴</b></p>"
    end

    # ノートをTABLEで組む
    notes.reverse_each {|note|
      if !note.notes.blank? then
        user = User.find(note.user_id)
        notes_string += "<table class=\"my-journal-table\">"
        notes_string += "<tr>"
        notes_string += "<th>"
        notes_string += "<a href=\"../issues/" + issue_id.to_s + "#change-" + note.id.to_s + "\">"
        notes_string += note.created_on.strftime("%Y-%m-%d %H:%M:%S")
        notes_string += "</a>"
        notes_string += "　"
        notes_string += user.lastname
        notes_string += "さん"
        notes_string += "</th>"
        notes_string += "</tr>"
        notes_string += "<tr>"
        notes_string += "<td>"
        notes_string += CGI.escapeHTML(trim_notes(note.notes))
        notes_string += "</td>"
        notes_string += "</tr>"
        notes_string += "</table>"
      end
    }

    # コメント投稿フォーム
    notes_string += "<p><b>コメント投稿</b></p>"
    notes_string += "<table class=\"my-comment-table\"><tr><td>"
    notes_string += "<textarea id=\"comment_area\" class=\"my-comment-textarea\" rows=\"5\"></textarea>"
    notes_string += "<p><input type=\"button\" id=\"submit-journal-button\" value=\"送信\"></p>"
    notes_string += "</td></tr></table>"
    
    # 返却
    result_hash["result"] = "OK"
    result_hash["notes"] = notes_string
    render json: result_hash
  end

  #
  # ノートを省略する
  #
  def trim_notes(notes)
    str = notes.byteslice(0, Constants::MAX_NOTES_BYTESIZE).scrub('')
    if notes.bytesize >= Constants::MAX_NOTES_BYTESIZE then
      str += "..."
    end
    return str
  end

  #
  # ジャーナルを追加する
  #
  def put_journal
    # POST値を取得
    card_id = params[:card_id]
    note = params[:note]
    
    # 返却値
    result_hash = {}

    # チケットIDを取得する
    issue_array = card_id.split("-")
    issue_id = issue_array[1].to_i

    # チケット取得
    issue = Issue.find(issue_id)

    # ノートを追加する
    note = Journal.new(:journalized => issue, :notes => note, user: User.current)
    note.save!

    # 返却
    result_hash["result"] = "OK"
    render json: result_hash
  end

end
