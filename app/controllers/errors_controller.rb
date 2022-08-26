class ErrorsController < ApplicationController
  def not_found
    render nothing: true, status: 404
  end

  def internal_server_error
    render nothing: true, status: 500
  end
end
