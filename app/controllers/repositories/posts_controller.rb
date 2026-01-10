module Repositories
  class PostsController < ApplicationController
    def index
      @repository = Repository.find(params[:repository_id])
      @posts = @repository.posts.published.page(params[:page]).per(20)
    end
  end
end
