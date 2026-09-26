from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from api.assessment import router as assessment_router

from fastapi.staticfiles import StaticFiles
from application_layer.authentication_managment.main import (
    app as authentication_app,
)


app = FastAPI(
    title="Taleeq API",
    description="Backend API for Taleeq",
    version="1.0.0",
)
#temprory until correct the path of the test audio files in the client side
app.mount(
    "/test-audio",
    StaticFiles(directory="test_audio"),
    name="test-audio",
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

# Adds the authentication application under /auth.
app.mount("/auth", authentication_app)


@app.get("/")
def root():
    return {"message": "Taleeq API is running"}