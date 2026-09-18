///|
/// Stable pseudo-random generator used by every generative operation.
/// The Park-Miller recurrence is intentionally small and reproducible on all
/// MoonBit targets; it is not a cryptographic generator.
pub(all) struct Random {
  mut state : Int64
  initial_seed : Int64
  mut draws : Int
}

///|
fn normalize_seed(seed : Int64) -> Int64 {
  let reduced = seed % 2147483647L
  if reduced < 0L {
    -reduced
  } else if reduced == 0L {
    1L
  } else {
    reduced
  }
}

///|
pub fn Random::new(seed : Int64) -> Random {
  { state: normalize_seed(seed), initial_seed: seed, draws: 0, }
}

///|
pub fn Random::seed(self : Random) -> Int64 {
  self.initial_seed
}

///|
pub fn Random::draw_count(self : Random) -> Int {
  self.draws
}

///|
pub fn Random::next_raw(self : Random) -> Int {
  self.state = self.state * 48271L % 2147483647L
  self.draws += 1
  self.state.to_int()
}

///|
pub fn Random::below(self : Random, exclusive : Int) -> Int {
  if exclusive <= 0 {
    0
  } else {
    self.next_raw() % exclusive
  }
}

///|
pub fn Random::between(self : Random, minimum : Int, maximum : Int) -> Int {
  if maximum <= minimum {
    minimum
  } else {
    minimum + self.below(maximum - minimum + 1)
  }
}

///|
pub fn Random::chance(
  self : Random,
  numerator : Int,
  denominator : Int,
) -> Bool {
  if numerator <= 0 || denominator <= 0 {
    false
  } else if numerator >= denominator {
    true
  } else {
    self.below(denominator) < numerator
  }
}

///|
pub fn Random::choose_index(self : Random, length : Int) -> Int? {
  if length <= 0 {
    None
  } else {
    Some(self.below(length))
  }
}

///|
pub fn Random::weighted_index(self : Random, weights : Array[Int]) -> Int? {
  let mut total = 0
  for weight in weights {
    if weight > 0 {
      total += weight
    }
  }
  if total <= 0 {
    return None
  }
  let ticket = self.below(total)
  let mut cursor = 0
  for index, weight in weights {
    if weight > 0 {
      cursor += weight
      if ticket < cursor {
        return Some(index)
      }
    }
  }
  Some(weights.length() - 1)
}

///|
pub fn[T] Random::shuffle(self : Random, input : Array[T]) -> Array[T] {
  let result = input.copy()
  let mut index = result.length() - 1
  while index > 0 {
    let other = self.below(index + 1)
    let value = result[index]
    result[index] = result[other]
    result[other] = value
    index -= 1
  }
  result
}

///|
pub fn Random::sample_without_replacement(
  self : Random,
  population : Int,
  requested : Int,
) -> Array[Int] {
  if population <= 0 || requested <= 0 {
    return []
  }
  let values : Array[Int] = []
  for index = 0; index < population; index = index + 1 {
    values.push(index)
  }
  let shuffled = self.shuffle(values)
  let count = requested.min(population)
  let result : Array[Int] = []
  for index = 0; index < count; index = index + 1 {
    result.push(shuffled[index])
  }
  result
}

///|
pub fn Random::fork(self : Random, stream : Int) -> Random {
  let mixed = Int64::from_int(self.next_raw()) +
    Int64::from_int(stream) * 104729L +
    self.initial_seed * 8191L
  Random::new(mixed)
}

///|
pub fn Random::advance(self : Random, count : Int) -> Unit {
  for index = 0; index < count.max(0); index = index + 1 {
    ignore(self.next_raw())
  }
}

///|
pub fn Random::snapshot(self : Random) -> RandomSnapshot {
  { seed: self.initial_seed, state: self.state, draws: self.draws, }
}

///|
pub(all) struct RandomSnapshot {
  seed : Int64
  state : Int64
  draws : Int
} derive(Debug, Eq)

///|
pub fn Random::restore(snapshot : RandomSnapshot) -> Random {
  {
    state: normalize_seed(snapshot.state),
    initial_seed: snapshot.seed,
    draws: snapshot.draws.max(0),
  }
}

///|
pub fn deterministic_permutation(seed : Int64, size : Int) -> Array[Int] {
  let values : Array[Int] = []
  for index = 0; index < size.max(0); index = index + 1 {
    values.push(index)
  }
  Random::new(seed).shuffle(values)
}
