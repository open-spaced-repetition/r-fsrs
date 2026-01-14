use extendr_api::prelude::*;
use fsrs::{FSRS, MemoryState, DEFAULT_PARAMETERS};

const DECAY: f64 = -0.5;
// FACTOR = 0.9^(1/DECAY) - 1 = 0.9^(-2) - 1 = 1/0.81 - 1 ≈ 0.2346
const FACTOR: f64 = 19.0 / 81.0;

/// Get default FSRS parameters
/// @export
#[extendr]
fn fsrs_default_parameters() -> Vec<f64> {
    DEFAULT_PARAMETERS.iter().map(|&x| x as f64).collect()
}

/// Calculate next interval
/// @param stability Current stability
/// @param desired_retention Target retention (0.0-1.0)
/// @export
#[extendr]
fn fsrs_next_interval(stability: f64, desired_retention: f64) -> f64 {
    let fsrs = FSRS::new(Some(&DEFAULT_PARAMETERS)).unwrap();
    fsrs.next_interval(Some(stability as f32), desired_retention as f32, 0) as f64
}

/// Initial memory state for new card
/// @param rating Rating: 1=Again, 2=Hard, 3=Good, 4=Easy
/// @export
#[extendr]
fn fsrs_initial_state(rating: i32) -> List {
    let fsrs = FSRS::new(Some(&DEFAULT_PARAMETERS)).unwrap();
    let r = (rating as u32).min(4).max(1);
    let states = fsrs.next_states(None, 0.0, 0).unwrap();
    let state = match r {
        1 => states.again.memory,
        2 => states.hard.memory,
        3 => states.good.memory,
        4 => states.easy.memory,
        _ => states.good.memory,
    };
    list!(
        stability = state.stability as f64,
        difficulty = state.difficulty as f64
    )
}

/// Next memory state after review
/// @param stability Current stability
/// @param difficulty Current difficulty  
/// @param elapsed_days Days since last review
/// @param rating Rating: 1=Again, 2=Hard, 3=Good, 4=Easy
/// @export
#[extendr]
fn fsrs_next_state(stability: f64, difficulty: f64, elapsed_days: f64, rating: i32) -> List {
    let fsrs = FSRS::new(Some(&DEFAULT_PARAMETERS)).unwrap();
    let state = MemoryState { 
        stability: stability as f32, 
        difficulty: difficulty as f32 
    };
    let r = (rating as u32).min(4).max(1);
    let states = fsrs.next_states(Some(state), elapsed_days as f32, 0).unwrap();
    let next = match r {
        1 => states.again.memory,
        2 => states.hard.memory,
        3 => states.good.memory,
        4 => states.easy.memory,
        _ => states.good.memory,
    };
    list!(
        stability = next.stability as f64,
        difficulty = next.difficulty as f64
    )
}

/// Calculate retrievability (recall probability)
/// @param stability Card stability
/// @param elapsed_days Days since last review
/// @export
#[extendr]
fn fsrs_retrievability(stability: f64, elapsed_days: f64) -> f64 {
    (1.0 + FACTOR * elapsed_days / stability).powf(DECAY)
}

extendr_module! {
    mod fsrsr;
    fn fsrs_default_parameters;
    fn fsrs_next_interval;
    fn fsrs_initial_state;
    fn fsrs_next_state;
    fn fsrs_retrievability;
}
