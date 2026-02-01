use extendr_api::prelude::*;
use fsrs::{FSRS, MemoryState, DEFAULT_PARAMETERS, FSRSItem, FSRSReview, ComputeParametersInput};

const DECAY: f64 = -0.5;
const FACTOR: f64 = 19.0 / 81.0;

// ============================================================================
// PARAMETERS
// ============================================================================

#[extendr]
fn fsrs_default_parameters() -> Vec<f64> {
    DEFAULT_PARAMETERS.iter().map(|&x| x as f64).collect()
}

// ============================================================================
// CORE SCHEDULING FUNCTIONS
// ============================================================================

#[extendr]
fn fsrs_next_interval(stability: f64, desired_retention: f64, params: Option<Vec<f64>>) -> f64 {
    let fsrs = create_fsrs(params);
    fsrs.next_interval(Some(stability as f32), desired_retention as f32, 0) as f64
}

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

#[extendr]
fn fsrs_retrievability(stability: f64, elapsed_days: f64) -> f64 {
    if stability <= 0.0 {
        return 1.0;
    }
    (1.0 + FACTOR * elapsed_days / stability).powf(DECAY)
}

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

#[extendr]
fn fsrs_optimize(
    ratings: Vec<i32>,
    delta_ts: Vec<i32>,
    card_starts: Vec<i32>,
    enable_short_term: bool
) -> List {
    // Convert card_starts to 0-based indices and add end marker
    let mut starts: Vec<usize> = card_starts.iter().map(|&x| (x - 1) as usize).collect();
    starts.push(ratings.len());
    
    // Build FSRSItems for each card
    let mut items: Vec<FSRSItem> = Vec::new();
    
    for window in starts.windows(2) {
        let start = window[0];
        let end = window[1];
        
        if start >= end || end > ratings.len() {
            continue;
        }
        
        let card_reviews: Vec<FSRSReview> = (start..end)
            .map(|i| FSRSReview {
                rating: (ratings[i] as u32).min(4).max(1),
                delta_t: delta_ts[i] as u32,
            })
            .collect();
        
        for i in 2..=card_reviews.len() {
            let slice = &card_reviews[0..i];
            if !slice.iter().any(|r| r.delta_t > 0) { continue; }
            items.push(FSRSItem {
                reviews: card_reviews[0..i].to_vec(),
            });
        }
    }
    
    if items.is_empty() {
        return list!(
            parameters = Vec::<f64>::new(),
            success = false,
            error = "No valid review data provided"
        );
    }
    
    // Create input for compute_parameters
    let input = ComputeParametersInput {
        train_set: items,
        enable_short_term: enable_short_term,
        ..Default::default()
    };
    
    // Create a default FSRS instance and call compute_parameters on it
    let fsrs = FSRS::new(Some(&DEFAULT_PARAMETERS)).unwrap();
    
    match fsrs.compute_parameters(input) {
        Ok(output) => {
            list!(
                parameters = output.iter().map(|&x| x as f64).collect::<Vec<_>>(),
                success = true,
                error = Null::<String>
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

#[extendr]
fn fsrs_evaluate(
    ratings: Vec<i32>,
    delta_ts: Vec<i32>,
    card_starts: Vec<i32>,
    params: Vec<f64>
) -> List {
    let fsrs = create_fsrs(Some(params));
    
    let mut starts: Vec<usize> = card_starts.iter().map(|&x| (x - 1) as usize).collect();
    starts.push(ratings.len());
    
    let mut items: Vec<FSRSItem> = Vec::new();
    
    for window in starts.windows(2) {
        let start = window[0];
        let end = window[1];
        
        if start >= end || end > ratings.len() {
            continue;
        }
        
        let card_reviews: Vec<FSRSReview> = (start..end)
            .map(|i| FSRSReview {
                rating: (ratings[i] as u32).min(4).max(1),
                delta_t: delta_ts[i] as u32,
            })
            .collect();
        
        for i in 2..=card_reviews.len() {
            let slice = &card_reviews[0..i];
            if !slice.iter().any(|r| r.delta_t > 0) { continue; }
            items.push(FSRSItem {
                reviews: card_reviews[0..i].to_vec(),
            });
        }
    }
    
    if items.is_empty() {
        return list!(
            log_loss = f64::NAN,
            rmse_bins = f64::NAN,
            success = false
        );
    }
    
    match fsrs.evaluate(items, |_| true) {
        Ok(metrics) => {
            list!(
                log_loss = metrics.log_loss as f64,
                rmse_bins = metrics.rmse_bins as f64,
                success = true
            )
        },
        Err(_) => {
            list!(
                log_loss = f64::NAN,
                rmse_bins = f64::NAN,
                success = false
            )
        }
    }
}

// ============================================================================
// HELPER
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
// MODULE
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
    fn fsrs_optimize;
    fn fsrs_evaluate;
}
