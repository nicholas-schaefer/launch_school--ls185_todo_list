CREATE TABLE lists (
    id serial PRIMARY KEY,
    name varchar(250) NOT NULL UNIQUE
);

CREATE TABLE todos (
    id serial PRIMARY KEY,
    name text NOT NULL,
    completed boolean NOT NULL DEFAULT false,
    list_id integer NOT NULL references lists(id)
)

