# frozen_string_literal: true

module Admin
  class RepositoriesController < BaseController
    def index
      @repositories = Repository.includes(:posts).order(created_at: :desc)
    end

    def new
      @repository = Repository.new
    end

    def create
      @repository = Repository.new(repository_params)

      if @repository.save
        DailySummaryJob.perform_later(@repository.id)
        redirect_to admin_repositories_path, notice: "リポジトリを登録しました。初回の取り込みをキューに追加しました。"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      @repository = Repository.find(params[:id])
      @repository.destroy

      redirect_to admin_repositories_path, notice: "リポジトリを削除しました"
    end

    private

    def repository_params
      params.require(:repository).permit(:name, :url)
    end
  end
end
