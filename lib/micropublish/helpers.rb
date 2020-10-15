# frozen_string_literal: true

module Micropublish
  module Helpers
    def h(text)
      Rack::Utils.escape_html(text)
    end

    def flash_message
      if session.key?('flash') && !session[:flash].empty?
        content = %(
          <div class="alert alert-#{session[:flash][:type]}">
            #{session[:flash][:message]}
          </div>
        )
        session.delete('flash')
        content
      end
    end

    def default_format
      if session.key?('format') && session[:format] == :form
        :form
      else
        :json
      end
    end

    def autogrow_script(id)
      %{
        <script>
          $(function(){
            $('##{id}').autogrow({vertical: true, horizontal: false});
          });
        </script>
      }
    end

    def tokenfield_script(id)
      %{
        <script>
          $(function(){
            $('##{id}').tokenfield();
          });
        </script>
      }
    end

    def tweet_reply_prefix(tweet_url)
      tweet_match = tweet_url.to_s.match(%r{twitter\.com/([A-Za-z0-9_]+)/})
      tweet_match.nil? ? '' : "@#{tweet_match[1]} "
    end
  end
end
