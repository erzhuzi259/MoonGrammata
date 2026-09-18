///|
pub(all) struct ScheduleConfig {
  base_energy : Int
  maximum_energy : Int
  novelty_bonus : Int
  discovery_bonus : Int
  failure_bonus : Int
  cost_penalty : Int
  selection_penalty : Int
} derive(Debug, Eq)

///|
pub fn ScheduleConfig::default() -> ScheduleConfig {
  {
    base_energy: 4,
    maximum_energy: 64,
    novelty_bonus: 16,
    discovery_bonus: 4,
    failure_bonus: 8,
    cost_penalty: 1,
    selection_penalty: 1,
  }
}

///|
pub(all) struct ScheduleDecision {
  entry_id : Int
  energy : Int
  reason : String
} derive(Debug, Eq)

///|
pub struct EnergyScheduler {
  config : ScheduleConfig
  random : Random
  mut rounds : Int
}

///|
pub fn EnergyScheduler::new(
  seed : Int64,
  config? : ScheduleConfig = ScheduleConfig::default(),
) -> EnergyScheduler {
  { config, random: Random::new(seed), rounds: 0 }
}

///|
fn rare_feature_score(corpus : Corpus, entry : CorpusEntry) -> Int {
  let mut score = 0
  for item in entry.observation.canonical_features() {
    let frequency = corpus.feature_frequency(item)
    if frequency <= 1 {
      score += 8
    } else if frequency <= 3 {
      score += 4
    } else if frequency <= 8 {
      score += 2
    } else if frequency <= 32 {
      score += 1
    }
  }
  score
}

///|
fn signature_score(corpus : Corpus, entry : CorpusEntry) -> Int {
  let frequency = corpus.signature_frequency(entry.signature)
  if frequency <= 1 {
    8
  } else if frequency <= 4 {
    4
  } else if frequency <= 16 {
    2
  } else {
    0
  }
}

///|
pub fn EnergyScheduler::energy_for(
  self : EnergyScheduler,
  corpus : Corpus,
  entry : CorpusEntry,
) -> Int {
  let mut energy = self.config.base_energy
  energy += rare_feature_score(corpus, entry)
  energy += signature_score(corpus, entry)
  if entry.executions == 0 {
    energy += self.config.novelty_bonus
  }
  energy += entry.discoveries.min(16) * self.config.discovery_bonus
  if entry.is_failure() {
    energy += self.config.failure_bonus
  }
  energy -= entry.observation.cost_class * self.config.cost_penalty
  energy -= entry.selections / 4 * self.config.selection_penalty
  energy.max(1).min(self.config.maximum_energy.max(1))
}

///|
pub fn EnergyScheduler::refresh(
  self : EnergyScheduler,
  corpus : Corpus,
) -> Array[Int] {
  let energies : Array[Int] = []
  for entry in corpus.entries() {
    let energy = self.energy_for(corpus, entry)
    entry.set_energy(energy)
    energies.push(energy)
  }
  energies
}

///|
fn decision_reason(entry : CorpusEntry, energy : Int) -> String {
  let category = if entry.is_failure() {
    "failure"
  } else if entry.executions == 0 {
    "unexplored"
  } else if entry.discoveries > 0 {
    "productive"
  } else {
    "scheduled"
  }
  category + " energy=" + energy.to_string()
}

///|
pub fn EnergyScheduler::select(
  self : EnergyScheduler,
  corpus : Corpus,
) -> ScheduleDecision? {
  if corpus.is_empty() {
    return None
  }
  let energies = self.refresh(corpus)
  let selected = self.random.weighted_index(energies).unwrap()
  let entry = corpus.entry(selected).unwrap()
  entry.record_selection()
  self.rounds += 1
  Some({
    entry_id: entry.id,
    energy: energies[selected],
    reason: decision_reason(entry, energies[selected]),
  })
}

///|
pub fn EnergyScheduler::rounds(self : EnergyScheduler) -> Int {
  self.rounds
}

///|
pub fn EnergyScheduler::seed(self : EnergyScheduler) -> Int64 {
  self.random.seed()
}

///|
pub fn EnergyScheduler::rank(
  self : EnergyScheduler,
  corpus : Corpus,
) -> Array[ScheduleDecision] {
  let result : Array[ScheduleDecision] = []
  let energies = self.refresh(corpus)
  for entry in corpus.entries() {
    result.push({
      entry_id: entry.id,
      energy: energies[entry.id],
      reason: decision_reason(entry, energies[entry.id]),
    })
  }
  let ordered : Array[ScheduleDecision] = []
  for item in result {
    let mut inserted = false
    for index = 0; index < ordered.length(); index = index + 1 {
      if item.energy > ordered[index].energy ||
        (item.energy == ordered[index].energy && item.entry_id < ordered[index].entry_id) {
        ordered.insert(index, item)
        inserted = true
        break
      }
    }
    if !inserted { ordered.push(item) }
  }
  ordered
}

