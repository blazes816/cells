require 'cell/rack'

module Cell
  class Rails < Rack
    # When this file is included we can savely assume that a rails environment with caching, etc. is available.
    include ActionController::RequestForgeryProtection
    
    abstract!
    delegate :session, :params, :request, :config, :env, :url_options, :to => :parent_controller
    
    class << self
      attr_accessor :asset_environment
      
      def cache_store
        # FIXME: i'd love to have an initializer in the cells gem that _sets_ the cache_store attr instead of overriding here.
        # since i dunno how to do that we'll have this method in rails for now.
        # DISCUSS: should this be in Cell::Rails::Caching ?
        ActionController::Base.cache_store
      end
      
      def expire_cache_key(key, *args)  # FIXME: move to Rails.
        expire_cache_key_for(key, cache_store ,*args)
      end
      
      # Each Cell class maintains its own asset environment.  We generate that
      # here by copying the application assets environment and adding the right paths
      def asset_environment        
        @asset_environment ||= begin
          # If the superclass is Cell::Base or another abstract, we dup the
          # main assets environment
          if superclass.abstract?
            environment = ::Rails.application.assets.dup
            
            # DISCUSS: Because trail isn't deepcopied, we need to do it manually
            # and reject previsously added cells paths.  Gross.
            environment.instance_eval do
              @trail = @trail.dup
              @trail.paths.reject! { |p| p =~ /cell/ }
            end
          else
            environment = superclass.asset_environment
          end
          
          # Now that we have our env, add the paths for each asset type
          environment.tap do |env|
            paths = view_paths.reverse.map(&:to_s).product([:javascripts, :stylesheets, :images])
            paths.each do |(view_path, asset_type)|
              env.prepend_path File.join(view_path, parent_prefixes, controller_path, asset_type.to_s)
            end
          end
        end
      end
      
    private
      # Run builder block in controller instance context.
      def run_builder_block(block, controller, *args)
        controller.instance_exec(*args, &block)
      end
    end
    
    
    attr_reader :parent_controller
    
    def initialize(parent_controller)
      super
      @parent_controller = parent_controller
    end
    
    def cache_configured?
      ActionController::Base.send(:cache_configured?) # DISCUSS: why is it private?
    end
    
    def cache_store
      self.class.cache_store  # in Rails, we have a global cache store.
    end

    # Override _prefixes so we get hierarchial prefixes instead of flat ones
    def _prefixes
      @_prefixes ||=  begin
        flat_prefixes = super.reverse
        
        [].tap do |prefixes|
          flat_prefixes.length.downto(0) do |p|
            prefixes << flat_prefixes[0, p].push('views').join('/')
          end
        end
      end
    end
  end
end
