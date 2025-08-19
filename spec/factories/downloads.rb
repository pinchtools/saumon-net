FactoryBot.define do
  factory :download do
    name { Faker::Internet.slug }
    fingerprint { Faker::Code.asin }
    dataset_code { Faker::Code.asin }
    checksum { "Aaaz" }
    current { false }
    version { 1 }
    source
  end
end
