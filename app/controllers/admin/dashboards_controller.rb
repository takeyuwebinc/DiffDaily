# frozen_string_literal: true

module Admin
  class DashboardsController < BaseController
    def show
      @repositories_count = Repository.count
      @posts_count = Post.count
    end
  end
end
