from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from api.assessment import router as assessment_router
from api.training import router as training_router

import logging

from api.techniques import router as techniques_router

from fastapi.staticfiles import StaticFiles
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


# Adds the assessment endpoints.
app.include_router(assessment_router)

# Adds technique instruction endpoints.
app.include_router(techniques_router)

# Adds training exercise endpoints.
app.include_router(training_router)

# Adds the authentication application under /auth.
app.mount("/auth", authentication_app)


@app.get("/")
def root():
    return {"message": "Taleeq API is running"}