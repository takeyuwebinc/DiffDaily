# frozen_string_literal: true

module Admin
  class SessionsController < ApplicationController
    layout "admin"

    helper_method :current_admin_user, :admin_signed_in?

    def new
      redirect_to admin_root_path if session[:admin_user].present?
    end

    def destroy
      reset_session
      redirect_to root_path, notice: "ログアウトしました"
    end

    private

    def current_admin_user
      session[:admin_user]
    end

    def admin_signed_in?
      current_admin_user.present?
    end
  end
end
