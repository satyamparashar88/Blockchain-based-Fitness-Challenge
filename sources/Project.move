module MyModule::FitnessChallenge {
    use aptos_framework::signer;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::timestamp;

    /// Struct representing a fitness challenge
    struct Challenge has store, key {
        stake_amount: u64,      // Amount staked by participant
        target_steps: u64,      // Target steps to complete
        current_steps: u64,     // Current steps completed
        end_time: u64,          // Challenge end timestamp
        completed: bool,        // Challenge completion status
        stake_deposited: coin::Coin<AptosCoin>, // Stored stake
    }

    /// Function to join a fitness challenge with a stake
    public fun join_challenge(
        participant: &signer, 
        stake_amount: u64, 
        target_steps: u64, 
        duration_days: u64
    ) {
        // Calculate end time (duration in seconds)
        let current_time = timestamp::now_seconds();
        let end_time = current_time + (duration_days * 24 * 60 * 60);
        
        // Withdraw stake from participant
        let stake = coin::withdraw<AptosCoin>(participant, stake_amount);
        
        // Create challenge with stake stored
        let challenge = Challenge {
            stake_amount,
            target_steps,
            current_steps: 0,
            end_time,
            completed: false,
            stake_deposited: stake,
        };
        
        move_to(participant, challenge);
    }

    /// Function to complete challenge and claim reward
    public fun complete_challenge(participant: &signer, steps_completed: u64) acquires Challenge {
        let participant_addr = signer::address_of(participant);
        let challenge = borrow_global_mut<Challenge>(participant_addr);
        
        // Check if challenge period has ended
        let current_time = timestamp::now_seconds();
        assert!(current_time <= challenge.end_time, 1);
        
        // Update steps
        challenge.current_steps = steps_completed;
        
        // Check if target is met
        if (steps_completed >= challenge.target_steps && !challenge.completed) {
            challenge.completed = true;
            
            // Extract the original stake
            let original_stake = coin::extract_all(&mut challenge.stake_deposited);
            let stake_value = coin::value(&original_stake);
            
            // Create reward (50% bonus)
            let bonus = coin::withdraw<AptosCoin>(participant, stake_value / 2);
            
            // Merge original stake with bonus
            coin::merge(&mut original_stake, bonus);
            
            // Return total reward to participant
            coin::deposit<AptosCoin>(participant_addr, original_stake);
        }
    }
}