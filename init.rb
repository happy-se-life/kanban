Redmine::Plugin.register :kanban do
  name 'Kanban plugin'
  author 'Kohei Nomura'
  description 'Kanban plugin for redmine'
  version '0.0.7'
  url 'https://github.com/happy-se-life/kanban'
  author_url 'mailto:kohei_nom@yahoo.co.jp'
  
  # Display application common menu
  menu :application_menu, :display_menu_link, { :controller => 'kanban', :action => 'index' }, :caption => :kanban_menu_caption, :if => Proc.new { User.current.logged? }
  
  # Display menu at project page
  menu :project_menu, :display_menu_link, { :controller => 'kanban', :action => 'index' }, :caption => :kanban_menu_caption, :param => :project_id

  # Enable permission for each project
  project_module :kanban do
    permission :display_menu_link, {:kanban => [:index]}
 end
end
