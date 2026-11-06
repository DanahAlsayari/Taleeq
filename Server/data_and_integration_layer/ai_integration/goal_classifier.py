import os

from dotenv import load_dotenv
from openai import OpenAI

from pydantic import BaseModel, Field
from typing import Literal

load_dotenv()

GoalCategory = Literal[
    "GENERAL_FLUENCY",
    "SPEECH_BLOCKS",
    "DAILY_CONVERSATION",
    "PRESENTATION",
    "PHONE_CALL",
    "JOB_INTERVIEW",
    "SPEAKING_ANXIETY",
    "SPEECH_REPETITIONS",
    "SPEECH_PROLONGATIONS",
    "UNKNOWN",
]


class GoalClassificationResult(BaseModel):
    categories: list[GoalCategory] = Field(min_length=1)


class GoalClassifier:

    def __init__(self):
        api_key = os.getenv("OPENAI_API_KEY")

        if not api_key:
            raise ValueError("OPENAI_API_KEY is not set.")

        self.client = OpenAI(api_key=api_key)

    def classify_goal(self, goal_text: str) -> GoalClassificationResult:
        response = self.client.beta.chat.completions.parse(
            model="gpt-4o-mini",
            messages=[
                {
                    "role": "system",
                    "content": (
                        "You classify training goals for Taleeq, "
                        "a speech practice application for people who stutter. "
                        "The goal may be written in Arabic or English. "
                        "Classify the goal into one or more available categories. "
                        "SPEECH_BLOCKS means an explicitly stated difficulty "
                        "initiating or continuing speech due to a speech block. "
                        "Do not classify general stuttering or general fluency "
                        "improvement as SPEECH_BLOCKS unless speech blocks "
                        "are specifically mentioned or clearly described. "
                        "not normal pauses. "
                        "SPEECH_REPETITIONS refers to explicitly mentioned "
                        "involuntary repetitions of sounds, syllables, or words. "
                        "SPEECH_PROLONGATIONS refers to explicitly mentioned "
                        "unusually prolonged or stretched speech sounds. "
                        "Distinguish speech repetitions, prolongations, and blocks. "
                        "Do not infer one stuttering type from another. "
                        "GENERAL_FLUENCY refers to an explicitly stated goal "
                        "of improving overall speech fluency or reducing stuttering "
                        "in general. "
                        "Return all categories explicitly supported by the goal. "
                        "SPEAKING_ANXIETY means psychological fear or anxiety "
                        "about speaking, not physical muscle tension. "
                        "Do not recommend techniques or diagnose the patient. "
                        "Do not infer goals that are not expressed. "
                        "If the goal is unclear, return UNKNOWN only."
                    ),
                },
                {
                    "role": "user",
                    "content": goal_text,
                },
            ],
            response_format=GoalClassificationResult,
        )
        result = response.choices[0].message.parsed
        if result is None:
            raise ValueError("OpenAI did not return a valid classification.")

        return result
