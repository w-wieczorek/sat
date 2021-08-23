@[Link(ldflags: "#{__DIR__}/solver.o")]

lib LibMinisat
  fun solver_new() : UInt64
  fun solver_delete(s : UInt64) : Void
  fun solver_addclause(s : UInt64, start : Int32*, finish : Int32*) : Int32
  fun solver_solve(s : UInt64, start : Int32*, finish : Int32*) : Int32
  fun solver_nvalue(s : UInt64, n : Int32) : Int32
end

module Sat
  alias Var = Int32
  
  struct Literal
    property var : Var
    property negated : Bool

    def initialize(@var, @negated)
    end

    def ~
      Literal.new(@var, @negated ? false : true)
    end

    def to_integer
      @negated ? (@var + @var) ^ 1 : @var + @var 
    end
  end

  class LiteralFactory
    @@indices = Hash({UInt64, String}, Int32).new
    @@num_of_vars = 0

    def initialize(range)
      u = self.object_id
      range.each do |idx|
        @@indices[{u, idx.to_s}] = @@num_of_vars
        @@num_of_vars += 1
      end
    end

    def [](idx : Object) : Literal
      u = self.object_id
      s = idx.to_s
      i = @@indices[{u, s}]
      Literal.new(i, false)
    end

    def [](*ids) : Literal
      u = self.object_id
      s = ids.to_s
      i = @@indices[{u, s}]
      Literal.new(i, false)
    end

    def self.reset
      @@indices.clear
      @@num_of_vars = 0
    end

    def self.indices
      @@indices
    end

    def self.num_of_vars
      @@num_of_vars
    end
  end

  class Program
    getter status, clauses, values

    def initialize
      @clauses = [] of Array(Literal)
      @values = [] of Int32
      @status = :unknown
    end

    def addFact(head)
      @clauses << [head]
    end

    def addClause(*body)
      @clauses << body.to_a
    end

    def addClauseFromArray(body)
      @clauses << body
    end

    private def _addConstraint(body)
      addClauseFromArray(body.to_a.map &.~)
    end

    def addConstraint(*body)
      _addConstraint(body)
    end

    def addConstraintFromArray(body)
      addClauseFromArray(body.map &.~)
    end

    private def _addRule(body, head)
      addClauseFromArray(body.to_a.map &.~ << head)
    end

    def addRule(*body, implies head)
      _addRule(body, head)
    end

    def addRuleFromArray(body, implies head)
      addClauseFromArray(body.map &.~ << head)
    end

    def ensureOneOf(*body)
      addClauseFromArray(body.to_a)
      body.each_combination(2) { |pair| addConstraintFromArray pair }
    end

    def ensureOneFromArray(body)
      addClauseFromArray(body)
      body.each_combination(2) { |pair| addConstraintFromArray pair }
    end

    def solve
      saddr = LibMinisat.solver_new
      n = LiteralFactory.num_of_vars
      @values.clear
      @clauses.each do |c|
        clause = c.map &.to_integer
        begin_ptr = clause.to_unsafe
        end_ptr = begin_ptr + c.size
        LibMinisat.solver_addclause(saddr, begin_ptr, end_ptr)
      end
      res = LibMinisat.solver_solve(saddr, nil, nil)
      if res == 1
        (0...n).each { |i| @values << LibMinisat.solver_nvalue(saddr, i) }
        @status = :satisfiable
      else
        @status = :unsatisfiable
      end
      LibMinisat.solver_delete(saddr)
    end

    def value(lit)
      raise "Do not read when status is not satisfiable!" unless @status == :satisfiable
      raise "Unexpected (#{lit.var}, too big) variable index!" if lit.var >= @values.size
      @values[lit.var]
    end
  end 
end
