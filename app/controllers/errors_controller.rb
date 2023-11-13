# frozen_string_literal: true
class ErrorsController < ApplicationController
  def not_found
    render nothing: true, status: 404, formats: :html
  end

  def internal_server_error
    render nothing: true, status: 500, formats: :html
  end
end
