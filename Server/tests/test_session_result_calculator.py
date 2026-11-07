"""Run from the Server folder:  python3 -m tests.test_session_result_calculator
(or with pytest). No database needed."""

from application_layer.training_management.session_result_calculator import (
    build_session_result,
)


def attempt(total, fluency, rhythm, speed, task, stutter, seconds, technique=None):
    return {
        "total_score": total,
        "fluency_score": fluency,
        "rhythm_score": rhythm,
        "speed_control_score": speed,
        "task_adherence_score": task,
        "stuttering_percent": stutter,
        "repetition_percent": stutter / 2,
        "prolongation_percent": stutter / 4,
        "block_percent": stutter / 4,
        "audio_duration_seconds": seconds,
        "technique_status": technique,
    }


def test_total_is_simple_average_and_stuttering_is_duration_weighted():
    result = build_session_result(
        [
            attempt(90, 96, 85, 80, 99, 4.0, 90, "applied"),
            attempt(80, 90, 80, 70, 80, 20.0, 10, "partial"),
        ]
    )

    assert result["total_score"] == 85.0
    assert result["exercise_count"] == 2
    # (4*90 + 20*10) / 100 = 5.6, not the plain average 12.0
    assert result["stuttering_percent"] == 5.6
    assert result["technique_summary"] == {
        "exercises_with_technique": 2,
        "applied": 1,
        "partial": 1,
        "not_applied": 0,
    }


def test_session_text_comes_from_best_and_worst_exercise():
    best = attempt(90, 90, 90, 90, 90, 1.0, 30)
    best.update(title="رحلة إلى البحر", strength="ثباتك واضح", improvement="خفف السرعة")
    worst = attempt(60, 60, 60, 60, 60, 1.0, 30)
    worst.update(title="وصف الصورة", strength="بدايتك جيدة", improvement="ركّز على المهمة")

    feedback = build_session_result([best, worst])["feedback"]

    assert feedback["strength"] == "ثباتك واضح"
    assert feedback["strength_exercise"] == "رحلة إلى البحر"
    assert feedback["improvement"] == "ركّز على المهمة"
    assert feedback["improvement_exercise"] == "وصف الصورة"


def test_falls_back_to_template_when_exercises_have_no_text():
    feedback = build_session_result(
        [attempt(85, 96, 85, 60, 99, 1.0, 30)]
    )["feedback"]

    assert feedback["strength_exercise"] is None
    assert "الالتزام بالمهمة" in feedback["strength"]


def test_strength_and_improvement_follow_best_and_worst_metric():
    result = build_session_result(
        [attempt(85, 96, 85, 60, 99, 1.0, 30)]
    )

    assert "الالتزام بالمهمة" in result["feedback"]["strength"]
    assert "التحكم بالسرعة" in result["feedback"]["improvement"]


def test_balanced_session_has_no_weak_metric():
    result = build_session_result([attempt(80, 80, 80, 80, 80, 1.0, 30)])

    assert "متوازنًا" in result["feedback"]["improvement"]


def test_score_change_against_previous_session():
    first = build_session_result([attempt(80, 80, 80, 80, 80, 1.0, 30)])
    assert first["score_change"] is None

    second = build_session_result(
        [attempt(85, 85, 85, 85, 85, 1.0, 30)],
        previous_total_score=first["total_score"],
    )
    assert second["score_change"] == 5.0


def test_missing_technique_status_and_zero_duration_are_safe():
    result = build_session_result(
        [attempt(70, 70, 70, 70, 70, 2.0, 0, None)]
    )

    assert result["technique_summary"]["exercises_with_technique"] == 0
    assert result["stuttering_percent"] == 2.0


def test_empty_session_is_rejected():
    try:
        build_session_result([])
    except ValueError:
        return

    raise AssertionError("expected ValueError")


if __name__ == "__main__":
    for name, fn in list(globals().items()):
        if name.startswith("test_"):
            fn()
            print("ok ", name)
