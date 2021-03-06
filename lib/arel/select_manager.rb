module Arel
  class SelectManager < Arel::TreeManager
    include Arel::Crud

    def initialize engine, table = nil
      super(engine)
      @ast   = Nodes::SelectStatement.new
      @ctx    = @ast.cores.last
      from table
    end

    def taken
      @ast.limit
    end

    def constraints
      @ctx.wheres
    end

    def skip amount
      @ast.offset = Nodes::Offset.new(amount)
      self
    end

    ###
    # Produces an Arel::Nodes::Exists node
    def exists
      Arel::Nodes::Exists.new @ast
    end

    def where_clauses
      #warn "where_clauses is deprecated" if $VERBOSE
      to_sql = Visitors::ToSql.new @engine
      @ctx.wheres.map { |c| to_sql.accept c }
    end

    def lock locking = true
      # FIXME: do we even need to store this?  If locking is +false+ shouldn't
      # we just remove the node from the AST?
      @ast.lock = Nodes::Lock.new
      self
    end

    def locked
      @ast.lock
    end

    def on *exprs
      @ctx.source.right.last.right = Nodes::On.new(collapse(exprs))
      self
    end

    def group *columns
      columns.each do |column|
        # FIXME: backwards compat
        column = Nodes::SqlLiteral.new(column) if String === column
        column = Nodes::SqlLiteral.new(column.to_s) if Symbol === column

        @ctx.groups.push Nodes::Group.new column
      end
      self
    end

    def from table
      table = Nodes::SqlLiteral.new(table) if String === table
      # FIXME: this is a hack to support
      # test_with_two_tables_in_from_without_getting_double_quoted
      # from the AR tests.

      case table
      when Nodes::SqlLiteral, Arel::Table
        @ctx.source.left = table
      when Nodes::Join
        @ctx.source.right << table
      end

      self
    end

    def with aliaz, manager
      aliaz = Nodes::SqlLiteral.new(aliaz) if String === aliaz
      @ctx.withs << Nodes::With.new(aliaz, manager)
    end

    def froms
      @ast.cores.map { |x| x.from }.compact
    end

    def join relation, klass = Nodes::InnerJoin
      return self unless relation

      case relation
      when String, Nodes::SqlLiteral
        raise if relation.blank?
        klass = Nodes::StringJoin
      end

      @ctx.source.right << create_join(relation, nil, klass)
      self
    end

    def having expr
      expr = Nodes::SqlLiteral.new(expr) if String === expr

      @ctx.having = Nodes::Having.new(expr)
      self
    end

    def project *projections
      # FIXME: converting these to SQLLiterals is probably not good, but
      # rails tests require it.
      @ctx.projections.concat projections.map { |x|
        [Symbol, String].include?(x.class) ? SqlLiteral.new(x.to_s) : x
      }
      self
    end

    def order *expr
      # FIXME: We SHOULD NOT be converting these to SqlLiteral automatically
      @ast.orders.concat expr.map { |x|
        String === x || Symbol === x ? Nodes::SqlLiteral.new(x.to_s) : x
      }
      self
    end

    def orders
      @ast.orders
    end

    def wheres
      Compatibility::Wheres.new @engine, @ctx.wheres
    end

    def where_sql
      return if @ctx.wheres.empty?

      viz = Visitors::WhereSql.new @engine
      Nodes::SqlLiteral.new viz.accept @ctx
    end

    def take limit
      @ast.limit = limit
      self
    end

    def join_sql
      return nil if @ctx.source.right.empty?

      sql = @visitor.dup.extend(Visitors::JoinSql).accept @ctx
      Nodes::SqlLiteral.new sql
    end

    def order_clauses
      Visitors::OrderClauses.new(@engine).accept(@ast).map { |x|
        Nodes::SqlLiteral.new x
      }
    end

    def join_sources
      @ctx.source.right
    end

    def joins manager
      if $VERBOSE
        warn "joins is deprecated and will be removed in 3.0.0"
        warn "please remove your call to joins from #{caller.first}"
      end
      manager.join_sql
    end

    class Row < Struct.new(:data) # :nodoc:
      def id
        data['id']
      end

      def method_missing(name, *args)
        name = name.to_s
        return data[name] if data.key?(name)
        super
      end
    end

    def to_a # :nodoc:
      warn "to_a is deprecated. Please remove it from #{caller[0]}"
      # FIXME: I think `select` should be made public...
      @engine.connection.send(:select, to_sql, 'AREL').map { |x| Row.new(x) }
    end

    # FIXME: this method should go away
    def insert values
      if $VERBOSE
        warn <<-eowarn
insert (#{caller.first}) is deprecated and will be removed in ARel 3.0.0. Please
switch to `compile_insert`
        eowarn
      end

      im = compile_insert(values)
      table = @ctx.froms

      primary_key      = table.primary_key
      primary_key_name = primary_key.name if primary_key

      # FIXME: in AR tests values sometimes were Array and not Hash therefore is_a?(Hash) check is added
      primary_key_value = primary_key && values.is_a?(Hash) && values[primary_key]
      im.into table
      # Oracle adapter needs primary key name to generate RETURNING ... INTO ... clause
      # for tables which assign primary key value using trigger.
      # RETURNING ... INTO ... clause will be added only if primary_key_value is nil
      # therefore it is necessary to pass primary key value as well
      @engine.connection.insert im.to_sql, 'AREL', primary_key_name, primary_key_value
    end

    private
    def collapse exprs
      return exprs.first if exprs.length == 1

      create_and exprs.compact.map { |expr|
        if String === expr
          Arel.sql(expr)
        else
          expr
        end
      }
    end
  end
end
