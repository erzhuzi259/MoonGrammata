///|
test "random stream is deterministic and seed zero is usable" {
  let left = Random::new(0L)
  let right = Random::new(0L)
  let a : Array[Int] = []
  let b : Array[Int] = []
  for index = 0; index < 64; index = index + 1 {
    a.push(left.next_raw())
    b.push(right.next_raw())
  }
  assert_eq(a, b)
  assert_eq(left.draw_count(), 64)
}

///|
test "bounded and weighted choices respect their contracts" {
  let random = Random::new(77L)
  for index = 0; index < 1000; index = index + 1 {
    let value = random.between(-4, 9)
    assert_true(value >= -4 && value <= 9)
  }
  assert_eq(random.weighted_index([0, 0, 5, 0]), Some(2))
  assert_eq(random.weighted_index([0, 0]), None)
  assert_eq(random.choose_index(0), None)
}

///|
test "snapshots resume the exact stream" {
  let random = Random::new(20260918L)
  random.advance(19)
  let snapshot = random.snapshot()
  let expected = random.next_raw()
  let restored = Random::restore(snapshot)
  assert_eq(restored.next_raw(), expected)
  assert_eq(restored.draw_count(), 20)
}

///|
test "sample without replacement is unique and bounded" {
  let random = Random::new(8L)
  let sample = random.sample_without_replacement(20, 12)
  assert_eq(sample.length(), 12)
  let seen : @hashmap.HashMap[Int, Unit] = @hashmap.HashMap([])
  for value in sample {
    assert_true(value >= 0 && value < 20)
    assert_false(seen.contains(value))
    seen.set(value, ())
  }
}
