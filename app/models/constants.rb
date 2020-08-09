#
# Constant definition
#
class Constants < ActiveRecord::Base

  # Max number of selections
  SELECT_LIMIT = 250

  # Days since upadated date
  # Please choose "1" "3" "7" "14" "31" "62" "93" "unspecified"
  DEFAULT_VALUE_UPDATED_WITHIN = "31"

  # Days since closed date
  # Please choose "1" "3" "7" "14" "31" "62" "93" "unspecified"
  DEFAULT_VALUE_DONE_WITHIN = "14"

  # Max number of WIP issue
  DEFAULT_VALUE_WIP_MAX = "2"

  # Array of status IDs to be displayed initially
  # Please customize this array for your environment
  # 1: New
  # 2: In Progress
  # 3: Resolved
  # 4: Feedback
  # 5: Closed
  # 6: Rejected
  DEFAULT_STATUS_FIELD_VALUE_ARRAY = [1,2,3,4,5]

  # Status ID for WIP count
  WIP_COUNT_STATUS_FIELD = 2

  # Max number of note on sidebar
  MAX_NOTES = 3

  # Order of note on sidebar
  # Please choose "ASC" "DESC"
  ORDER_NOTES = "DESC"

  # Max length of note on sidebar (bytes)
  MAX_NOTES_BYTESIZE = 350

  # Enable display user's avator at user lane
  # 0: None
  # 1: Display avator
  DISPLAY_USER_AVATOR = 1

  # Enable hide user without issues
  # 0: Hide
  # 1: Show
  DISPLAY_USER_WITHOUT_ISSUES = 1

  # Display comment dialog when issue was dropped
  # 0: Not display
  # 1: Display
  DISPLAY_COMMENT_DIALOG_WHEN_DROP = 1
end
