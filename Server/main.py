from fastapi import FastAPI

from api.assessment import router as assessment_router
from application_layer.authentication_managment.main import (
    app as authentication_app,
)


app = FastAPI(
    title="Taleeq API",
    description="Backend API for Taleeq",
    version="1.0.0",
)


# Adds the assessment endpoints.
app.include_router(assessment_router)

# Adds the authentication application under /auth.
app.mount("/auth", authentication_app)


@app.get("/")
def root():
    return {"message": "Taleeq API is running"}