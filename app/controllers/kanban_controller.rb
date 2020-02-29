class KanbanController < ApplicationController
  unloadable
  before_action :global_authorize
  #
  # Display kanban board
  #
  def index 
    # Do not cache on browser back
    response.headers['Cache-Control'] = 'no-store, no-cache, must-revalidate, max-age=0, post-check=0, pre-check=0'
    response.headers['Pragma'] = 'no-cache'
    
    # Session discard
    if params[:clear].to_i == 1 then
      discard_session
    end

    # Session restore
    restore_session

    # Initialize and store session
    initialize_params_and_store_session

    # Get user to display avator
    @user = User.find(@user_id.to_i)

    # Get all user for user filetr <select>
    @all_users = User.where(type: "User").where(status: 1)

    # Collect lastname for users
    @all_lastnames_hash = {}
    @all_users.each {|user|
      @all_lastnames_hash[user.id] = user.lastname
    }

    # Remove inactive users from array of target users
    @user_id_array.each {|id|
      if @all_users.ids.include?(id) == false then
        @user_id_array.delete(id)
      end
    }

    # Add group ID to array of target users
    if Setting.issue_group_assignment? and @group_id != nil and @group_id.to_i != 0 then
      @user_id_array << @group_id.to_i
    end

    # Collect lastname for groups
    @all_groups.each {|group|
      @all_lastnames_hash[group.id] = group.lastname
    }

    # Move current user to head
    selected_user_index = @user_id_array.index(@user_id.to_i)
    if @user_id_array.length > 1 && selected_user_index != nil then
      swap_id = @user_id_array[0]
      @user_id_array[selected_user_index] = swap_id
      @user_id_array[0] = @user_id.to_i
    end

    # Get all status orderby position
    @issue_statuses = IssueStatus.all.order("position ASC")
    @issue_statuses_hash = {}
    @issue_statuses.each {|issue_status|
      @issue_statuses_hash[issue_status.id.to_i] = issue_status.name
    }

    # Get statuses for issue closed
    @done_issue_statuses = IssueStatus.where(is_closed: 1)
    @done_issue_statuses_array = []
    @done_issue_statuses.each {|issue_status|
      @done_issue_statuses_array << issue_status.id
    }

    # Updated datetime for filter
    time_from = Time.now - 3600 * 24 * @updated_within.to_i
    updated_from = time_from.strftime("%Y-%m-%d 00:00:00")

    # Closed datetime for filter
    time_from = Time.now - 3600 * 24 * @done_within.to_i
    closed_from = time_from.strftime("%Y-%m-%d 00:00:00")

    # Get issues related to target users
    issues_for_projects = Issue.where(assigned_to_id: @user_id_array)
      .where("updated_on >= '" + updated_from + "'")
      .where(is_private: 0)
      .limit(Constants::SELECT_LIMIT)

    # Group by project ID
    unique_project_id_array = []
    if @project_all == "1" then
      issues_for_projects.each {|issue|
        if unique_project_id_array.include?(issue.project.id.to_i) == false then
          unique_project_id_array << issue.project.id.to_i
        end
      }
    else
      # When select one project
      unique_project_id_array << @project.id.to_i
    end

    # To display no assignee issue
    @user_id_array << nil;

    # Declaring variables
    @issues_hash = {}
    @wip_hash = {}
    @over_wip = 0

    # Get issues using status loop
    @status_fields_array.each {|status_id|
      if @done_issue_statuses_array.include?(status_id) == false then
        # Case not closed status
        @issues_hash[status_id] = Issue.where(assigned_to_id: @user_id_array)
          .where(project_id: unique_project_id_array)
          .where(status: status_id)
          .where("updated_on >= '" + updated_from + "'")
          .where(is_private: 0)
          .limit(Constants::SELECT_LIMIT)
          .order("CASE assigned_to_id WHEN '" + @user_id.to_s + "' THEN 1 ELSE 2 END, assigned_to_id DESC")  # Sort @user_id first
        # Count WIP issues
        if status_id == Constants::WIP_COUNT_STATUS_FIELD then
          @user_id_array.each {|uid|
            wip_counter = 0
              @issues_hash[status_id].each {|issue|
              if issue.assigned_to_id == uid then
                wip_counter += 1
              end
            }
            # Save count value
            if uid != nil then
              @wip_hash[uid] = wip_counter
            end
          }
        end
      else
        # Case closed status
        @issues_hash[status_id] = Issue.where(assigned_to_id: @user_id_array)
          .where(project_id: unique_project_id_array)
          .where(status: status_id)
          .where("updated_on >= '" + closed_from + "'")
          .where(is_private: 0)
          .limit(Constants::SELECT_LIMIT)
          .order("CASE assigned_to_id WHEN '" + @user_id.to_s + "' THEN 1 ELSE 2 END, assigned_to_id DESC")  # Sort @user_id first
      end
    }

  end
  
  private

  #
  # Session discard
  #
  def discard_session
    session[:kanban] = nil
  end

  #
  # Session restore
  #
  def restore_session
    session_hash = session[:kanban]
    
    # Days since upadated date
    if !session_hash.blank? && params[:updated_within].blank?
      @updated_within = session_hash["updated_within"]
    else
      @updated_within = params[:updated_within]
    end

    # Days since closed date
    if !session_hash.blank? && params[:done_within].blank?
      @done_within = session_hash["done_within"]
    else
      @done_within = params[:done_within]
    end

    # Target user ID
    if !session_hash.blank? && params[:user_id].blank?
      @user_id = session_hash["user_id"]
    else
      @user_id = params[:user_id]
    end

    # Target group ID
    if !session_hash.blank? && params[:group_id].blank?
      @group_id = session_hash["group_id"]
    else
      @group_id = params[:group_id]
    end

    # Selected statuses
    if !session_hash.blank? && params[:status_fields].blank?
      @status_fields = session_hash["status_fields"]
    else
      @status_fields = params[:status_fields]
    end

    # Selected project
    if !session_hash.blank? && params[:project_all].blank?
      @project_all = session_hash["project_all"]
    else
      @project_all = params[:project_all]
    end

    # Max number of WIP issue
    if !session_hash.blank? && params[:wip_max].blank?
      @wip_max = session_hash["wip_max"]
    else
      @wip_max = params[:wip_max]
    end
  end

  #
  # Initialize and store session
  #
  def initialize_params_and_store_session
    session_hash = {}

    # Days since upadated date (default)
    if @updated_within == nil || @updated_within.to_i == 0 then
      @updated_within = Constants::DEFAULT_VALUE_UPDATED_WITHIN
    end
    session_hash["updated_within"] = @updated_within
    
    # Days since closed date (default)
    if @done_within == nil || @done_within.to_i == 0 then
      @done_within = Constants::DEFAULT_VALUE_DONE_WITHIN
    end
    session_hash["done_within"] = @done_within

    # Default user ID (= current user)
    if @user_id == nil || @user_id.to_i == 0 then
      @user_id = @current_user.id
    end
    session_hash["user_id"] = @user_id
    
    # Project identifier
    @project_id = params[:project_id]
    if @project_id.blank? == true then
      @project = nil
    else
      @project = Project.find(@project_id)
    end
    
    # Get all group
    @all_groups = Group.where(type: "Group")

    # Create array of user ID belongs to group
    @user_id_array = []
    if @group_id == nil || @group_id.to_i == 0 then
      # Case no group selected
      @user_id_array << @user_id.to_i
      @group_id = "all"
    else
      # Case group selected
      @all_groups.each {|group|
        if group.id == @group_id.to_i
          @user_id_array = group.user_ids
        end
      }
    end
    session_hash["group_id"] = @group_id

    # Case <unspecified> selected
    if @project_id.blank? == true then
      @project_all = "1"
    else
      if @project_all.blank? == true then
        @project_all = "0"
      end
    end
    session_hash["project_all"] = @project_all

    # Array of status ID for display
    @status_fields_array = []
    if !@status_fields.blank? then
      @status_fields.each {|id,chk|
        if chk == "1"
          @status_fields_array << id.to_i
        end
      }
    else
      # Default
      @status_fields_array = Constants::DEFAULT_STATUS_FIELD_VALUE_ARRAY
    end
    session_hash["status_fields"] = @status_fields

    # Max number of WIP issue (default)
    if @wip_max == nil || @wip_max.to_i == 0 then
      @wip_max = Constants::DEFAULT_VALUE_WIP_MAX
    end
    session_hash["wip_max"] = @wip_max

    # Store session
    session[:kanban] = session_hash
  end


  #
  # User logged in
  #
  def set_user
    @current_user ||= User.current
  end

  #
  # Need Login
  #
  def global_authorize
    set_user
    render_403 unless @current_user.type == 'User'
  end

end
