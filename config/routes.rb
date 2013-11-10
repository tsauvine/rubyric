Rubyric::Application.routes.draw do 
  resource :session, :only => [:new, :create, :destroy] do
    get 'shibboleth'
  end

  resource :frontpage, :only => [:show], :controller => 'frontpage'
  

  resources :users, :except => [:index] do
    collection do
      get :search
    end
  end
  match 'preferences' => 'users#edit'

  resources :courses do
    resources :course_instances, :only => [:new, :create, :update]
    resources :teachers, :only => [:index, :create, :destroy], :controller => 'courses/teachers'
  end

  resources :course_instances, :only => [:show, :edit, :destroy] do
    resources :exercises, :only => [:new, :create, :update]
    
    resources :reviewers, :only => [:index, :create, :destroy], :controller => 'course_instances/reviewers'
    
    resource :students, :only => [:show], :controller => 'course_instances/students'
    
    resource :groups, :only => [:update], :controller => 'course_instances/groups'
    resources :groups, :only => [:index, :edit, :update], :controller => 'course_instances/groups' do
      collection do
        get :batch
        post :batch
      end
    end
    
    get :create_example_groups
  end

  resources :exercises, :only => [:show, :edit, :destroy] do
    get 'results'
    get 'statistics'
    get 'batch_assign'
    post 'batch_assign'
    get 'archive'
    post 'delete_reviews'
    post 'send_reviews'
    
    get :create_example_submissions

    resource :rubric, :only => [:show, :edit, :update] do
      member do
        get 'download'
        get 'upload'
        post 'upload'
      end
    end

    resources :groups
  end

  match 'groups/:id/join/:token' => 'groups#join', :as => :join_group

  resources :invitations, :only => [:show, :destroy], :id => /[^\/]+/ do
#     member do
#       get 'teacher'
#       get 'assistant'
#       get 'group'
#     end
  end
  
  resources :submissions, :only => [:show, :new, :create, :destroy] do
    member do
      get :review
      get :confirm_delete
      match 'move' => 'submissions#move', :via => [:get, :post]
    end
  end

  resources :reviews, :only => [:show, :edit, :update] do
    member do
      get :finish
      put :update_finish
      get :reopen  # FIXME: should be POST
      get :upload
      post :upload
      get :download
    end
  end


  #match '/exercise/new/:instance' => 'exercises#new'
  match 'submit/:exercise' => 'submissions#new', :via => :get, :as => :submit
  match 'submit/:exercise' => 'submissions#create', :via => :post

  match '/login' => 'sessions#new', :as => :login
  match '/logout' => 'sessions#destroy', :as => :logout

  root :to => "frontpage#show"

  # Install the default routes as the lowest priority.
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
  #match ':controller(/:action(/:id(.:format)))'

end
