FactoryBot.define do
  factory :entity do
    uid { Faker::Code.asin }
    type { Faker::Lorem.word }
    download
  end
end
