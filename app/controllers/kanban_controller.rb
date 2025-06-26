class KanbanController < ApplicationController
  if Redmine::VERSION::MAJOR < 4 || (Redmine::VERSION::MAJOR == 4 && Redmine::VERSION::MINOR < 1)
    unloadable
  end
  before_action :global_authorize
  #
  # Display kanban board
  #
  def index 
    # Do not cache on browser back
    response.headers['Cache-Control'] = 'no-store, no-cache, must-revalidate, max-age=0, post-check=0, pre-check=0'
    response.headers['Pragma'] = 'no-cache'
    
    # Discard session
    if params[:clear].to_i == 1 then
      discard_session
    end

    # Restore session
    restore_params_from_session

    # Initialize params
    initialize_params

    # Store session
    store_params_to_session

    # Get user to display avator
    if @user_id == "unspecified" then
      @user = User.find(@current_user.id)
    else
      @user = User.find(@user_id.to_i)
    end
  
    # Get current project
    if @project_id.blank? then
      @project = nil
    else
      @project = Project.find(@project_id)
    end
    
    # Get users for assignee filetr
    if @project_all == "1" then
      @selectable_users = User.where(type: "User").where(status: 1)
    else
      # Get users who have roles in the project
      project_users = @project.users
      
      # Get users who are assigned to issues in the project (including those without roles)
      assigned_user_ids = Issue.where(project_id: @project.id)
                               .where.not(assigned_to_id: nil)
                               .pluck(:assigned_to_id)
                               .uniq
      
      assigned_users = User.where(id: assigned_user_ids, type: "User", status: 1)
      
      # Combine project users and assigned users
      @selectable_users = User.where(id: (project_users.pluck(:id) + assigned_users.pluck(:id)).uniq)
                             .where(type: "User", status: 1)
    end

    # Get groups for group filetr
    if @project_all == "1" then
      @selectable_groups = Group.where(type: "Group")
    else
      members = Member.where(project_id: @project.id)
      member_user_ids = []
      members.each {|member|
        member_user_ids << member.user_id
      }
      @selectable_groups = Group.where(type: "Group").where(id: member_user_ids)
    end

    # Create array of dispaly user IDs belongs to the group
    @user_id_array = []
    if @group_id == "unspecified" then
      # Case group is unspecified
      if @user_id == "unspecified" then
        # Case user is unspecified
        @user_id_array = @selectable_users.ids
      else
        # Case user is specified
        @user_id_array << @user.id
      end
    else
      # Case group is specified
      @selectable_groups.each {|group|
        if group.id == @group_id.to_i
          @user_id_array = group.user_ids
        end
      }
    end

    # Remove inactive users from array of display users
    copied_user_id_array = @user_id_array.dup
    copied_user_id_array.each {|id|
      if !@selectable_users.ids.include?(id) then
        @user_id_array.delete(id)
      end
    }

    # Move current user to head
    selected_user_index = @user_id_array.index(@user.id)
    if @user_id_array.length > 1 && selected_user_index != nil then
      swap_id = @user_id_array[0]
      @user_id_array[selected_user_index] = swap_id
      @user_id_array[0] = @user.id
    end

    # When system settings of issue_group_assignment is true,
    # add group ID to array of display users
    @group_id_array = []
    if Setting.issue_group_assignment? then
      if @group_id == "unspecified" then
        @selectable_groups.each {|group|
            @user_id_array << group.id
            @group_id_array << group.id
        }
      else
        @user_id_array << @group_id.to_i
        @group_id_array << @group_id.to_i
      end
    end

    # Create hash of users/groups name
    @user_and_group_names_hash = {}
    @selectable_users.each {|user|
      @user_and_group_names_hash[user.id] = user.name
    }
    @selectable_groups.each {|group|
      @user_and_group_names_hash[group.id] = group.name
    }

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

    # Get trackers
    if @project.nil? then
      @trackers = Tracker.sorted
    else
      @trackers = @project.rolled_up_trackers
    end

    # Updated datetime for filter
    if @updated_within == "unspecified" then
      updated_from = "1970-01-01 00:00:00"
    else
      time_from = Time.now - 3600 * 24 * @updated_within.to_i
      updated_from = time_from.strftime("%Y-%m-%d 00:00:00")
    end

    # Closed datetime for filter
    if @done_within == "unspecified" then
      closed_from = "1970-01-01 00:00:00"
    else
      time_from = Time.now - 3600 * 24 * @done_within.to_i
      closed_from = time_from.strftime("%Y-%m-%d 00:00:00")
    end

    # Due datetime for filetr
    due_from = ""
    due_to = ""
    due_now = Time.now
    case @due_date 
      when "overdue" then
        due_from = "1970-01-01"
        due_to = due_now.yesterday.strftime("%Y-%m-%d")
      when "today" then
        due_from = due_now.strftime("%Y-%m-%d")
        due_to = due_from
      when "tommorow" then
        due_from = due_now.tomorrow.strftime("%Y-%m-%d")
        due_to = due_from
      when "thisweek" then
        due_from = due_now.beginning_of_week.strftime("%Y-%m-%d")
        due_to = due_now.end_of_week.strftime("%Y-%m-%d")
      when "nextweek" then
        due_from = due_now.next_week.beginning_of_week.strftime("%Y-%m-%d")
        due_to = due_now.next_week.end_of_week.strftime("%Y-%m-%d")
    end

    # Get issues related to display users
    issues_for_projects = Issue.where(assigned_to_id: @user_id_array)
      .where("updated_on >= '" + updated_from + "'")
      .where(get_issues_visibility_condition)

    if Constants::SELECT_LIMIT_STRATEGY == 1 then
      issues_for_projects = issues_for_projects.limit(Constants::SELECT_LIMIT)
    end

    # Unique project IDs
    unique_project_id_array = []
    if @project_all == "1" then
      issues_for_projects.each {|issue|
        if unique_project_id_array.include?(issue.project.id.to_i) == false then
          unique_project_id_array << issue.project.id.to_i
        end
      }
    else
      # When select one project, add subproject IDs
      fill_subproject_ids(@project.id.to_i, unique_project_id_array)
    end

    # Display no assignee issue
    @user_id_array << nil;

    # Declaring variables
    @issues_hash = {}
    @wip_hash = {}

    # Get issues using status loop
    @status_fields_array.each {|status_id|
      if @done_issue_statuses_array.include?(status_id) == false then
        # Case not closed status
        issues = Issue.where(assigned_to_id: @user_id_array)
          .where(project_id: unique_project_id_array)
          .where(status: status_id)
          .where(get_issues_visibility_condition)
          .where("updated_on >= '" + updated_from + "'")
        if @version_id != "unspecified" then
          issues = issues.where(fixed_version_id: @version_id)
        end
        if @due_date != "unspecified" then
          issues = issues.where("due_date >= '" + due_from + "'").where("due_date <= '" + due_to + "'")
        end
        if @tracker_id != "unspecified" then
          issues = issues.where(tracker_id: @tracker_id)
        end
        @issues_hash[status_id] = issues.order(updated_on: "DESC").limit(Constants::SELECT_LIMIT)
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
        issues = Issue.where(assigned_to_id: @user_id_array)
            .where(project_id: unique_project_id_array)
            .where(status: status_id)
            .where(get_issues_visibility_condition)
            .where("updated_on >= '" + closed_from + "'")
        if @version_id != "unspecified" then
          issues = issues.where(fixed_version_id: @version_id)
        end
        if @due_date != "unspecified" then
          issues = issues.where("due_date >= '" + due_from + "'").where("due_date <= '" + due_to + "'")
        end
        if @tracker_id != "unspecified" then
          issues = issues.where(tracker_id: @tracker_id)
        end
        @issues_hash[status_id] = issues.order(updated_on: "DESC").limit(Constants::SELECT_LIMIT)
      end
    }

    # Hide user without issues
    if Constants::DISPLAY_USER_WITHOUT_ISSUES != 1 then
      remove_user_without_issues
    end    
  end
  
  private

  #
  # Get issues visibility condition based on user's role settings
  #
  def get_issues_visibility_condition
    if @current_user.admin?
      # Admin can see all issues
      return '1=1'
    end

    # Get user's roles for the current project
    if @project
      roles = @current_user.roles_for_project(@project)
    else
      # For all projects, use the most permissive role
      roles = @current_user.roles.to_a
    end

    return '1=0' if roles.empty?

    # Find the most permissive issues_visibility setting
    visibility_levels = roles.map(&:issues_visibility).compact
    return '1=0' if visibility_levels.empty?

    # Determine the most permissive setting
    if visibility_levels.include?('all')
      # 'all' - can see all issues including private ones
      return '1=1'
    elsif visibility_levels.include?('default')
      # 'default' - can see non-private issues or issues created by/assigned to user
      user_ids = [@current_user.id] + @current_user.groups.pluck(:id).compact
      return "(#{Issue.table_name}.is_private = #{Issue.connection.quoted_false} " \
             "OR #{Issue.table_name}.author_id = #{@current_user.id} " \
             "OR #{Issue.table_name}.assigned_to_id IN (#{user_ids.join(',')}))"
    elsif visibility_levels.include?('own')
      # 'own' - can only see issues created by or assigned to user
      user_ids = [@current_user.id] + @current_user.groups.pluck(:id).compact
      return "(#{Issue.table_name}.author_id = #{@current_user.id} OR " \
             "#{Issue.table_name}.assigned_to_id IN (#{user_ids.join(',')}))"
    else
      # Fallback to most restrictive
      return '1=0'
    end
  end

  #
  # Discard session
  #
  def discard_session
    session[:kanban] = nil
  end

  #
  # Store session
  #
  def store_params_to_session

    session_hash = {}
    session_hash["updated_within"] = @updated_within
    session_hash["done_within"] = @done_within
    session_hash["due_date"] = @due_date
    session_hash["tracker_id"] = @tracker_id
    session_hash["user_id"] = @user_id
    session_hash["group_id"] = @group_id
    session_hash["project_all"] = @project_all
    session_hash["version_id"] = @version_id
    session_hash["open_versions"] = @open_versions
    session_hash["status_fields"] = @status_fields.to_json
    session_hash["wip_max"] = @wip_max
    session_hash["card_size"] = @card_size
    session_hash["show_ancestors"] = @show_ancestors
    session[:kanban] = session_hash
  end

  #
  # Restore session
  #
  def restore_params_from_session
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

    # Due date
    if !session_hash.blank? && params[:due_date].blank?
      @due_date = session_hash["due_date"]
    else
      @due_date = params[:due_date]
    end

    # Display tracker ID
    if !session_hash.blank? && params[:tracker_id].blank?
      @tracker_id = session_hash["tracker_id"]
    else
      @tracker_id = params[:tracker_id]
    end
    
    # Display user ID
    if !session_hash.blank? && params[:user_id].blank?
      @user_id = session_hash["user_id"]
    else
      @user_id = params[:user_id]
    end

    # Display group ID
    if !session_hash.blank? && params[:group_id].blank?
      @group_id = session_hash["group_id"]
    else
      @group_id = params[:group_id]
    end

    # Project display flag
    if !session_hash.blank? && params[:project_all].blank?
      @project_all = session_hash["project_all"]
    else
      @project_all = params[:project_all]
    end

    # Display version ID
    if !session_hash.blank? && params[:version_id].blank?
      @version_id = session_hash["version_id"]
    else
      @version_id = params[:version_id]
    end

    # Only open versions flag
    if !session_hash.blank? && params[:open_versions].blank?
      @open_versions = session_hash["open_versions"]
    else
      @open_versions = params[:open_versions]
    end

    # Selected statuses
    if !session_hash.blank? && params[:status_fields].blank?
      if !session_hash["status_fields"].blank?
        @status_fields = JSON.parse( session_hash["status_fields"])
      else
        @status_fields = ""
      end
    else
      @status_fields = params[:status_fields]
    end

    # Max number of WIP issue
    if !session_hash.blank? && params[:wip_max].blank?
      @wip_max = session_hash["wip_max"]
    else
      @wip_max = params[:wip_max]
    end

    # Card size
    if !session_hash.blank? && params[:card_size].blank?
      @card_size = session_hash["card_size"]
    else
      @card_size = params[:card_size]
    end

    # Show ancestors
    if !session_hash.blank? && params[:show_ancestors].blank?
      @show_ancestors = session_hash["show_ancestors"]
    else
      @show_ancestors = params[:show_ancestors]
    end
  end

  #
  # Initialize params
  # When value is invalid, set it to default. 
  #
  def initialize_params
    # Days since upadated date
    if @updated_within.nil? || (@updated_within.to_i == 0 && @updated_within != "unspecified") then
      @updated_within = Constants::DEFAULT_VALUE_UPDATED_WITHIN
    end
    
    # Days since closed date
    if @done_within.nil? || (@done_within.to_i == 0 && @done_within != "unspecified") then
      @done_within = Constants::DEFAULT_VALUE_DONE_WITHIN
    end

    # Due date
    due_date_values = ["overdue", "today", "tommorow", "thisweek", "nextweek", "unspecified"]
    if @due_date.nil? || !due_date_values.include?(@due_date.to_s) then
      @due_date = "unspecified"
    end

    # Tracker ID
    if @tracker_id.nil? || @tracker_id.to_i == 0 then
      @tracker_id = "unspecified"
    end

    # User ID
    if @user_id.nil? || (@user_id.to_i == 0 && @user_id != "unspecified") then
      @user_id = @current_user.id
    end
    
    # Group ID
    if @group_id.nil? || @group_id.to_i == 0 then
      @group_id = "unspecified"
    end

    # Project display flag
    @project_id = params[:project_id]
    if @project_id.blank? then
      # Case move from application menu
      @project_all = "1"
    else
      # Case move from project menu
      if @project_all.blank? then
        @project_all = "0"
      end
    end

    # Version ID
    if @version_id.nil? || @version_id.to_i == 0 || @project_all == "1" then
      @version_id = "unspecified"
    end

    # Only open versions flag
    if @open_versions.nil? then
      @open_versions = "1"
    end

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

    # Max number of WIP issue (default)
    if @wip_max.nil? || @wip_max.to_i == 0 then
      @wip_max = Constants::DEFAULT_VALUE_WIP_MAX
    end

    # Card size (default)
    if @card_size.nil? || (@card_size != "normal_days_left" && @card_size != "normal_estimated_hours" && @card_size != "normal_spent_hours" && @card_size != "small") then
      @card_size = Constants::DEFAULT_CARD_SIZE
    end

    # Show ancestors (default)
    if @show_ancestors.nil?  then
      @show_ancestors = Constants::DEFAULT_SHOW_ANCESTORS
    end
  end

  #
  # Remove user without issues from @user_id_array
  #
  def remove_user_without_issues
    copied_user_id_array = @user_id_array.dup
    copied_user_id_array.each {|uid|
      number_of_issues = 0
      @status_fields_array.each {|status_id|
        @issues_hash[status_id].each {|issue|
          if issue.assigned_to_id == uid then
            number_of_issues += 1
          end
        }
      }
      if !uid.nil? && number_of_issues == 0 then
        @user_id_array.delete(uid)
      end
    }
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

  #
  # Get all subprojects
  #
  def fill_subproject_ids(project_id, unique_project_id_array)
    if unique_project_id_array.include?(project_id) == true then
      return
    end

    unique_project_id_array << project_id
    subprojects = Project.where(parent_id: project_id)
    subprojects.each {|subproject|
      fill_subproject_ids(subproject.id.to_i, unique_project_id_array)
    }
  end

end
