import os

import psycopg
from flask import Flask, render_template
from psycopg.rows import dict_row


app = Flask(__name__)


def get_database_connection():
    return psycopg.connect(
        host=os.environ["DB_HOST"],
        port=os.environ.get("DB_PORT", "5432"),
        dbname=os.environ["DB_NAME"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        connect_timeout=5,
        row_factory=dict_row,
    )


@app.get("/")
def index():
    with get_database_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT id, slug, title, description, created_at
                FROM lessons
                ORDER BY id
                """
            )
            lessons = cursor.fetchall()

    return render_template("index.html", lessons=lessons)


@app.get("/health")
def health():
    try:
        with get_database_connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1")

        return {"status": "ok"}, 200

    except Exception:
        app.logger.exception("Database health check failed")
        return {"status": "error"}, 503