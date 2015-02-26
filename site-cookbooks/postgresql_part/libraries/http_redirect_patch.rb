# NoMethodError occurs when the source has been redirected in remote_file resources
# This is a monkey patch to fix the problem
# If you want to use a chef 12.2.0 alpha, because the problem has been fixed that you want to delete this file

chef_ver = ::Chef::VERSION.split('.')

if chef_ver[0].to_i < 12 || chef_ver[0].to_i == 12 && chef_ver[1].to_i < 2
  ::Chef::HTTP.class_eval do
    def send_http_request_patched(method, url, headers, body, &response_handler)
      headers = build_headers(method, url, headers, body)

      retrying_http_errors(url) do
        client = http_client(url)
        return_value = nil
        if block_given?
          request, response = client.request(method, url, body, headers, &response_handler)
        else
          request, response = client.request(method, url, body, headers) { |r| r.read_body }
          return_value = response.read_body
        end
        @last_response = response

        if response.is_a?(Net::HTTPSuccess)
          [response, request, return_value]
        elsif response.is_a?(Net::HTTPNotModified) # Must be tested before Net::HTTPRedirection because it's subclass.
          [response, request, false]
        elsif redirect_location = redirected_to(response)
          if [:GET, :HEAD].include?(method)
            follow_redirect do
              send_http_request(method, url + redirect_location, headers, body, &response_handler)
            end
          else
            fail Exceptions::InvalidRedirect, "#{method} request was redirected from #{url} to #{redirect_location}. Only GET and HEAD support redirects."
          end
        else
          [response, request, nil]
        end
      end
    end
    alias_method :send_http_request_org, :send_http_request
    alias_method :send_http_request, :send_http_request_patched
  end
end
