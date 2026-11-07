"""Pure calculation of a practice session result.

No database or framework imports, so it can be tested on its own.

Rules (agreed for the first version):
- Session total score = simple average of the exercise total scores.
- Each performance metric = simple average across exercises.
- Stuttering percentages = average weighted by recording duration, because
  the number of spoken words is not stored per attempt. Longer recordings
  therefore count more than short ones.
- Strength = the AI strength text of the exercise with the highest score.
  Improvement = the AI improvement text of the exercise with the lowest
  score. So the session text reflects the real exercise analysis. When an
  exercise has no AI text, a short template based on the averaged metrics
  is used instead.
"""

METRICS = (
    "fluency_score",
    "rhythm_score",
    "speed_control_score",
    "task_adherence_score",
)

METRIC_NAMES_AR = {
    "fluency_score": "الطلاقة",
    "rhythm_score": "الإيقاع",
    "speed_control_score": "التحكم بالسرعة",
    "task_adherence_score": "الالتزام بالمهمة",
}

STUTTERING_KEYS = (
    "stuttering_percent",
    "repetition_percent",
    "prolongation_percent",
    "block_percent",
)

TECHNIQUE_STATUSES = ("applied", "partial", "not_applied")


def _average(rows: list[dict], key: str) -> float:
    return sum(row[key] for row in rows) / len(rows)


def _weighted_average(rows: list[dict], key: str) -> float:
    weights = [max(1, row.get("audio_duration_seconds") or 1) for row in rows]

    return sum(
        row[key] * weight for row, weight in zip(rows, weights)
    ) / sum(weights)


def _pick_text(rows: list[dict], key: str, best: bool) -> dict | None:
    """Row whose AI text `key` is used: highest total for strength,
    lowest total for improvement. Ties keep the first exercise."""

    candidates = [
        row
        for row in rows
        if isinstance(row.get(key), str) and row[key].strip()
    ]

    if not candidates:
        return None

    chooser = max if best else min

    return chooser(candidates, key=lambda row: row["total_score"])


def build_session_result(
    attempts: list[dict],
    previous_total_score: float | None = None,
) -> dict:
    """Build the values stored in session_results.

    `attempts` holds one dict per session exercise (its latest attempt) with:
    total_score, the four metric scores, the four stuttering percentages,
    audio_duration_seconds, technique_status (or None), and optionally
    title, strength and improvement (the AI texts of that exercise).
    """

    if not attempts:
        raise ValueError("A session result needs at least one attempt.")

    scores = {
        metric: round(_average(attempts, metric), 2)
        for metric in METRICS
    }

    total_score = round(_average(attempts, "total_score"), 2)

    strongest = max(METRICS, key=lambda metric: scores[metric])
    weakest = min(METRICS, key=lambda metric: scores[metric])

    strength_row = _pick_text(attempts, "strength", best=True)
    improvement_row = _pick_text(attempts, "improvement", best=False)

    if strength_row is not None:
        strength = strength_row["strength"].strip()
    else:
        strength = (
            f"أقوى جوانب أدائك في هذه الجلسة كان "
            f"{METRIC_NAMES_AR[strongest]}."
        )

    if improvement_row is not None:
        improvement = improvement_row["improvement"].strip()
    elif scores[strongest] == scores[weakest]:
        improvement = "أداؤك كان متوازنًا بين جميع المقاييس، استمر على نفس المستوى."
    else:
        improvement = (
            f"أكثر جانب يحتاج تركيزك في الجلسة القادمة هو "
            f"{METRIC_NAMES_AR[weakest]}."
        )

    statuses = [
        attempt.get("technique_status")
        for attempt in attempts
        if attempt.get("technique_status") in TECHNIQUE_STATUSES
    ]

    technique_summary = {
        "exercises_with_technique": len(statuses),
        "applied": statuses.count("applied"),
        "partial": statuses.count("partial"),
        "not_applied": statuses.count("not_applied"),
    }

    score_change = (
        round(total_score - previous_total_score, 2)
        if previous_total_score is not None
        else None
    )

    return {
        "total_score": total_score,
        "fluency_score": scores["fluency_score"],
        "rhythm_score": scores["rhythm_score"],
        "speed_control_score": scores["speed_control_score"],
        "task_adherence_score": scores["task_adherence_score"],
        "stuttering_percent": round(
            _weighted_average(attempts, "stuttering_percent"), 2
        ),
        "repetition_percent": round(
            _weighted_average(attempts, "repetition_percent"), 2
        ),
        "prolongation_percent": round(
            _weighted_average(attempts, "prolongation_percent"), 2
        ),
        "block_percent": round(
            _weighted_average(attempts, "block_percent"), 2
        ),
        "exercise_count": len(attempts),
        "previous_total_score": previous_total_score,
        "score_change": score_change,
        "feedback": {
            "strength": strength,
            "strength_exercise": (
                strength_row.get("title") if strength_row else None
            ),
            "improvement": improvement,
            "improvement_exercise": (
                improvement_row.get("title") if improvement_row else None
            ),
        },
        "technique_summary": technique_summary,
    }
