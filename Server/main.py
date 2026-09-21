from fastapi import FastAPI

from api.assessment import router as assessment_router


app = FastAPI(
    title="Taleeq API",
    description="Backend API for Taleeq",
    version="1.0.0",
)


app.include_router(assessment_router)


@app.get("/")
def root():
    return {"message": "Taleeq API is running"}