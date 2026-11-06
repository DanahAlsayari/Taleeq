from data_and_integration_layer.database.connection import SessionLocal

from application_layer.training_management.technique_recommendation_service import (
    TechniqueRecommendationService,
)
from data_and_integration_layer.database.models.user import User
from data_and_integration_layer.database.models.assessment import Assessment

db = SessionLocal()

try:
    service = TechniqueRecommendationService(db)

    user_id = 110 # Replace with an existing test user's ID

    active_goals, techniques = service.get_recommendation_inputs(user_id)

    print("ACTIVE GOALS:")
    for goal in active_goals:
        print(goal.id, goal.goal)

    categories = service.classify_active_goals(active_goals)
    print("GOAL CATEGORIES:", categories)

    print("\nAVAILABLE TECHNIQUES:")
    for technique in techniques:
        print(technique.id, technique.name_en)

    print("\nGOAL-BASED SCORES:")

    scores = service.get_goal_based_scores(user_id)

    for technique in techniques:
        print(
            technique.name_en,
            "->",
            scores[technique.id]
        )

    techniques = service.technique_repository.get_all_techniques()

    scores = service.get_goal_based_scores(user_id)

    ranked_techniques = service.rank_techniques(techniques, scores)

    for technique in ranked_techniques:
        print(technique.name_en, "->", scores[technique.id])

    completed_session_counts = {
        1: 3,  # Easy Onset
        2: 1,  # Prolonged Speech
        3: 0,  # Rate Control
    }

    rotation_ranked = service.rank_goal_matched_by_rotation(
        techniques,
        scores,
        completed_session_counts,
    )

    print("\nROTATION RANKING:")
    for technique in rotation_ranked:
        print(
            technique.name_en,
            "-> Score:", scores[technique.id],
            "| Completed Sessions:",
            completed_session_counts.get(technique.id, 0),
        )

    print("\nINITIAL PRACTICE TESTS:")

    test_cases = [
        {1: 2, 2: 2, 3: 2},
        {1: 3, 2: 1, 3: 0},
        {1: 2, 2: 3, 3: 1},
        {1: 4, 2: 3, 3: 2},
    ]

    for counts in test_cases:
        result = service.is_initial_practice_complete(scores, counts)
        print(counts, "->", result)

    print("\nEXPLORATION SCHEDULE TESTS:")

    for session_number in range(1, 10):
        result = service.should_explore(session_number)
        print(f"Session {session_number} -> {result}")

    exploration_counts = {
        4: 2,  # Controlled Pausing
        5: 0,  # Metronome / Rhythmic Speech
        7: 1,  # Cancellation
        8: 0,  # Stuttering Modification / Easing
    }

    exploration_ranked = service.rank_exploration_techniques(
        techniques,
        scores,
        exploration_counts,
    )

    print("\nEXPLORATION RANKING:")

    for technique in exploration_ranked:
        print(
            technique.name_en,
            "-> Score:", scores[technique.id],
            "| Completed Sessions:",
            exploration_counts.get(technique.id, 0),
        )

    print("\nCOMBINED RECOMMENDATION TESTS:")

    completed_counts = {
        1: 2,
        2: 2,
        3: 2,
    }

    for session_number in [1, 2, 3]:
        result = service.get_session_technique_candidates(
            techniques,
            scores,
            completed_counts,
            session_number,
        )

        print(f"\nSession {session_number}")
        print("Explore:", result["explore"])

        print("Goal Techniques:")
        for technique in result["goal_ranked"]:
            print("-", technique.name_en)

        print("Exploration Techniques:")
        for technique in result["exploration_ranked"]:
            print("-", technique.name_en)

    incomplete_counts = {
        1: 2,  # Easy Onset
        2: 1,  # Prolonged Speech
        3: 0,  # Rate Control
    }

    result = service.get_session_technique_candidates(
        techniques,
        scores,
        incomplete_counts,
        3,
    )

    print("\nINCOMPLETE INITIAL PHASE TEST:")
    print("Explore:", result["explore"])
    print("Exploration Candidates:", len(result["exploration_ranked"]))
    print("Goal Ranking:")

    for technique in result["goal_ranked"]:
        print("-", technique.name_en)

    print("\nGENERAL PRACTICE FALLBACK TEST:")

    zero_scores = {
        technique.id: 0
        for technique in techniques
    }

    zero_counts = {
        technique.id: 0
        for technique in techniques
    }

    result = service.get_session_technique_candidates(
        techniques,
        zero_scores,
        zero_counts,
        1,
    )

    print("Explore:", result["explore"])
    print("Recommended Order:")

    for technique in result["goal_ranked"]:
        print("-", technique.name_en)

    print("\nGENERAL PRACTICE ROTATION TEST:")

    practice_counts = {
        1: 3,  # Easy Onset
        2: 1,  # Prolonged Speech
        3: 2,  # Rate Control
        4: 0,  # Controlled Pausing
        5: 0,  # Metronome
        7: 1,  # Cancellation
        8: 0,  # Stuttering Modification
    }

    result = service.get_session_technique_candidates(
        techniques,
        zero_scores,
        practice_counts,
        2,
    )

    for technique in result["goal_ranked"]:
        print(
            technique.name_en,
            "-> Completed Sessions:",
            practice_counts.get(technique.id, 0),
        )

    print("\nSINGLE EXERCISE TEST:")

    candidates = service.get_session_technique_candidates(
        techniques,
        scores,
        {1: 2, 2: 2, 3: 2},
        3,
    )

    selected = service.select_session_techniques(
        candidates,
        exercise_count=1,
    )

    print("Selected Techniques:")
    for technique in selected:
        print("-", technique.name_en)

    print("Number of Techniques:", len(selected))


    print("\n========== FINAL TECHNIQUE SELECTION TESTS ==========")

    def run_selection_test(name, test_candidates, exercise_count, expected_exploration=0):
        print(f"\n{name}")

        try:
            selected = service.select_session_techniques(
                test_candidates,
                exercise_count,
            )

            exploration_ids = {
                technique.id
                for technique in test_candidates["exploration_ranked"]
            }

            exploration_count = sum(
                technique.id in exploration_ids
                for technique in selected
            )

            for index, technique in enumerate(selected, start=1):
                technique_type = (
                    "Exploration"
                    if technique.id in exploration_ids
                    else "Goal/General"
                )
                print(f"Exercise {index}: {technique.name_en} ({technique_type})")

            valid_count = len(selected) == max(exercise_count, 0)
            valid_exploration = exploration_count == expected_exploration

            print("Total:", len(selected))
            print("Correct Count:", valid_count)
            print("Correct Exploration Count:", valid_exploration)
            print("RESULT:", "PASS" if valid_count and valid_exploration else "FAIL")

        except Exception as error:
            print("RESULT: ERROR")
            print(type(error).__name__, ":", error)


    # Shared test data
    goal_techniques = [t for t in techniques if t.id in (1, 2, 3)]
    one_goal_technique = [t for t in techniques if t.id == 1]
    exploration_techniques = [t for t in techniques if t.id in (4, 5)]

    goal_candidates = {
        "goal_ranked": goal_techniques,
        "exploration_ranked": [],
        "explore": False,
    }

    explore_candidates = {
        "goal_ranked": goal_techniques,
        "exploration_ranked": exploration_techniques,
        "explore": True,
    }

    one_goal_explore_candidates = {
        "goal_ranked": one_goal_technique,
        "exploration_ranked": exploration_techniques,
        "explore": True,
    }

    general_candidates = {
        "goal_ranked": techniques,
        "exploration_ranked": [],
        "explore": False,
    }

    # 1. One exercise, goal-focused
    run_selection_test(
        "TEST 1: One Goal-Focused Exercise",
        goal_candidates, 1
    )

    # 2. Three exercises, goal-focused
    run_selection_test(
        "TEST 2: Three Goal-Focused Exercises",
        goal_candidates, 3
    )

    # 3. More exercises than goal-matched techniques
    run_selection_test(
        "TEST 3: Goal-Focused Repetition",
        goal_candidates, 5
    )

    # 4. Exploration due, but only one exercise
    run_selection_test(
        "TEST 4: Single Exercise During Exploration",
        explore_candidates, 1
    )

    # 5. Two exercises with exploration
    run_selection_test(
        "TEST 5: Two Exercises With Exploration",
        explore_candidates, 2, expected_exploration=1
    )

    # 6. Four exercises with exploration
    run_selection_test(
        "TEST 6: Four Exercises With Exploration",
        explore_candidates, 4, expected_exploration=1
    )

    # 7. Only one goal-matched technique, four exercises
    run_selection_test(
        "TEST 7: One Goal Technique With Exploration",
        one_goal_explore_candidates, 4, expected_exploration=1
    )

    # 8. General Practice fallback
    run_selection_test(
        "TEST 8: General Practice",
        general_candidates, 4
    )

    # 9. Zero exercises
    run_selection_test(
        "TEST 9: Zero Exercises",
        goal_candidates, 0
    )

    # 10. No available techniques
    empty_candidates = {
        "goal_ranked": [],
        "exploration_ranked": [],
        "explore": False,
    }

    run_selection_test(
        "TEST 10: No Available Techniques",
        empty_candidates, 3
    )


finally:
    db.close()
