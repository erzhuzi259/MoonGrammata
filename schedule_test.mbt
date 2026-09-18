///|
test "scheduler prefers unseen and rare-feature entries" {
  let corpus = Corpus::new()
  ignore(
    corpus.consider(
      literal_tree("a", 0),
      accepted(features=[feature("common", "x")]),
      Seeded(1L),
    ),
  )
  let second = accepted(features=[feature("rare", "y")])
  ignore(corpus.consider(literal_tree("b", 1), second, Generated(2L)))
  corpus.entry(0).unwrap().record_execution()
  let scheduler = EnergyScheduler::new(5L)
  let ranking = scheduler.rank(corpus)
  assert_eq(ranking.length(), 2)
  assert_eq(ranking[0].entry_id, 1)
  assert_true(ranking[0].energy > ranking[1].energy)
}

///|
test "scheduler selections are deterministic for a seed" {
  fn populated() -> Corpus {
    let corpus = Corpus::new()
    ignore(corpus.consider(literal_tree("a", 0), accepted(), Seeded(1L)))
    ignore(
      corpus.consider(
        literal_tree("b", 1),
        accepted(features=[feature("path", "b")]),
        Generated(2L),
      ),
    )
    corpus
  }
  let left_corpus = populated()
  let right_corpus = populated()
  let left = EnergyScheduler::new(99L)
  let right = EnergyScheduler::new(99L)
  let ids_left : Array[Int] = []
  let ids_right : Array[Int] = []
  for index = 0; index < 50; index = index + 1 {
    ids_left.push(left.select(left_corpus).unwrap().entry_id)
    ids_right.push(right.select(right_corpus).unwrap().entry_id)
  }
  assert_eq(ids_left, ids_right)
  assert_eq(left.rounds(), 50)
}

///|
test "scheduler handles empty corpus" {
  let scheduler = EnergyScheduler::new(1L)
  assert_eq(scheduler.select(Corpus::new()), None)
}
