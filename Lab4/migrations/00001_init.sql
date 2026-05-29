-- +goose Up
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    login TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    password TEXT NOT NULL,
    is_admin BOOLEAN NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key_name TEXT NOT NULL,
    key_value TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS cards (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    card_no TEXT NOT NULL UNIQUE,
    balance REAL NOT NULL DEFAULT 0,
    blocked BOOLEAN NOT NULL DEFAULT 0,
    owner_name TEXT NOT NULL,
    key_id INTEGER NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (key_id) REFERENCES keys(id)
);

CREATE TABLE IF NOT EXISTS terminals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    serial_number TEXT NOT NULL UNIQUE,
    address TEXT NOT NULL,
    display_name TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS transactions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    amount REAL NOT NULL,
    card_id INTEGER NOT NULL,
    terminal_id INTEGER NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (card_id) REFERENCES cards(id),
    FOREIGN KEY (terminal_id) REFERENCES terminals(id)
);

INSERT INTO users (login, name, password, is_admin)
VALUES
    ('admin', 'Admin User', 'admin123', 1),
    ('user', 'Regular User', 'user123', 0);

INSERT INTO keys (key_name, key_value)
VALUES
    ('MIFARE_KEY_A_DEFAULT', 'FFFFFFFFFFFF'),
    ('MIFARE_KEY_B_DEFAULT', 'FFFFFFFFFFFF');

INSERT INTO cards (card_no, balance, blocked, owner_name, key_id)
VALUES
    ('84f07c05', 500.00, 0, 'Kirill MIFARE Demo', 1),
    ('b754105e', 500.00, 0, 'Test Passenger', 1);

INSERT INTO terminals (serial_number, address, display_name)
VALUES
    ('TERM-001', 'MacBook lab', 'PN532 terminal');

-- +goose Down
DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS terminals;
DROP TABLE IF EXISTS cards;
DROP TABLE IF EXISTS keys;
DROP TABLE IF EXISTS users;
