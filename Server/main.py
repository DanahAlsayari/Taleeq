from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from api.assessment import router as assessment_router
from api.training import router as training_router

from fastapi.staticfiles import StaticFiles
from application_layer.authentication_managment.main import (
    app as authentication_app,
)
from api.naming_game import router as naming_game_router
from api.dont_say_it import router as dont_say_it_router


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


# Adds the assessment endpoints.
app.include_router(assessment_router)

# Adds the training endpoints.
app.include_router(training_router)

# Adds the authentication application under /auth.
app.mount("/auth", authentication_app)

# Adds game endpoints.
app.include_router(naming_game_router)
app.include_router(dont_say_it_router)


@app.get("/")
def root():
    return {"message": "Taleeq API is running"}