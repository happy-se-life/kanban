Redmine::Plugin.register :kanban do
  name 'Kanban plugin'
  author 'Kohei Nomura'
  description 'Kanban plugin for redmine'
  version '0.0.3'
  url 'https://twitter.com/happy_se_life'
  author_url 'mailto:kohei_nom@yahoo.co.jp'
  
  #アプリケーションメニューに「かんばん」を表示
  menu :application_menu, :kanban, { :controller => 'kanban', :action => 'index' }, :caption => 'かんばん', :if => Proc.new { User.current.logged? }
  
  #プロジェクトメニューに「かんばん」を表示
  menu :project_menu, :kanban, { :controller => 'kanban', :action => 'index' }, :caption => 'かんばん', :param => :project_id
  
  # プロジェクトごとの権限を追加
  project_module :kanban do
    permission :kanban, {:kanban => [:index]}
 end
end
