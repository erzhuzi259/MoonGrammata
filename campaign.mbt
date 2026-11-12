///|
#derive(Debug, Eq)
pub(all) struct CampaignConfig {
  seed : Int64
  executions : Int32
  initial_inputs : Int32
  crossover_percent : Int32
  generation_budget : GenerationBudget
  mutation_config : MutationConfig
  crossover_config : CrossoverConfig
  corpus_limits : CorpusLimits
  max_events : Int32
}

///|
pub fn CampaignConfig::default(seed~ : Int64 = 1L) -> CampaignConfig {
  {
    seed,
    executions: 10000,
    initial_inputs: 16,
    crossover_percent: 10,
    generation_budget: GenerationBudget::default(),
    mutation_config: MutationConfig::default(),
    crossover_config: CrossoverConfig::default(),
    corpus_limits: CorpusLimits::default(),
    max_events: 4096,
  }
}

///|
#derive(Debug, Eq)
pub(all) enum CampaignEventKind {
  Generated
  Mutated(MutationStrategy)
  Crossed
  Admitted(AdmissionReason)
  RejectedInput(RejectionReason)
  FailureFound(FailureFingerprint)
  MutationSkipped
}

///|
#derive(Debug, Eq)
pub(all) struct CampaignEvent {
  execution : Int32
  input_bytes : Int32
  corpus_entries : Int32
  kind : CampaignEventKind
}

///|
#derive(Debug, Eq)
pub(all) struct CampaignStatistics {
  requested_executions : Int32
  completed_executions : Int32
  generated_inputs : Int32
  mutated_inputs : Int32
  crossed_inputs : Int32
  admitted_inputs : Int32
  rejected_inputs : Int32
  unique_failures : Int32
  mutation_failures : Int32
  final_corpus : CorpusStatistics
}

///|
#derive(Debug, Eq)
pub(all) struct CampaignResult {
  statistics : CampaignStatistics
  corpus : Array[CorpusEntry]
  failures : Array[ReplayRecord]
  events : Array[CampaignEvent]
}

///|
#derive(Debug, Eq)
pub(all) enum CampaignError {
  InvalidCampaignConfig(String)
  InitialGenerationFailed(GenerationError)
  CorpusCouldNotBeSeeded
}

///|
fn CampaignConfig::validate(
  self : CampaignConfig,
) -> Result[Unit, CampaignError] {
  if self.executions <= 0 {
    Err(InvalidCampaignConfig("executions must be positive"))
  } else if self.initial_inputs <= 0 {
    Err(InvalidCampaignConfig("initial_inputs must be positive"))
  } else if self.crossover_percent < 0 || self.crossover_percent > 100 {
    Err(InvalidCampaignConfig("crossover_percent must be within 0..100"))
  } else if self.max_events < 0 {
    Err(InvalidCampaignConfig("max_events must not be negative"))
  } else {
    Ok(())
  }
}

///|
priv struct CampaignCounters {
  mut completed : Int32
  mut generated : Int32
  mut mutated : Int32
  mut crossed : Int32
  mut admitted : Int32
  mut rejected : Int32
  mut mutation_failures : Int32
}

///|
fn CampaignCounters::new() -> CampaignCounters {
  {
    completed: 0,
    generated: 0,
    mutated: 0,
    crossed: 0,
    admitted: 0,
    rejected: 0,
    mutation_failures: 0,
  }
}

///|
fn push_event(
  events : Array[CampaignEvent],
  maximum : Int32,
  event : CampaignEvent,
) -> Unit {
  if events.length() < maximum {
    events.push(event)
  }
}

///|
fn record_failure(
  failures : Array[ReplayRecord],
  seen : @hashmap.HashMap[FailureFingerprint, Unit],
  maximum : Int32,
  target : Target,
  input : Bytes,
  observation : TargetObservation,
  seed : Int64,
  budget : GenerationBudget,
) -> FailureFingerprint? {
  match observation.failure_fingerprint() {
    None => None
    Some(fingerprint) =>
      if !seen.contains(fingerprint) && failures.length() < maximum {
        seen.set(fingerprint, ())
        failures.push(
          ReplayRecord::new(
            target_name=target.name(),
            seed~,
            input~,
            observation~,
            generation_budget=budget,
          ),
        )
        Some(fingerprint)
      } else {
        None
      }
  }
}

///|
fn execute_candidate(
  corpus : Corpus,
  target : Target,
  tree : DerivationTree,
  origin : CorpusOrigin,
  seed : Int64,
  budget : GenerationBudget,
  counters : CampaignCounters,
  failures : Array[ReplayRecord],
  seen_failures : @hashmap.HashMap[FailureFingerprint, Unit],
  events : Array[CampaignEvent],
  max_events : Int32,
) -> AdmissionDecision {
  let input = tree.render()
  let observation = target.run(input)
  counters.completed += 1
  let new_failure = record_failure(
    failures,
    seen_failures,
    corpus.limits.max_failures,
    target,
    input,
    observation,
    seed,
    budget,
  )
  match new_failure {
    None => ()
    Some(fingerprint) =>
      push_event(events, max_events, {
        execution: counters.completed,
        input_bytes: input.length(),
        corpus_entries: corpus.length(),
        kind: FailureFound(fingerprint),
      })
  }
  let decision = corpus.consider(tree, observation, origin)
  match decision {
    Admitted(_, reason) => {
      counters.admitted += 1
      push_event(events, max_events, {
        execution: counters.completed,
        input_bytes: input.length(),
        corpus_entries: corpus.length(),
        kind: Admitted(reason),
      })
    }
    Rejected(reason) => {
      counters.rejected += 1
      push_event(events, max_events, {
        execution: counters.completed,
        input_bytes: input.length(),
        corpus_entries: corpus.length(),
        kind: RejectedInput(reason),
      })
    }
  }
  decision
}

///|
fn campaign_seed(config : CampaignConfig, ordinal : Int32) -> Int64 {
  config.seed + Int64::from_int(ordinal) * 104729L
}

///|
fn generated_candidate(
  grammar : Grammar,
  config : CampaignConfig,
  ordinal : Int32,
) -> Result[DerivationTree, GenerationError] {
  grammar.generate(
    seed=campaign_seed(config, ordinal),
    budget=config.generation_budget,
  )
}

///|
fn evolved_candidate(
  grammar : Grammar,
  corpus : Corpus,
  scheduler : EnergyScheduler,
  random : Random,
  config : CampaignConfig,
  ordinal : Int32,
  counters : CampaignCounters,
) -> (DerivationTree, CorpusOrigin, CampaignEventKind, CorpusEntry?)? {
  let decision = match scheduler.select(corpus) {
    None => return None
    Some(value) => value
  }
  let parent = corpus.entry(decision.entry_id).unwrap()
  parent.record_execution()
  let seed = campaign_seed(config, ordinal)
  if corpus.length() > 1 && random.chance(config.crossover_percent, 100) {
    let mut donor_id = random.below(corpus.length() - 1)
    if donor_id >= parent.id {
      donor_id += 1
    }
    let donor = corpus.entry(donor_id).unwrap()
    match
      crossover(parent.tree, donor.tree, seed~, config=config.crossover_config) {
      Ok(result) => {
        counters.crossed += 1
        return Some(
          (result.tree, Crossed(parent.id, donor.id), Crossed, Some(parent)),
        )
      }
      Err(_) => ()
    }
  }
  match grammar.mutate(parent.tree, seed~, config=config.mutation_config) {
    Ok(result) => {
      counters.mutated += 1
      Some(
        (
          result.tree,
          Mutated(parent.id, result.detail),
          Mutated(result.strategy),
          Some(parent),
        ),
      )
    }
    Err(_) => {
      counters.mutation_failures += 1
      match generated_candidate(grammar, config, ordinal) {
        Err(_) => None
        Ok(tree) => {
          counters.generated += 1
          Some((tree, Generated(seed), MutationSkipped, Some(parent)))
        }
      }
    }
  }
}

///|
pub fn run_campaign(
  grammar : Grammar,
  target : Target,
  config : CampaignConfig,
) -> Result[CampaignResult, CampaignError] {
  match config.validate() {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let corpus = Corpus::new(limits=config.corpus_limits)
  let counters = CampaignCounters::new()
  let failures : Array[ReplayRecord] = []
  let seen_failures : @hashmap.HashMap[FailureFingerprint, Unit] = @hashmap.HashMap([],
  )
  let events : Array[CampaignEvent] = []
  let initial_count = config.initial_inputs.min(config.executions)
  for ordinal = 0; ordinal < initial_count; ordinal = ordinal + 1 {
    let seed = campaign_seed(config, ordinal)
    let tree = match generated_candidate(grammar, config, ordinal) {
      Err(error) => return Err(InitialGenerationFailed(error))
      Ok(value) => value
    }
    counters.generated += 1
    push_event(events, config.max_events, {
      execution: counters.completed + 1,
      input_bytes: tree.byte_length(),
      corpus_entries: corpus.length(),
      kind: Generated,
    })
    ignore(
      execute_candidate(
        corpus,
        target,
        tree,
        Generated(seed),
        seed,
        config.generation_budget,
        counters,
        failures,
        seen_failures,
        events,
        config.max_events,
      ),
    )
  }
  if corpus.is_empty() {
    return Err(CorpusCouldNotBeSeeded)
  }
  let scheduler = EnergyScheduler::new(config.seed + 17L)
  let random = Random::new(config.seed + 31L)
  let mut ordinal = initial_count
  while counters.completed < config.executions {
    match
      evolved_candidate(
        grammar, corpus, scheduler, random, config, ordinal, counters,
      ) {
      None => {
        counters.mutation_failures += 1
        let tree = match generated_candidate(grammar, config, ordinal) {
          Err(error) => return Err(InitialGenerationFailed(error))
          Ok(value) => value
        }
        counters.generated += 1
        ignore(
          execute_candidate(
            corpus,
            target,
            tree,
            Generated(campaign_seed(config, ordinal)),
            campaign_seed(config, ordinal),
            config.generation_budget,
            counters,
            failures,
            seen_failures,
            events,
            config.max_events,
          ),
        )
      }
      Some((tree, origin, event_kind, parent)) => {
        push_event(events, config.max_events, {
          execution: counters.completed + 1,
          input_bytes: tree.byte_length(),
          corpus_entries: corpus.length(),
          kind: event_kind,
        })
        let decision = execute_candidate(
          corpus,
          target,
          tree,
          origin,
          campaign_seed(config, ordinal),
          config.generation_budget,
          counters,
          failures,
          seen_failures,
          events,
          config.max_events,
        )
        match (decision, parent) {
          (Admitted(_, _), Some(value)) => value.record_discovery()
          _ => ()
        }
      }
    }
    ordinal += 1
  }
  let statistics : CampaignStatistics = {
    requested_executions: config.executions,
    completed_executions: counters.completed,
    generated_inputs: counters.generated,
    mutated_inputs: counters.mutated,
    crossed_inputs: counters.crossed,
    admitted_inputs: counters.admitted,
    rejected_inputs: counters.rejected,
    unique_failures: failures.length(),
    mutation_failures: counters.mutation_failures,
    final_corpus: corpus.statistics(),
  }
  Ok({ statistics, corpus: corpus.entries(), failures, events, })
}
