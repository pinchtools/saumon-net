FactoryBot.define do
  factory :source do
    name { Faker::Dessert.variety }
    code { Faker::Code.asin }
  end
end
