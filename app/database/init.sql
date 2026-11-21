CREATE TABLE IF NOT EXISTS lessons (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    slug VARCHAR(80) NOT NULL UNIQUE,
    title VARCHAR(120) NOT NULL,
    description TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO lessons (slug, title, description)
VALUES
    (
        'password-security',
        'Seguridad de contraseñas',
        'Buenas prácticas para crear y proteger contraseñas.'
    ),
    (
        'phishing-awareness',
        'Detección de phishing',
        'Cómo reconocer mensajes y enlaces sospechosos.'
    ),
    (
        'backup-recovery',
        'Backups y recuperación',
        'Importancia de verificar copias y procedimientos de restauración.'
    )
ON CONFLICT (slug) DO NOTHING;