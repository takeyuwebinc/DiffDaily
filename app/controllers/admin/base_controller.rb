# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    layout "admin"

    before_action :authenticate!

    helper_method :current_admin_user, :admin_signed_in?

    private

    def authenticate!
      return if admin_signed_in?

      store_location
      redirect_to admin_login_path, alert: "ログインしてください"
    end

    def current_admin_user
      return @current_admin_user if defined?(@current_admin_user)

      @current_admin_user = session[:admin_user]
    end

    def admin_signed_in?
      current_admin_user.present?
    end

    def store_location
      session[:admin_return_to] = request.fullpath if request.get?
    end

    def stored_location_for_admin
      session.delete(:admin_return_to)
    end
  end
end
