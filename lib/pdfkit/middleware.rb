class PDFKit
  
  # A rack middleware for validating HTML via w3c validator
  class Middleware
    
    def initialize(app, options = {})
      @app = app
      @options = options
    end
        
    def call(env)
      @render_pdf = false
      set_request_to_render_as_pdf(env) if env['PATH_INFO'].match(/\.pdf$/)
      
      status, headers, response = @app.call( env )
      
      request = Rack::Request.new( env )
      if @render_pdf && headers['Content-Type'] =~ /text\/html|application\/xhtml\+xml/
        body = response.body
        
        body = translate_paths(body, env)
        
        pdf = PDFKit.new(body, @options)
        body = pdf.to_pdf
        
        # Do not cache PDFs
        puts "DELETING CACHING"
        headers.delete('ETag')
        headers.delete('Cache-Control')
        
        headers["Content-Length"] = body.length.to_s
        headers["Content-Type"] = "application/pdf"
        
        response = [body]
      end
      
      [status, headers, response]
    end
    
    private
    
      def translate_paths(body, env)
        # Make absolute urls
        uri = env['REQUEST_URI'].split('?').first
        uri += '/' unless uri.match(/\/$/)
        root = env['rack.url_scheme'] + "://" + env['HTTP_HOST']
        
        # translate relative urls
        body.gsub!(/(href|src)=['"]([^\/][^\"']*)['"]/,'\1="'+root+'/\2"')
        
        # translate absolute urls
        body.gsub!(/(href|src)=['"]\/([^\"]*|[^']*)['"]/,'\1="'+uri+'\2"')
      end
    
      def set_request_to_render_as_pdf(env)
        @render_pdf = true
        puts "Setting PDF mode"
        
        path = Pathname(env['PATH_INFO'])
        env['PATH_INFO'] = path.to_s.sub(/#{path.extname}$/,'') if path.extname == '.pdf'
        env['HTTP_ACCEPT'] = concat(env['HTTP_ACCEPT'], Rack::Mime.mime_type('html'))
      end
      
      def concat(accepts, type)
        (accepts || '').split(',').unshift(type).compact.join(',')
      end
  
  end
end