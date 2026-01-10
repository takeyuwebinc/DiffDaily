module Repositories
  class PostsController < ApplicationController
    def index
      @repository = Repository.find(params[:repository_id])

      respond_to do |format|
        format.html do
          @posts = @repository.posts.published.page(params[:page]).per(20)
        end
        format.rss do
          @posts = @repository.posts.published.limit(50)
        end
      end
    end
  end
end
