import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from api.assessment import router as assessment_router
from api.training import router as training_router
from api.techniques import router as techniques_router
from api.speech_exercises import router as speech_exercises_router
from api.exercise import router as exercise_router
from api.naming_game import router as naming_challenge_router
from api.dont_say_it import router as dont_say_it_router

from application_layer.authentication_managment.main import (
    app as authentication_app,
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
)

app = FastAPI(
    title="Taleeq API",
    description="Backend API for Taleeq",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Assessment endpoints
app.include_router(assessment_router)

# Technique endpoints
app.include_router(techniques_router)

# Training endpoints
app.include_router(training_router)

# Speech exercise endpoints
app.include_router(speech_exercises_router)

# Exercise analysis endpoints
app.include_router(exercise_router)

# Game endpoints
app.include_router(naming_challenge_router)
app.include_router(dont_say_it_router)

# Authentication endpoints
app.mount("/auth", authentication_app)


@app.get("/")
def root():
    return {"message": "Taleeq API is running"}