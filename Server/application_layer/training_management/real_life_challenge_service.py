from fastapi import HTTPException
from sqlalchemy import text
from sqlalchemy.orm import Session


def _lock_user(db: Session, user_id: int) -> None:
    # Prevent simultaneous requests from assigning multiple challenges.
    user = db.execute(
        text("""
            SELECT id
            FROM users
            WHERE id = :user_id
            FOR UPDATE
        """),
        {"user_id": user_id},
    ).scalar_one_or_none()

    if user is None:
        raise HTTPException(
            status_code=404,
            detail="الحساب غير موجود",
        )


def _read_current(db: Session, user_id: int):
    return db.execute(
        text("""
            SELECT *
            FROM real_life_challenge_attempts
            WHERE user_id = :user_id
              AND is_current = TRUE
        """),
        {"user_id": user_id},
    ).mappings().one_or_none()


def _require_current(
    db: Session,
    user_id: int,
    attempt_id: int,
):
    attempt = db.execute(
        text("""
            SELECT *
            FROM real_life_challenge_attempts
            WHERE id = :attempt_id
              AND user_id = :user_id
        """),
        {
            "attempt_id": attempt_id,
            "user_id": user_id,
        },
    ).mappings().one_or_none()

    if attempt is None:
        raise HTTPException(
            status_code=404,
            detail="التحدّي غير موجود",
        )

    if not attempt["is_current"]:
        raise HTTPException(
            status_code=409,
            detail="هذا تحدٍّ سابق. حدّث الصفحة لعرض تحدّيك الحالي",
        )

    return attempt


def _assign_challenge(
    db: Session,
    user_id: int,
    previous_challenge_id: int | None = None,
):
    # Prefer unseen challenges and avoid immediately repeating the last one.
    challenge = db.execute(
        text("""
            SELECT c.id, c.title, c.instructions
            FROM real_life_challenges AS c
            WHERE c.is_active = TRUE
            ORDER BY
                CASE
                    WHEN c.id = :previous_id THEN 1
                    ELSE 0
                END,
                CASE
                    WHEN EXISTS (
                        SELECT 1
                        FROM real_life_challenge_attempts AS a
                        WHERE a.user_id = :user_id
                          AND a.challenge_id = c.id
                    ) THEN 1
                    ELSE 0
                END,
                random()
            LIMIT 1
        """),
        {
            "user_id": user_id,
            "previous_id": previous_challenge_id,
        },
    ).mappings().first()

    if challenge is None:
        raise HTTPException(
            status_code=409,
            detail="لا توجد تحدّيات متاحة حاليًا",
        )

    # Save the wording so future catalogue edits do not change past attempts.
    return db.execute(
        text("""
            INSERT INTO real_life_challenge_attempts (
                user_id,
                challenge_id,
                title,
                instructions
            )
            VALUES (
                :user_id,
                :challenge_id,
                :title,
                :instructions
            )
            RETURNING *
        """),
        {
            "user_id": user_id,
            "challenge_id": challenge["id"],
            "title": challenge["title"],
            "instructions": challenge["instructions"],
        },
    ).mappings().one()


def get_current_challenge(
    db: Session,
    user_id: int,
):
    attempt = _read_current(db, user_id)
    return dict(attempt) if attempt is not None else None


def ensure_current_challenge(
    db: Session,
    user_id: int,
):
    """Return the existing challenge or assign the user's first one."""
    try:
        _lock_user(db, user_id)

        attempt = _read_current(db, user_id)

        if attempt is None:
            attempt = _assign_challenge(db, user_id)

        result = dict(attempt)
        db.commit()
        return result

    except Exception:
        db.rollback()
        raise


def set_challenge_completion(
    db: Session,
    user_id: int,
    attempt_id: int,
    completed: bool,
):
    try:
        _lock_user(db, user_id)
        _require_current(db, user_id, attempt_id)

        attempt = db.execute(
            text("""
                UPDATE real_life_challenge_attempts
                SET
                    is_completed = :completed,
                    completed_at = CASE
                        WHEN :completed THEN
                            COALESCE(completed_at, CURRENT_TIMESTAMP)
                        ELSE NULL
                    END
                WHERE id = :attempt_id
                  AND user_id = :user_id
                RETURNING *
            """),
            {
                "completed": completed,
                "attempt_id": attempt_id,
                "user_id": user_id,
            },
        ).mappings().one()

        # Unmarking preserves any reflection already written.
        result = dict(attempt)
        db.commit()
        return result

    except Exception:
        db.rollback()
        raise


def save_challenge_reflection(
    db: Session,
    user_id: int,
    attempt_id: int,
    reflection: str,
):
    reflection = reflection.strip()

    if len(reflection) > 2000:
        raise HTTPException(
            status_code=422,
            detail="يجب ألا تتجاوز التجربة ٢٠٠٠ حرف",
        )

    try:
        _lock_user(db, user_id)
        attempt = _require_current(db, user_id, attempt_id)

        if not attempt["is_completed"]:
            raise HTTPException(
                status_code=409,
                detail="أكمل التحدّي قبل حفظ تجربتك",
            )

        updated = db.execute(
            text("""
                UPDATE real_life_challenge_attempts
                SET
                    reflection = :reflection,
                    reflection_updated_at = CURRENT_TIMESTAMP
                WHERE id = :attempt_id
                  AND user_id = :user_id
                RETURNING *
            """),
            {
                "reflection": reflection or None,
                "attempt_id": attempt_id,
                "user_id": user_id,
            },
        ).mappings().one()

        result = dict(updated)
        db.commit()
        return result

    except Exception:
        db.rollback()
        raise


def next_challenge(
    db: Session,
    user_id: int,
    attempt_id: int,
):
    """Keep the completed attempt in history and assign another."""
    try:
        _lock_user(db, user_id)
        attempt = _require_current(db, user_id, attempt_id)

        if not attempt["is_completed"]:
            raise HTTPException(
                status_code=409,
                detail="أكمل تحدّيك الحالي قبل اختيار تحدٍّ جديد",
            )

        db.execute(
            text("""
                UPDATE real_life_challenge_attempts
                SET is_current = FALSE
                WHERE id = :attempt_id
                  AND user_id = :user_id
            """),
            {
                "attempt_id": attempt_id,
                "user_id": user_id,
            },
        )

        new_attempt = _assign_challenge(
            db,
            user_id,
            previous_challenge_id=attempt["challenge_id"],
        )

        result = dict(new_attempt)
        db.commit()
        return result

    except Exception:
        # Restore the previous current attempt if assignment fails.
        db.rollback()
        raise


def get_challenge_history(
    db: Session,
    user_id: int,
    limit: int = 20,
    offset: int = 0,
):
    attempts = db.execute(
        text("""
            SELECT *
            FROM real_life_challenge_attempts
            WHERE user_id = :user_id
              AND is_completed = TRUE
            ORDER BY completed_at DESC, id DESC
            LIMIT :limit OFFSET :offset
        """),
        {
            "user_id": user_id,
            "limit": limit + 1,
            "offset": offset,
        },
    ).mappings().all()

    return {
        "items": [
            dict(attempt)
            for attempt in attempts[:limit]
        ],
        "has_more": len(attempts) > limit,
    }