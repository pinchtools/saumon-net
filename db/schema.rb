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

ActiveRecord::Schema[8.0].define(version: 2025_08_24_131832) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "downloads", force: :cascade do |t|
    t.string "fingerprint", null: false
    t.string "name", null: false
    t.boolean "current", default: false, null: false
    t.integer "version", default: 1, null: false
    t.bigint "source_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "dataset_code", null: false
    t.string "checksum"
    t.index ["fingerprint", "version"], name: "index_downloads_on_fingerprint_and_version", unique: true
    t.index ["fingerprint"], name: "index_downloads_on_fingerprint_where_current_true", unique: true, where: "(current = true)"
    t.index ["name"], name: "index_downloads_on_name"
    t.index ["source_id"], name: "index_downloads_on_source_id"
  end

  create_table "entities", force: :cascade do |t|
    t.string "uid", null: false
    t.string "type", null: false
    t.jsonb "metadata"
    t.bigint "download_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "extracted_file_id"
    t.index ["download_id"], name: "index_entities_on_download_id"
    t.index ["extracted_file_id"], name: "index_entities_on_extracted_file_id"
    t.index ["metadata"], name: "index_entities_on_metadata", using: :gin
    t.index ["type"], name: "index_entities_on_type"
    t.index ["uid"], name: "index_entities_on_uid", unique: true
  end

  create_table "extracted_files", force: :cascade do |t|
    t.string "path", null: false
    t.bigint "download_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["download_id"], name: "index_extracted_files_on_download_id"
    t.index ["path", "download_id"], name: "index_extracted_files_on_path_and_download_id", unique: true
  end

  create_table "sources", force: :cascade do |t|
    t.string "name", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_sources_on_code", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "entities", "extracted_files", on_delete: :cascade
end
