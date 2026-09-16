from dotenv import load_dotenv
from sqlalchemy import create_engine, text
import os

load_dotenv()

database_url = os.getenv("DATABASE_URL")

if not database_url:
    print("DATABASE_URL not found. Check your .env file.")
else:
    try:
        engine = create_engine(database_url)
        with engine.connect() as connection:
            result = connection.execute(text("SELECT 1"))
            print("Connection successful! Result:", result.fetchone())
    except Exception as e:
        print("Connection failed:")
        print(e)