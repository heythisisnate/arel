module Arel
  module Visitors
    class DepthFirst < Arel::Visitors::Visitor
      def initialize block = nil
        @block = block || Proc.new
      end

      private

      def binary o
        visit o.left
        visit o.right
        @block.call o
      end
      alias :visit_Arel_Nodes_And                :binary
      alias :visit_Arel_Nodes_Assignment         :binary
      alias :visit_Arel_Nodes_Between            :binary
      alias :visit_Arel_Nodes_DoesNotMatch       :binary
      alias :visit_Arel_Nodes_Equality           :binary
      alias :visit_Arel_Nodes_GreaterThan        :binary
      alias :visit_Arel_Nodes_GreaterThanOrEqual :binary
      alias :visit_Arel_Nodes_In                 :binary
      alias :visit_Arel_Nodes_LessThan           :binary
      alias :visit_Arel_Nodes_LessThanOrEqual    :binary
      alias :visit_Arel_Nodes_Matches            :binary
      alias :visit_Arel_Nodes_NotEqual           :binary
      alias :visit_Arel_Nodes_NotIn              :binary
      alias :visit_Arel_Nodes_Or                 :binary

      def visit_Arel_Attribute o
        visit o.relation
        visit o.name
        @block.call o
      end
      alias :visit_Arel_Attributes_Integer :visit_Arel_Attribute
      alias :visit_Arel_Attributes_Float :visit_Arel_Attribute
      alias :visit_Arel_Attributes_String :visit_Arel_Attribute
      alias :visit_Arel_Attributes_Time :visit_Arel_Attribute
      alias :visit_Arel_Attributes_Boolean :visit_Arel_Attribute
      alias :visit_Arel_Attributes_Attribute :visit_Arel_Attribute

      def visit_Arel_Table o
        visit o.name
        @block.call o
      end

      def terminal o
        @block.call o
      end
      alias :visit_Arel_Nodes_SqlLiteral :terminal
      alias :visit_Arel_SqlLiteral       :terminal
      alias :visit_BigDecimal            :terminal
      alias :visit_Date                  :terminal
      alias :visit_DateTime              :terminal
      alias :visit_FalseClass            :terminal
      alias :visit_Fixnum                :terminal
      alias :visit_Float                 :terminal
      alias :visit_NilClass              :terminal
      alias :visit_String                :terminal
      alias :visit_Symbol                :terminal
      alias :visit_Time                  :terminal
      alias :visit_TrueClass             :terminal

      def visit_Arel_Nodes_SelectCore o
        visit o.projections
        visit o.froms
        visit o.wheres
        visit o.groups
        visit o.having
        @block.call o
      end

      def visit_Arel_Nodes_SelectStatement o
        visit o.cores
        visit o.orders
        visit o.limit
        visit o.lock
        visit o.offset
        @block.call o
      end

      def visit_Arel_Nodes_UpdateStatement o
        visit o.relation
        visit o.values
        visit o.wheres
        visit o.orders
        visit o.limit
        @block.call o
      end

      def visit_Array o
        o.each { |i| visit i }
        @block.call o
      end

      def visit_Hash o
        o.each { |k,v| visit(k); visit(v) }
        @block.call o
      end
    end
  end
end