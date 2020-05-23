class JournalController < ApplicationController
  
  def index
  end
  
  #
  # Get journals to display on sidebar
  #
  def get_journal
    # Get POST value
    card_id = params[:card_id]
    
    # Target issue ID
    issue_array = card_id.split("-")
    issue_id = issue_array[1].to_i

    # Declaring variable to return
    result_hash = {}

    # Target issue
    issue = Issue.find(issue_id);

    # ヘッダ表示
    notes_string ="<p><b>#" + issue_id.to_s + "</b></p>"
    notes_string ="<a href=\"./issues/" + issue_id.to_s + "\"><p><b>#" + issue_id.to_s + "</b><p></a>"

    # Building html of issue description
    if !issue.description.blank? then
      user = User.find(issue.author_id)
      notes_string +="<p><b>" + I18n.t(:field_description) + "</b></p>"
      notes_string += "<table class=\"my-journal-table\">"
      notes_string += "<tr>"
      notes_string += "<th>"
      notes_string += "<a href=\"./issues/" + issue_id.to_s + "\">"
      notes_string += issue.created_on.strftime("%Y-%m-%d %H:%M:%S")
      notes_string += "</a>"
      notes_string += "　"
      notes_string += user.name
      notes_string += "</th>"
      notes_string += "</tr>"
      notes_string += "<tr>"
      notes_string += "<td>"
      notes_string += CGI.escapeHTML(trim_notes(issue.description))
      notes_string += "</td>"
      notes_string += "</tr>"
      notes_string += "</table>"
    end

    # Get newer 3 journals
    notes = Journal.where(journalized_id: issue_id)
      .where(journalized_type: "Issue")
      .where(private_notes: 0)
      .where("notes IS NOT NULL")
      .where("notes <> ''")
      .order(created_on: :desc)
      .limit(Constants::MAX_NOTES)

    # Adding string for recent history
    if !notes.blank? then
      notes_string +="<p><b>" + I18n.t(:kanban_label_recent_history) + "</b></p>"
    end

    # Building html of notes
    if Constants::ORDER_NOTES == "ASC" then
      notes.reverse_each {|note|
        notes_string += note_to_html(issue_id, note)
      }
    else
      # DESC
      notes.each {|note|
        notes_string += note_to_html(issue_id, note)
      }
    end

    # Buiding input area for new note
    notes_string += "<p><b>" + I18n.t(:kanban_label_add_notes) + "</b></p>"
    notes_string += "<table class=\"my-comment-table\"><tr><td>"
    notes_string += "<textarea id=\"comment_area\" class=\"my-comment-textarea\" rows=\"5\"></textarea>"
    notes_string += "<p><input type=\"button\" id=\"submit-journal-button\" value=\"" + I18n.t(:button_submit) + "\"></p>"
    notes_string += "</td></tr></table>"
    
    # Ignoring failing
    result_hash["result"] = "OK"
    result_hash["notes"] = notes_string
    render json: result_hash
  end

  #
  # Shorten strings
  #
  def trim_notes(notes)
    str = notes.byteslice(0, Constants::MAX_NOTES_BYTESIZE).scrub('')
    if notes.bytesize >= Constants::MAX_NOTES_BYTESIZE then
      str += "..."
    end
    return str
  end

  #
  # Add new journal
  #
  def put_journal
    # Get POST value
    card_id = params[:card_id]
    note = params[:note]
    
    # Declaring variable to return
    result_hash = {}

    # Target issue ID
    issue_array = card_id.split("-")
    issue_id = issue_array[1].to_i

    # Target issue
    issue = Issue.find(issue_id)

    # Create new journal and save
    note = Journal.new(:journalized => issue, :notes => note, user: User.current)
    note.save!

    # Ignoring failing
    result_hash["result"] = "OK"
    render json: result_hash
  end

  #
  # Return html of note
  #
  def note_to_html(issue_id, note)
    html = ""
    if !note.notes.blank? then
      user = User.find(note.user_id)
      html += "<table class=\"my-journal-table\">"
      html += "<tr>"
      html += "<th>"
      html += "<a href=\"./issues/" + issue_id.to_s + "#change-" + note.id.to_s + "\">"
      html += note.created_on.strftime("%Y-%m-%d %H:%M:%S")
      html += "</a>"
      html += "　"
      html += user.name
      html += "</th>"
      html += "</tr>"
      html += "<tr>"
      html += "<td>"
      html += CGI.escapeHTML(trim_notes(note.notes))
      html += "</td>"
      html += "</tr>"
      html += "</table>"
    end
    return html
  end
end
