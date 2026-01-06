class PostsController < ApplicationController
  def index
    @posts = Post.published.page(params[:page]).per(20)
  end

  def show
    @post = Post.find(params[:id])
  end
end
