# frozen_string_literal: true

wrapping_proc = proc do |relationship|
  ActiveGraph::RelWrapping.wrapper(relationship)
end
Neo4j::Driver::Types::Relationship.wrapper_callback(wrapping_proc)

module ActiveGraph
  module RelWrapping
    class << self
      def wrapper(rel)
        rel.properties.symbolize_keys!
        begin
          most_concrete_class = class_from_type(rel.type).constantize
          return rel unless most_concrete_class < ActiveGraph::Relationship
          most_concrete_class.new
        rescue NameError => e
          raise e unless e.message =~ /(uninitialized|wrong) constant/

          return rel
        end.tap do |wrapped_rel|
          wrapped_rel.init_on_load(rel, rel.start_node_id, rel.end_node_id, rel.type)
        end
      end

      def class_from_type(type)
        ActiveGraph::Relationship::Types::WRAPPED_CLASSES[type] || ActiveGraph::Relationship::Types::WRAPPED_CLASSES[type] = type.to_s.downcase.camelize
      end
    end
  end
end
