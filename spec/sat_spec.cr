require "spec"
require "../src/sat.cr"

describe "Sat" do
  it "creates a rule and adds it to a logic program" do
    prog = Sat::Program.new
    p = Sat::LiteralFactory.new (0..3)
    prog.addRule p[1], ~p[2], ~p[3], implies: p[0]
    prog.clauses.size.should eq(1)
    prog.clauses.should contain([~p[1], p[2], p[3], p[0]])
  end

  it "adds facts and constraints to a logic program" do
    prog = Sat::Program.new
    idx_arr = (0..2).zip ["Ala", "Grażyna", "Adam"]
    Sat::LiteralFactory.reset
    person = Sat::LiteralFactory.new idx_arr
    prog.addFact person[0, "Ala"]
    prog.addConstraint person[1, "Grażyna"], ~person[2, "Adam"]
    Sat::LiteralFactory.indices.values.should eq([0, 1, 2])
    prog.clauses.size.should eq(2)
    c1 = [person[0, "Ala"]]
    prog.clauses.should contain(c1)
    c2 = [~person[1, "Grażyna"], person[2, "Adam"]]
    prog.clauses.should contain(c2)
  end

  it "determines the model of a simple program" do
    prog = Sat::Program.new
    Sat::LiteralFactory.reset
    q = Sat::LiteralFactory.new (1..6)
    prog.addFact q[1]
    prog.addFact q[6]
    prog.addRule q[1], implies: q[2]
    prog.addRule q[1], q[2], implies: q[3]
    prog.addRule q[6], implies: ~q[5]
    prog.solve
    prog.status.should eq(:satisfiable)
    prog.value(q[1]).should eq(1)
    prog.value(q[2]).should eq(1)
    prog.value(q[3]).should eq(1)
    prog.value(q[5]).should eq(0)
    prog.value(q[6]).should eq(1)
  end

  it "solves a combinatorial problem (Hamiltonian Path)" do
    prog = Sat::Program.new
    Sat::LiteralFactory.reset
    graph = { vertices: Set{0, 1, 2, 3}, edges: Set{ {0, 1}, {1, 2}, {2, 0}, {3, 1} } }
    idx = [] of Tuple(Int32, Int32)
    n = graph[:vertices].size
    (0...n).each do |i|
      graph[:vertices].each { |v| idx << {v, i} }
    end
    is_at = Sat::LiteralFactory.new idx
    graph[:vertices].each do |v|
      prog.ensureOneFromArray((0...n).map{ |i| is_at[v, i] })
    end
    (0...n).each do |i|
      prog.ensureOneFromArray(graph[:vertices].map{ |v| is_at[v, i] })
    end
    graph[:vertices].each do |u|
      graph[:vertices].each do |v|
        unless u == v || graph[:edges].includes?({u, v})
          (0..n-2).each do |j|
            prog.addConstraint is_at[u, j], is_at[v, j+1]
          end
        end
      end
    end
    prog.solve
    prog.status.should eq(:satisfiable)
    prog.value(is_at[3, 0]).should eq(1)
    prog.value(is_at[1, 1]).should eq(1)
    prog.value(is_at[2, 2]).should eq(1)
    prog.value(is_at[0, 3]).should eq(1)
    counter = 0
    idx.each do |v, i|
      counter += 1 if prog.value(is_at[v, i]) == 1
    end
    counter.should eq(4)
  end

  it "solves a combinatorial problem (Graph Coloring)" do
    prog = Sat::Program.new
    Sat::LiteralFactory.reset
    graph = { vertices: Set{0, 1, 2, 3, 4}, 
      edges: Set{ {0, 1}, {0, 3}, {0, 4}, {1, 2}, {2, 3}, {3, 4} } }
    cs = [:red, :green, :blue]
    pairs = [] of {Int32, Symbol}
    graph[:vertices].each { |v| cs.each { |c| pairs << {v, c} } }
    color = Sat::LiteralFactory.new pairs
    graph[:vertices].each do |v|
      prog.ensureOneFromArray(cs.map{ |c| color[v, c] })
    end
    graph[:edges].each do |v, u|
      cs.each { |c| prog.addConstraint color[v, c], color[u, c] }
    end
    prog.addFact color[0, :red]
    prog.addFact color[1, :blue]
    prog.addFact color[3, :green]
    prog.solve
    prog.status.should eq(:satisfiable)
    prog.value(color[2, :red]).should eq(1)
    prog.value(color[4, :blue]).should eq(1)
  end

  it "solves a combinatorial optimization problem (Minimum Vertex Cover)" do
    graph = { vertices: (0..7).to_set, 
      edges: Set{ {0, 1}, {0, 2}, {0, 3}, {0, 6}, {1, 2}, 
        {1, 3}, {1, 5}, {1, 7}, {2, 7}, {3, 6}, {4, 6}, {5, 7} } }
    prog = Sat::Program.new
    Sat::LiteralFactory.reset
    n = 4
    indexes = [] of Tuple(Int32, Int32)
    graph[:vertices].each { |v| (1..n).each { |i| indexes << {v, i} } }
    taken = Sat::LiteralFactory.new indexes
    (1..n).each do |i|
      prog.ensureOneFromArray(graph[:vertices].map{ |v| taken[v, i] })
    end
    graph[:edges].each do |u, v|
      clause = [] of Sat::Literal
      (1..n).each do |i|
        clause << taken[u, i]
        clause << taken[v, i]
      end
      prog.addClauseFromArray clause
    end
    prog.solve
    prog.status.should eq(:satisfiable)
    answer = Set(Int32).new
    indexes.each do |v, i|
      answer.add v if prog.value(taken[v, i]) == 1
    end
    answer.should eq(Set{0, 1, 6, 7})
  end

  it "solves a combinatorial problem (Clique)" do
    prog = Sat::Program.new
    Sat::LiteralFactory.reset
    graph = { vertices: (0..7).to_set, 
      edges: Set{ {0, 1}, {0, 2}, {0, 3}, {1, 2}, {1, 5}, 
        {1, 7}, {2, 5}, {2, 7}, {3, 4}, {3, 6}, {4, 6}, {5, 7} } }
    n = 5
    indexes = [] of Tuple(Int32, Int32)
    graph[:vertices].each { |v| (1..n).each { |i| indexes << {v, i} } }
    taken = Sat::LiteralFactory.new indexes
    (1..n).each do |i|
      prog.ensureOneFromArray(graph[:vertices].map{ |v| taken[v, i] })
    end
    graph[:vertices].each do |v|
      (1..n).each do |i| 
        (1..n).each do |j| 
          prog.addConstraint taken[v, i], taken[v, j] if i < j
        end
      end
    end
    graph[:vertices].each do |u|
      graph[:vertices].each do |v|
        unless u >= v || graph[:edges].includes?({u, v})
          (1..n).each do |i| 
            (1..n).each do |j| 
              prog.addConstraint taken[u, i], taken[v, j] if i != j
            end
          end
        end
      end
    end
    prog.solve
    prog.status.should eq(:unsatisfiable)
  end

  it "solves a combinatorial problem (Kernel)" do
    prog = Sat::Program.new
    Sat::LiteralFactory.reset
    graph = { vertices: Set{0, 1, 2, 3, 4, 5, 6, 7}, 
      edges: Set{ {0, 1}, {0, 2}, {1, 2}, {2, 6}, {3, 1}, {3, 2}, {4, 0}, {4, 5} } }
    taken = Sat::LiteralFactory.new graph[:vertices]
    graph[:vertices].each do |v|
      outdegree = 0
      graph[:edges].each { |u, w| outdegree += 1 if v == u }
      prog.addFact taken[v] if outdegree == 0
      if outdegree > 0
        arr = [~taken[v]]
        graph[:edges].each { |u, w| arr << ~taken[w] if v == u }
        prog.addConstraintFromArray arr
      end
    end
    graph[:edges].each do |u, v|
      prog.addConstraint taken[u], taken[v]
    end
    prog.solve
    prog.status.should eq(:satisfiable)
    answer = Set(Int32).new
    graph[:vertices].each do |v|
      answer.add v if prog.value(taken[v]) == 1
    end
    answer.should eq(Set{1, 5, 6, 7})
  end

  it "solves a set cover problem" do
    prog = Sat::Program.new
    Sat::LiteralFactory.reset
    n = 5  # universum = Set{1, 2, 3, 4, 5}
    k = 2  # find k subsets to cover universum
    family = [ Set{1, 2, 3}, Set{2, 4}, Set{3, 4}, Set{4, 5} ]
    indexes = [] of Tuple(Int32, Int32)
    m = family.size
    (0...m).each { |i| (1..k).each { |j| indexes << {i, j} } }
    x = Sat::LiteralFactory.new indexes
    (1..k).each do |j|
      prog.addClauseFromArray (0...m).map{ |i| x[i, j] }
      (0..m-2).each do |a|
        (a+1..m-1).each do |b|
          prog.addClause ~x[a, j], ~x[b, j]
        end
      end
    end
    (1..n).each do |u|
      arr = [] of Sat::Literal
      (0...m).each do |i|
        if family[i].includes? u
          (1..k).each { |j| arr << x[i, j] }
        end
      end
      prog.addClauseFromArray arr
    end
    prog.solve
    prog.status.should eq(:satisfiable)
    answer = Set(Int32).new
    (0...m).each do |i|
      (1..k).each do |j|
        answer.add i if prog.value(x[i, j]) == 1
      end
    end
    answer.should eq(Set{0, 3})
  end
end
