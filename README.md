# sat

This [Crystal](https://crystal-lang.org/) module consists of the set of classes 
to modeling selected combinatorial optimization problems by means of 
[SAT](https://en.wikipedia.org/wiki/Boolean_satisfiability_problem) encoding.
We use [MiniSat](http://minisat.se/Main.html) sat-solver in the background, but
executable binary files do not need any additional library/files.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     sat:
       github: w-wieczorek/sat
       branch: master
   ```

2. Run `shards install`

3. (Optional) In `src` sub-directory of the library there is a file `solver.o`
   which was obtained by compiling:

   ```
   gcc -c solver.c -o solver.o
   ```

   the MiniSat source code given in `MiniSat-C_v1.14.1` directory. We have added
   to it one simple function `solver_nvalue` to simplify reading result from
   a solver.

## Usage

```crystal
require "sat"
```

Let us solve as an example the graph kernel problem. For a given directed graph G = (V, E), 
find an [independent set](https://en.wikipedia.org/wiki/Independent_set_(graph_theory))
of vertices, U, such that if v is in V - U then there is at least one u in U for which 
(v, u) is in E.

```crystal
require "sat"
include Sat

graph = { vertices: Set{0, 1, 2, 3, 4, 5, 6, 7}, 
  edges: Set{ {0, 1}, {0, 2}, {1, 2}, {2, 6}, {3, 1}, {3, 2}, {4, 0}, {4, 5} } }
prog = Program.new
taken = LiteralFactory.new graph[:vertices]
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
if prog.status == :satisfiable
  answer = Set(Int32).new
  graph[:vertices].each do |v|
    answer.add v if prog.value(taken[v]) == 1
  end
  puts "A kernel is: #{answer}."
else
  puts "There is no kernel set."
end
```

Generally, there are five types of constraints. Suppose that we have three
binary variables: `x[1]`, `x[2]`, and `x[3]` (i.e., six literals `x[1]`, `x[2]`, `x[3]`,
`~x[1]`, `~x[2]`, and `~x[3]`), which can be declare in a program by

```crystal
x = LiteralFactory.new (1..3)
```

* A fact `p.addFact x[1]` which means `x[1]`.

* A clause `p.addClause x[1], ~x[2], x[3]` which means `x[1]` or `~x[2]` or `x[3]`.

* A constraint `p.addConstraint ~x[1], x[2], x[3]` which means `x[1]` or `~x[2]` or `~x[3]`.

* A simple rule `p.addRule x[1], ~[x2], implies: ~x[3]` which means `~x[1]` or `x[2]` or `~x[3]`.

* A one-of rule `p.ensureOneOf x[1], x[2], x[3]` which means that exactly one of given
  variables have to be **true** (the rest have to be **false**).

For more examples please see `spec` directory.

## Contributing

1. Fork it (<https://github.com/your-github-user/sat/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Wojciech Wieczorek](https://github.com/w-wieczorek) - creator and maintainer
