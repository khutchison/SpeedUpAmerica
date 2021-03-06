Rails.application.routes.draw do

  resources :home, only: :index do
    collection do
      post :get_location_data
      post :calculate_ping
    end
  end

  resources :submissions, only: :create do
    collection do
      post :export_csv, defaults: { format: :csv }
    end
  end

  get 'all-results', to: 'submissions#result_page', as: :result_page
  get 'result/:id', to: 'submissions#show', as: :submission
  post 'mapbox_data', to: 'submissions#mapbox_data', defaults: { format: :json }
  get 'speed_data', to: 'submissions#speed_data'
  get 'isps_data', to: 'submissions#isps_data'
  get '/internet-stats', to: redirect('/all-results')
  get 'embeddable_view', to: 'submissions#embeddable_view'
  get 'embed', to: 'submissions#embed', defaults: { format: :js }, constraints: { format: :js }
  root 'home#index'

  match '*invalid_path', to: 'application#rescue_from_invalid_url', via: [:get, :post]

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
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

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
