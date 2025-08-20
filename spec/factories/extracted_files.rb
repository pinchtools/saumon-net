FactoryBot.define do
  factory :extracted_file do
    download
    path { Faker::File.file_name(dir: Faker::File.dir) }
  end
end
