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
end
