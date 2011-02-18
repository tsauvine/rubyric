Rubyric::Application.routes.draw do
  resource :session do
    get 'shibboleth'
  end
  
  resource :frontpage, :only => [:show], :controller => 'frontpage'
  
  resources :users
  resources :groups
  
  resources :courses do
    get 'teachers'
    post 'add_teachers'
    post 'remove_selected_teachers'
  end
  
  resources :course_instances, :except => [:index] do
    resources :students, :controller => 'course_instances/students' do
    end
    
    resources :assistants, :controller => 'course_instances/assistants' do
    end
  end
  
  
  resources :rubrics
  resources :submissions
  resources :reviews
  resources :feedbacks
  
  resources :exercises do
    get 'results'
    get 'statistics'
    get 'batch_assign'
  end


  match '/exercise/new/:instance' => 'exercises#new'
  match '/submit/:exercise' => 'submissions#new', :as => :submit
  
  match '/login' => 'sessions#new', :as => :login
  match '/logout' => 'sessions#destroy', :as => :logout
  
  root :to => "frontpage#show"
  
  # Install the default routes as the lowest priority.
  # FIXME: get rid of this
  #match ':controller(/:action(/:id(.:format)))'
  
  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  # root :to => "welcome#index"

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id(.:format)))'
end
