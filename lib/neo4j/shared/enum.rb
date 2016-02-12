module Neo4j::Shared
  module Enum
    extend ActiveSupport::Concern

    class ConflictingEnumMethodError < Neo4j::Error; end

    module ClassMethods
      attr_reader :neo4j_enum_data

      def enum(parameters = {})
        options, parameters = *split_options_and_parameters(parameters)
        parameters.each do |property_name, enum_keys|
          enum_keys = normalize_key_list enum_keys
          @neo4j_enum_data ||= {}
          @neo4j_enum_data[property_name] = enum_keys
          define_property(property_name, enum_keys, options)
          define_enum_methods(property_name, enum_keys, options)
        end
      end

      def method_missing(name, *args, &block)
        singular_name = name.to_s.singularize.to_sym
        if args.empty? && !block && @neo4j_enum_data[singular_name]
          @neo4j_enum_data[singular_name]
        else
          super
        end
      end

      protected

      def normalize_key_list(enum_keys)
        case enum_keys
        when Hash
          enum_keys
        when Array
          Hash[enum_keys.each_with_index.to_a]
        else
          fail ArgumentError, 'Invalid parameter for enum. Please provide an Array or an Hash.'
        end
      end

      VALID_OPTIONS_FOR_ENUMS = [:_index, :_prefix, :_suffix]
      DEFAULT_OPTIONS_FOR_ENUMS = {
        _index: true
      }

      def split_options_and_parameters(parameters)
        options = DEFAULT_OPTIONS_FOR_ENUMS.clone
        new_parameters = {}
        parameters.each do |k, v|
          if VALID_OPTIONS_FOR_ENUMS.include? k
            options[k] = v
          else
            new_parameters[k] = v
          end
        end
        [options, new_parameters]
      end

      def define_property(property_name, enum_keys, options)
        property_options = build_property_options(enum_keys, options)
        property property_name, property_options
      end

      def build_property_options(enum_keys, _options = {})
        {
          serializer: Neo4j::Shared::TypeConverters::EnumConverter.new(enum_keys),
          default: enum_keys.keys.first
        }
      end

      def define_enum_methods(property_name, enum_keys, options)
        define_enum_methods_?(property_name, enum_keys, options)
        define_enum_methods_!(property_name, enum_keys, options)
      end

      def define_enum_methods_?(property_name, enum_keys, options)
        enum_keys.keys.each do |enum_value|
          method_name = build_method_name(enum_value, property_name, options)
          check_enum_method_conflicts! property_name, :"#{method_name}?"
          define_method("#{method_name}?") do
            __send__(property_name).to_s.to_sym == enum_value
          end
        end
      end

      def define_enum_methods_!(property_name, enum_keys, options)
        enum_keys.keys.each do |enum_value|
          method_name = build_method_name(enum_value, property_name, options)
          check_enum_method_conflicts! property_name, :"#{method_name}!"
          define_method("#{method_name}!") do
            __send__("#{property_name}=", enum_value)
          end
        end
      end

      def build_method_name(base_name, property_name, options)
        method_name = base_name
        method_name = "#{method_name}_#{property_name}" if options[:_suffix]
        method_name = "#{options[:_prefix]}_#{method_name}" if options[:_prefix]
        method_name
      end

      def check_enum_method_conflicts!(property_name, method_name)
        fail ConflictingEnumMethodError,
             "The enum `#{property_name}` is trying to define a `#{method_name}` method, "\
             'that is already defined. Try to use options `:prefix` or `:suffix` '\
             'to avoid conflicts.' if instance_methods(false).include?(method_name)
      end
    end
  end
end
