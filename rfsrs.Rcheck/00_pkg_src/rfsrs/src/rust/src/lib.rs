use extendr_api::prelude::*;
use fsrs::{FSRS, MemoryState, DEFAULT_PARAMETERS, FSRSItem, FSRSReview};

// Note: compute_parameters requires the "bundled-train" feature in Cargo.toml

const DECAY: f64 = -0.5;
const FACTOR: f64 = 19.0 / 81.0;

// ============================================================================
// PARAMETERS
// ============================================================================

/// Get default FSRS parameters (21 values for FSRS-6)
/// @export
#[extendr]
fn fsrs_default_parameters() -> Vec<f64> {
    DEFAULT_PARAMETERS.iter().map(|&x| x as f64).collect()
}

// ============================================================================
// CORE SCHEDULING FUNCTIONS (with optional custom parameters)
// ============================================================================

/// Calculate next interval for target retention
/// @param stability Current stability
/// @param desired_retention Target retention (0.0-1.0)
/// @param params Optional custom parameters (21 values). Uses defaults if NULL.
/// @export
#[extendr]
fn fsrs_next_interval(stability: f64, desired_retention: f64, params: Option<Vec<f64>>) -> f64 {
    let fsrs = create_fsrs(params);
    fsrs.next_interval(Some(stability as f32), desired_retention as f32, 0) as f64
}

/// Initial memory state for new card
/// @param rating Rating: 1=Again, 2=Hard, 3=Good, 4=Easy
/// @param params Optional custom parameters (21 values). Uses defaults if NULL.
/// @export
#[extendr]
fn fsrs_initial_state(rating: i32, params: Option<Vec<f64>>) -> List {
    let fsrs = create_fsrs(params);
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
/// @param params Optional custom parameters (21 values). Uses defaults if NULL.
/// @export
#[extendr]
fn fsrs_next_state(
    stability: f64, 
    difficulty: f64, 
    elapsed_days: f64, 
    rating: i32,
    params: Option<Vec<f64>>
) -> List {
    let fsrs = create_fsrs(params);
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

/// Get all four rating outcomes at once (like py-fsrs repeat())
/// @param stability Current stability (NULL for new card)
/// @param difficulty Current difficulty (NULL for new card)  
/// @param elapsed_days Days since last review (0 for new card)
/// @param desired_retention Target retention for interval calculation
/// @param params Optional custom parameters (21 values). Uses defaults if NULL.
/// @return List with $again, $hard, $good, $easy, each containing stability, difficulty, interval
/// @export
#[extendr]
fn fsrs_repeat(
    stability: Option<f64>,
    difficulty: Option<f64>,
    elapsed_days: f64,
    desired_retention: f64,
    params: Option<Vec<f64>>
) -> List {
    let fsrs = create_fsrs(params);
    
    let state = match (stability, difficulty) {
        (Some(s), Some(d)) => Some(MemoryState {
            stability: s as f32,
            difficulty: d as f32,
        }),
        _ => None,
    };
    
    let states = fsrs.next_states(state, elapsed_days as f32, 0).unwrap();
    
    let make_outcome = |item: &fsrs::ItemState| -> List {
        let interval = fsrs.next_interval(
            Some(item.memory.stability), 
            desired_retention as f32, 
            0
        );
        list!(
            stability = item.memory.stability as f64,
            difficulty = item.memory.difficulty as f64,
            interval = interval as f64
        )
    };
    
    list!(
        again = make_outcome(&states.again),
        hard = make_outcome(&states.hard),
        good = make_outcome(&states.good),
        easy = make_outcome(&states.easy)
    )
}

/// Calculate retrievability (recall probability)
/// @param stability Card stability
/// @param elapsed_days Days since last review
/// @export
#[extendr]
fn fsrs_retrievability(stability: f64, elapsed_days: f64) -> f64 {
    if stability <= 0.0 {
        return 1.0;
    }
    (1.0 + FACTOR * elapsed_days / stability).powf(DECAY)
}

/// Vectorized retrievability calculation
/// @param stability Vector of stability values
/// @param elapsed_days Vector of elapsed days (same length as stability)
/// @export
#[extendr]
fn fsrs_retrievability_vec(stability: Vec<f64>, elapsed_days: Vec<f64>) -> Vec<f64> {
    stability.iter()
        .zip(elapsed_days.iter())
        .map(|(s, t)| {
            if *s <= 0.0 {
                1.0
            } else {
                (1.0 + FACTOR * t / s).powf(DECAY)
            }
        })
        .collect()
}

// ============================================================================
// SM-2 MIGRATION
// ============================================================================

/// Convert SM-2 ease factor and interval to FSRS memory state
/// @param ease_factor SM-2 ease factor (typically 1.3-3.0)
/// @param interval Current interval in days
/// @param sm2_retention Assumed retention rate for SM-2 (default 0.9)
/// @param params Optional custom parameters (21 values). Uses defaults if NULL.
/// @export
#[extendr]
fn fsrs_from_sm2(
    ease_factor: f64, 
    interval: f64, 
    sm2_retention: f64,
    params: Option<Vec<f64>>
) -> List {
    let fsrs = create_fsrs(params);
    let state = fsrs.memory_state_from_sm2(
        ease_factor as f32,
        interval as f32, 
        sm2_retention as f32
    ).unwrap();
    
    list!(
        stability = state.stability as f64,
        difficulty = state.difficulty as f64
    )
}

// ============================================================================
// REVIEW HISTORY PROCESSING
// ============================================================================

/// Compute memory state from review history
/// @param ratings Vector of ratings (1-4) in chronological order
/// @param delta_ts Vector of days since previous review (0 for first review)
/// @param initial_stability Optional starting stability (for SM-2 migration)
/// @param initial_difficulty Optional starting difficulty (for SM-2 migration)
/// @param params Optional custom parameters (21 values). Uses defaults if NULL.
/// @export
#[extendr]
fn fsrs_memory_state(
    ratings: Vec<i32>,
    delta_ts: Vec<i32>,
    initial_stability: Option<f64>,
    initial_difficulty: Option<f64>,
    params: Option<Vec<f64>>
) -> List {
    let fsrs = create_fsrs(params);
    
    let reviews: Vec<FSRSReview> = ratings.iter()
        .zip(delta_ts.iter())
        .map(|(&r, &t)| FSRSReview { 
            rating: (r as u32).min(4).max(1), 
            delta_t: t as u32 
        })
        .collect();
    
    let item = FSRSItem { reviews };
    
    let initial = match (initial_stability, initial_difficulty) {
        (Some(s), Some(d)) => Some(MemoryState {
            stability: s as f32,
            difficulty: d as f32,
        }),
        _ => None,
    };
    
    let state = fsrs.memory_state(item, initial).unwrap();
    
    list!(
        stability = state.stability as f64,
        difficulty = state.difficulty as f64
    )
}

// ============================================================================
// PARAMETER OPTIMIZATION
// ============================================================================

// Note: Uncomment this section if you want to expose the optimizer.
// Requires: fsrs = { version = "5", features = ["bundled-train"] } in Cargo.toml
// This significantly increases compile time and binary size.

/*
/// Optimize FSRS parameters from review history
/// 
/// @param reviews_json JSON array of review items. Each item should have:
///   - ratings: array of ratings (1-4)
///   - delta_ts: array of days since previous review
/// @param enable_short_term Whether to enable short-term scheduling
/// @return List with optimized parameters and metrics
/// @export
#[cfg(feature = "optimizer")]
#[extendr]
fn fsrs_optimize(
    ratings_flat: Vec<i32>,
    delta_ts_flat: Vec<i32>, 
    card_lengths: Vec<i32>,  // Number of reviews per card
    enable_short_term: bool
) -> List {
    // Reconstruct FSRSItems from flat vectors
    let mut items = Vec::new();
    let mut offset = 0usize;
    
    for &len in card_lengths.iter() {
        let len = len as usize;
        let reviews: Vec<FSRSReview> = (0..len)
            .map(|i| FSRSReview {
                rating: ratings_flat[offset + i] as u32,
                delta_t: delta_ts_flat[offset + i] as u32,
            })
            .collect();
        
        // For optimization, we need cumulative review histories
        // Each FSRSItem contains all reviews up to that point
        for i in 1..=len {
            items.push(FSRSItem {
                reviews: reviews[0..i].to_vec(),
            });
        }
        offset += len;
    }
    
    let result = compute_parameters(ComputeParametersInput {
        train_set: items,
        enable_short_term: Some(enable_short_term),
        ..Default::default()
    });
    
    match result {
        Ok(output) => {
            list!(
                parameters = output.parameters.iter().map(|&x| x as f64).collect::<Vec<_>>(),
                success = true
            )
        },
        Err(e) => {
            list!(
                parameters = Vec::<f64>::new(),
                success = false,
                error = format!("{:?}", e)
            )
        }
    }
}
*/

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

fn create_fsrs(params: Option<Vec<f64>>) -> FSRS {
    match params {
        Some(p) => {
            let params_f32: Vec<f32> = p.iter().map(|&x| x as f32).collect();
            FSRS::new(Some(&params_f32)).unwrap()
        },
        None => FSRS::new(Some(&DEFAULT_PARAMETERS)).unwrap()
    }
}

// ============================================================================
// MODULE REGISTRATION
// ============================================================================

extendr_module! {
    mod rfsrs;
    fn fsrs_default_parameters;
    fn fsrs_next_interval;
    fn fsrs_initial_state;
    fn fsrs_next_state;
    fn fsrs_repeat;
    fn fsrs_retrievability;
    fn fsrs_retrievability_vec;
    fn fsrs_from_sm2;
    fn fsrs_memory_state;
    // Uncomment if using optimizer:
    // fn fsrs_optimize;
}
