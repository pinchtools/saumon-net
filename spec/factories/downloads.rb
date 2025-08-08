FactoryBot.define do
  factory :download do
    name { Faker::Internet.slug }
    fingerprint { Faker::Code.asin }
    current { true }
    version { 1 }
    source
  end
end
