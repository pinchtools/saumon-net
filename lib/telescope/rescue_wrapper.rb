require "set"

module Telescope
  module RescueWrapper
    WRAPPED_METHODS_IVAR = :@_rescues_all_wrapped_methods

    def self.prepended(base)
      base.singleton_class.prepend ClassMethods
      wrap_existing_methods(base)
    end

    def self.wrap_existing_methods(base)
      base.instance_methods(false).each do |m|
        wrap_method(base, m)
      end
    end

    def self.wrap_method(base, name)
      return if name.to_s.start_with?("report_")

      unless base.instance_variable_defined?(WRAPPED_METHODS_IVAR)
        base.instance_variable_set(WRAPPED_METHODS_IVAR, Set.new)
      end
      wrapped = base.instance_variable_get(WRAPPED_METHODS_IVAR)

      return if wrapped.include?(name)

      original = base.instance_method(name)
      base.define_method(name) do |*args, **kwargs, &block|
        begin
          original.bind_call(self, *args, **kwargs, &block)
        rescue => e
          if respond_to?(:rescue_with_handler, true)
            handled = rescue_with_handler(e)
            raise e unless handled
          else
            raise e
          end
        end
      end

      wrapped << name
    end

    module ClassMethods
      def method_added(name)
        return if @_adding_rescue
        @_adding_rescue = true
        Telescope::RescueWrapper.wrap_method(self, name)
        @_adding_rescue = false
      end
    end
  end
end
