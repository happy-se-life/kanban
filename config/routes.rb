# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
Rails.application.routes.draw do
  resources :kanban
  post 'update_status', to: 'issue#update_status'
  post 'put_journal', to: 'journal#put_journal'
end