
import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from api.assessment import router as assessment_router
from api.training import router as training_router
from api.techniques import router as techniques_router
from api.speech_exercises import router as speech_exercises_router
from api.naming_game import router as naming_challenge_router
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from api.assessment import router as assessment_router
from api.training import router as training_router

from application_layer.authentication_managment.main import (
    app as authentication_app,
)
from api.speech_exercises import router as speech_exercises_router
from api.exercise import router as exercise_router
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
)
from api.naming_game import router as naming_challenge_router
from api.naming_game import router as naming_game_router
from api.dont_say_it import router as dont_say_it_router


app = FastAPI(
    title="Taleeq API",
    description="Backend API for Taleeq",
    version="1.0.0",
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
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

# Technique instruction endpoints
app.include_router(techniques_router)

# Training exercise endpoints
app.include_router(training_router)

# Speech exercise endpoints
app.include_router(speech_exercises_router)


# Authentication endpoints
app.mount("/auth", authentication_app)

# Adds the speech exercises endpoints.
app.include_router(speech_exercises_router)

# Adds exercise audio analysis endpoints.
app.include_router(exercise_router)

# Adds the naming challenge endpoints.
app.include_router(naming_challenge_router)
# Adds game endpoints.
app.include_router(naming_game_router)
app.include_router(dont_say_it_router)


@app.get("/")
def root():
    return {"message": "Taleeq API is running"}
