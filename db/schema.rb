# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_01_07_022128) do
  create_table "link_metadata", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "domain"
    t.string "favicon"
    t.string "image_url"
    t.datetime "last_fetched_at"
    t.text "title"
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["url"], name: "index_link_metadata_on_url", unique: true
  end

  create_table "posts", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.string "generated_by"
    t.datetime "published_at"
    t.integer "repository_id", null: false
    t.integer "review_attempts", default: 0, null: false
    t.text "review_issues"
    t.string "review_status", default: "not_reviewed", null: false
    t.string "source_url"
    t.string "status", default: "draft", null: false
    t.text "summary"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["published_at"], name: "index_posts_on_published_at"
    t.index ["repository_id", "source_url"], name: "index_posts_on_repository_id_and_source_url", unique: true
    t.index ["repository_id"], name: "index_posts_on_repository_id"
    t.index ["review_status"], name: "index_posts_on_review_status"
    t.index ["source_url"], name: "index_posts_on_source_url"
    t.index ["status"], name: "index_posts_on_status"
  end

  create_table "repositories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["name"], name: "index_repositories_on_name", unique: true
  end

  add_foreign_key "posts", "repositories"
end
