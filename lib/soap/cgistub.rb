=begin
SOAP4R - CGI stub library
Copyright (C) 2001, 2003  NAKAMURA, Hiroshi.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PRATICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 675 Mass
Ave, Cambridge, MA 02139, USA.
=end


require 'soap/rpc/server'
require 'soap/streamHandler'
require 'http-access2/http'


module SOAP


###
# SYNOPSIS
#   CGIStub.new
#
# DESCRIPTION
#   To be written...
#
class CGIStub < RPC::Server
  include SOAP

  # There is a client which does not accept the media-type which is defined in
  # SOAP spec.
  attr_accessor :mediatype

  class CGIError < Error; end

  class SOAPRequest
    ALLOWED_LENGTH = 1024 * 1024

    def initialize(stream = $stdin)
      @method = ENV['REQUEST_METHOD']
      @size = ENV['CONTENT_LENGTH'].to_i || 0
      @contenttype = ENV['CONTENT_TYPE']
      @charset = nil
      @soapaction = ENV['HTTP_SOAPAction']
      @source = stream
      @body = nil
    end

    def init
      validate
      @charset = StreamHandler.parse_media_type(@contenttype)
      @body = @source.read(@size)
      self
    end

    def dump
      @body.dup
    end

    def soapaction
      @soapaction
    end

    def charset
      @charset
    end

    def to_s
      "method: #{ @method }, size: #{ @size }"
    end

  private

    def validate # raise CGIError
      if @method != 'POST'
	raise CGIError.new("Method '#{ @method }' not allowed.")
      end

      if @size > ALLOWED_LENGTH
        raise CGIError.new("Content-length too long.")
      end
    end
  end

  def initialize(appname, namespace)
    super(appname, namespace)
    @remote_user = ENV['REMOTE_USER'] || 'anonymous'
    @remote_host = ENV['REMOTE_HOST'] || ENV['REMOTE_ADDR'] || 'unknown'
    @request = nil
    @response = nil
    @mediatype = MediaType
  end
  
  def on_init
    # Override this method in derived class to call 'add_method' to add methods.
  end

private
  
  def run
    @log.sev_threshold = SEV_INFO

    prologue

    begin
      log(SEV_INFO) { "Received a request from '#{ @remote_user }@#{ @remote_host }'." }
    
      # SOAP request parsing.
      @request = SOAPRequest.new.init
      req_charset = @request.charset
      req_string = @request.dump
      log(SEV_DEBUG) { "XML Request: #{req_string}" }

      res_string, is_fault = route(req_string, req_charset)
      log(SEV_DEBUG) { "XML Response: #{res_string}" }

      @response = HTTP::Message.new_response(res_string)
      unless is_fault
	@response.status = 200
      else
	@response.status = 500
      end
      @response.header.set('Cache-Control', 'private')
      @response.body.type = @mediatype
      @response.body.charset = if req_charset
	  ::SOAP::Charset.charset_str(req_charset)
	else
	  nil
	end
      str = @response.dump
      log(SEV_DEBUG) { "SOAP CGI Response:\n#{ str }" }
      print str

      epilogue

    rescue Exception
      res_string = create_fault_response($!)
      @response = HTTP::Message.new_response(res_string)
      @response.header.set('Cache-Control', 'private')
      @response.body.type = @mediatype
      @response.body.charset = nil
      @response.status = 500
      str = @response.dump
      log(SEV_DEBUG) { "SOAP CGI Response:\n#{ str }" }
      print str

    end

    0
  end

  def prologue; end
  def epilogue; end
end


end
