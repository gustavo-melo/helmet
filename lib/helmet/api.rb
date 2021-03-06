require 'goliath/api'

require 'helmet/handler'

module Helmet
  class API < Goliath::API
    
    class << self
      
      def set(key, value)
        @config[key.to_sym] = value
      end

      def config(key)
        @config[key.to_sym]
      end
      
      def before(route, &block)
        @before_filters << [route, block]
      end
      
      def routes
        @routes
      end
      
      def before_filters
        @before_filters
      end
      
      # include methods to the helper
      def helpers(&block)
        @helpers.module_exec(&block)
      end
      
      def get_helpers
        @helpers
      end
      
      def get(route, &block) 
        register_route('GET', route, &block);
        register_route('HEAD', route, &block);
      end
      def post(route, &block) register_route('POST', route, &block); end
      def put(route, &block) register_route('PUT', route, &block); end
      def delete(route, &block) register_route('DELETE', route, &block); end
      def head(route, &block) register_route('HEAD', route, &block); end

      def register_route(method, route, &block)
        sig = API.signature(method, route)
        @routes[sig] = block
      end
      
      def signature(method, route)
        "#{method}#{route}"
      end

      def inherited(klass)
        klass.init
        
        # setup basic middlewares
        setup_middlewares klass

        # compute public/ views folder
        base = File.expand_path(File.dirname(caller.first[/^[^:]*/]))
        klass.set :public_folder, File.join(base, 'public')
        klass.set :views_folder, File.join(base, 'views')

        super # update Goliath::Application.app_class
      end

      def init
        # Handle application routes
        @routes          = {}

        # Handle before filters
        @before_filters  = []

        @config          = {}
        
        @helpers         = Module.new
      end

      private
            
      def setup_middlewares(klass)
        # support for session
        klass.use Rack::Session::Cookie
        # support for forms
        klass.use Goliath::Rack::Params 
      end
    end

    def response(env)
      # request path
      path    = env['REQUEST_PATH']
      
      # request handler
      handler = Handler.new(env, self.class)
      
      # include Helpers
      handler.extend(self.class.get_helpers)

      catch(:halt) do
        # evaluate filters
        self.class.before_filters.each do |route|
          case route.first
          when String
            handler.handle! &route[1] if route.first == path
          when Regexp
            handler.handle! &route[1] if route.first =~ path
          end
        end
        
        sig = API.signature(env['REQUEST_METHOD'], path)
        block = self.class.routes[sig]
        if block
          handler.handle!(&block)
        else
          handler.handle! do
            status 404
            'not found!'
          end
        end
      end
      handler.response.format_response
    end
  end
end
  