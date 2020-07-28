CREATE TABLE lists (
    id   serial PRIMARY KEY,
    name text   UNIQUE NOT NULL
);

CREATE TABLE todos (
    id       serial  PRIMARY KEY,
    name     text    NOT NULL,
    list_id  int     NOT NULL    REFERENCES lists (id) ON DELETE CASCADE,
    complete boolean NOT NULL    DEFAULT false
);
