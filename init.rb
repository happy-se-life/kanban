Redmine::Plugin.register :kanban do
  name 'Kanban plugin'
  author 'Kohei Nomura'
  description 'Kanban plugin for redmine'
  version '0.0.5'
  url 'https://github.com/happy-se-life/kanban'
  author_url 'mailto:kohei_nom@yahoo.co.jp'
  
  # Display application common menu
  menu :application_menu, :kanban, { :controller => 'kanban', :action => 'index' }, :caption => :kanban_menu_caption, :if => Proc.new { User.current.logged? }
  
  # Display menu at project page
  menu :project_menu, :kanban, { :controller => 'kanban', :action => 'index' }, :caption => :kanban_menu_caption, :param => :project_id

  # Enable permission for each project
  project_module :kanban do
    permission :kanban, {:kanban => [:index]}
 end
end
