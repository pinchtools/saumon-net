RSpec.shared_context "with memoization cleanup" do
  after do
    if described_class.respond_to?(:instance_variables)
      described_class.instance_variables.each do |var|
        described_class.remove_instance_variable(var) if described_class.instance_variable_defined?(var)
      end
    end
  end
end

RSpec.configure do |config|
  config.include_context "with memoization cleanup", :memoization_cleanup
end
