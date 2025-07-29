FactoryBot.define do
  factory :download do
    name { Faker::Internet.slug }
    fingerprint { Faker::Code.asin }
    checksum { "ASZ2" }
    current { true }
    version { 1 }
    source
  end
end
