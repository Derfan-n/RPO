const API_BASE = "/api/v1";

function getToken() {
  return localStorage.getItem("token") || "";
}

function getIsAdmin() {
  return localStorage.getItem("isAdmin") === "true";
}

function setAuth(token, isAdmin) {
  localStorage.setItem("token", token);
  localStorage.setItem("isAdmin", String(isAdmin));
}

function clearAuth() {
  localStorage.removeItem("token");
  localStorage.removeItem("isAdmin");
}

function logout() {
  clearAuth();
  window.location.href = "/login.html";
}

async function api(path, options = {}) {
  const { method = "GET", body, auth = true } = options;
  const headers = {};

  if (body) {
    headers["Content-Type"] = "application/json";
  }

  if (auth) {
    headers["Authorization"] = `Bearer ${getToken()}`;
  }

  const res = await fetch(`${API_BASE}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  const text = await res.text();
  let data;

  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = text;
  }

  if (!res.ok) {
    const message =
      (data && typeof data === "object" && data.error) ||
      (typeof data === "string" ? data : `HTTP ${res.status}`);
    throw new Error(message);
  }

  return data;
}

function requireAuth(adminOnly = false) {
  const token = getToken();
  if (!token) {
    window.location.href = "/login.html";
    return false;
  }

  if (adminOnly && !getIsAdmin()) {
    window.location.href = "/terminal.html";
    return false;
  }

  return true;
}

function showMessage(el, text, isError = false) {
  el.className = isError ? "error" : "success-text";
  el.textContent = text;
}

function renderTable(containerId, items, columns, actions = []) {
  const container = document.getElementById(containerId);
  if (!container) return;

  if (!items || items.length === 0) {
    container.innerHTML = `<p class="muted">Нет данных</p>`;
    return;
  }

  const table = document.createElement("table");
  const thead = document.createElement("thead");
  const tbody = document.createElement("tbody");

  const headRow = document.createElement("tr");
  columns.forEach((col) => {
    const th = document.createElement("th");
    th.textContent = col.label;
    headRow.appendChild(th);
  });

  if (actions.length) {
    const th = document.createElement("th");
    th.textContent = "Действия";
    headRow.appendChild(th);
  }

  thead.appendChild(headRow);

  items.forEach((item) => {
    const row = document.createElement("tr");

    columns.forEach((col) => {
      const td = document.createElement("td");
      td.textContent = item[col.key];
      row.appendChild(td);
    });

    if (actions.length) {
      const td = document.createElement("td");
      actions.forEach((action) => {
        const btn = document.createElement("button");
        btn.textContent = action.label;
        btn.className = `small ${action.className || "secondary"}`;
        btn.addEventListener("click", () => action.onClick(item));
        td.appendChild(btn);
      });
      row.appendChild(td);
    }

    tbody.appendChild(row);
  });

  table.appendChild(thead);
  table.appendChild(tbody);

  container.innerHTML = "";
  container.appendChild(table);
}

async function loadMe(targetId) {
  const me = await api("/users/me");
  const el = document.getElementById(targetId);
  if (el) {
    el.textContent = `Вы вошли как: ${me.login} (${me.name}), admin=${me.is_admin}`;
  }
  return me;
}

function num(v) {
  return Number(v);
}

async function initLoginPage() {
  const form = document.getElementById("loginForm");
  if (!form) return;

  if (getToken()) {
    window.location.href = getIsAdmin() ? "/admin.html" : "/terminal.html";
    return;
  }

  const msg = document.getElementById("loginMessage");

  form.addEventListener("submit", async (e) => {
    e.preventDefault();
    msg.textContent = "";

    const login = document.getElementById("login").value.trim();
    const password = document.getElementById("password").value.trim();

    try {
      const data = await api("/auth/login", {
        method: "POST",
        body: { login, password },
        auth: false,
      });

      setAuth(data.token, data.is_admin);
      window.location.href = data.is_admin ? "/admin.html" : "/terminal.html";
    } catch (err) {
      showMessage(msg, err.message, true);
    }
  });
}

async function initTerminalPage() {
  const page = document.getElementById("terminalPage");
  if (!page) return;
  if (!requireAuth(false)) return;

  await loadMe("terminalMeInfo");

  const goAdminBtn = document.getElementById("goAdminBtn");
  if (getIsAdmin()) {
    goAdminBtn.style.display = "inline-block";
    goAdminBtn.addEventListener("click", () => {
      window.location.href = "/admin.html";
    });
  }

  document.getElementById("terminalLogoutBtn").addEventListener("click", logout);

  document.getElementById("loadKeysBtn").addEventListener("click", async () => {
    const out = document.getElementById("keysOutput");
    try {
      const data = await api("/terminal/keys");
      out.textContent = JSON.stringify(data, null, 2);
    } catch (err) {
      out.textContent = err.message;
    }
  });

  document.getElementById("authorizeForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    const out = document.getElementById("authorizeOutput");

    try {
      const data = await api("/terminal/authorize", {
        method: "POST",
        body: {
          card_no: document.getElementById("authCardNo").value.trim(),
          terminal_serial: document.getElementById("authTerminalSerial").value.trim(),
          amount: num(document.getElementById("authAmount").value),
        },
      });

      out.textContent = JSON.stringify(data, null, 2);
    } catch (err) {
      out.textContent = err.message;
    }
  });
}

async function initAdminPage() {
  const page = document.getElementById("adminPage");
  if (!page) return;
  if (!requireAuth(true)) return;

  await loadMe("meInfo");

  document.getElementById("logoutBtn").addEventListener("click", logout);
  document.getElementById("goTerminalBtn").addEventListener("click", () => {
    window.location.href = "/terminal.html";
  });
  document.getElementById("refreshAllBtn").addEventListener("click", refreshAll);

  document.getElementById("createUserBtn").addEventListener("click", async () => {
    await api("/users", {
      method: "POST",
      body: {
        login: document.getElementById("userLogin").value.trim(),
        name: document.getElementById("userName").value.trim(),
        password: document.getElementById("userPassword").value.trim(),
        is_admin: document.getElementById("userIsAdmin").checked,
      },
    });
    refreshUsers();
  });

  document.getElementById("createKeyBtn").addEventListener("click", async () => {
    await api("/keys", {
      method: "POST",
      body: {
        key_name: document.getElementById("keyName").value.trim(),
        key_value: document.getElementById("keyValue").value.trim(),
      },
    });
    refreshKeys();
  });

  document.getElementById("createCardBtn").addEventListener("click", async () => {
    await api("/cards", {
      method: "POST",
      body: {
        card_no: document.getElementById("cardNo").value.trim(),
        balance: num(document.getElementById("cardBalance").value),
        blocked: document.getElementById("cardBlocked").checked,
        owner_name: document.getElementById("cardOwnerName").value.trim(),
        key_id: num(document.getElementById("cardKeyId").value),
      },
    });
    refreshCards();
  });

  document.getElementById("createTerminalBtn").addEventListener("click", async () => {
    await api("/terminals", {
      method: "POST",
      body: {
        serial_number: document.getElementById("terminalSerial").value.trim(),
        address: document.getElementById("terminalAddress").value.trim(),
        display_name: document.getElementById("terminalDisplayName").value.trim(),
      },
    });
    refreshTerminals();
  });

  document.getElementById("createTransactionBtn").addEventListener("click", async () => {
    await api("/transactions", {
      method: "POST",
      body: {
        amount: num(document.getElementById("transactionAmount").value),
        card_id: num(document.getElementById("transactionCardId").value),
        terminal_id: num(document.getElementById("transactionTerminalId").value),
      },
    });
    refreshTransactions();
  });

  await refreshAll();
}

async function refreshAll() {
  await Promise.all([
    refreshUsers(),
    refreshKeys(),
    refreshCards(),
    refreshTerminals(),
    refreshTransactions(),
  ]);
}

async function refreshUsers() {
  const items = await api("/users");
  renderTable(
    "usersTable",
    items,
    [
      { key: "id", label: "ID" },
      { key: "login", label: "Login" },
      { key: "name", label: "Name" },
      { key: "is_admin", label: "Admin" },
    ],
    [
      {
        label: "Изменить",
        onClick: async (item) => {
          const name = prompt("Новое имя", item.name);
          if (name === null) return;

          const password = prompt("Новый пароль (можно пусто)", "");
          const adminText = prompt("is_admin (true/false)", String(item.is_admin));
          if (adminText === null) return;

          await api(`/users/${item.id}`, {
            method: "PUT",
            body: {
              name,
              ...(password ? { password } : {}),
              is_admin: adminText === "true",
            },
          });
          refreshUsers();
        },
      },
      {
        label: "Удалить",
        className: "danger",
        onClick: async (item) => {
          if (!confirm(`Удалить пользователя ${item.login}?`)) return;
          await api(`/users/${item.id}`, { method: "DELETE" });
          refreshUsers();
        },
      },
    ]
  );
}

async function refreshKeys() {
  const items = await api("/keys");
  renderTable(
    "keysTable",
    items,
    [
      { key: "id", label: "ID" },
      { key: "key_name", label: "Key Name" },
      { key: "key_value", label: "Key Value" },
    ],
    [
      {
        label: "Изменить",
        onClick: async (item) => {
          const key_name = prompt("Новое имя ключа", item.key_name);
          if (key_name === null) return;
          const key_value = prompt("Новое значение ключа", item.key_value);
          if (key_value === null) return;

          await api(`/keys/${item.id}`, {
            method: "PUT",
            body: { key_name, key_value },
          });
          refreshKeys();
        },
      },
      {
        label: "Удалить",
        className: "danger",
        onClick: async (item) => {
          if (!confirm(`Удалить ключ ${item.key_name}?`)) return;
          await api(`/keys/${item.id}`, { method: "DELETE" });
          refreshKeys();
        },
      },
    ]
  );
}

async function refreshCards() {
  const items = await api("/cards");
  renderTable(
    "cardsTable",
    items,
    [
      { key: "id", label: "ID" },
      { key: "card_no", label: "Card No" },
      { key: "balance", label: "Balance" },
      { key: "blocked", label: "Blocked" },
      { key: "owner_name", label: "Owner" },
      { key: "key_id", label: "Key ID" },
    ],
    [
      {
        label: "Изменить",
        onClick: async (item) => {
          const card_no = prompt("card_no", item.card_no);
          if (card_no === null) return;
          const balance = prompt("balance", item.balance);
          if (balance === null) return;
          const blocked = prompt("blocked (true/false)", String(item.blocked));
          if (blocked === null) return;
          const owner_name = prompt("owner_name", item.owner_name);
          if (owner_name === null) return;
          const key_id = prompt("key_id", item.key_id);
          if (key_id === null) return;

          await api(`/cards/${item.id}`, {
            method: "PUT",
            body: {
              card_no,
              balance: num(balance),
              blocked: blocked === "true",
              owner_name,
              key_id: num(key_id),
            },
          });
          refreshCards();
        },
      },
      {
        label: "Удалить",
        className: "danger",
        onClick: async (item) => {
          if (!confirm(`Удалить карту ${item.card_no}?`)) return;
          await api(`/cards/${item.id}`, { method: "DELETE" });
          refreshCards();
        },
      },
    ]
  );
}

async function refreshTerminals() {
  const items = await api("/terminals");
  renderTable(
    "terminalsTable",
    items,
    [
      { key: "id", label: "ID" },
      { key: "serial_number", label: "Serial" },
      { key: "address", label: "Address" },
      { key: "display_name", label: "Display Name" },
    ],
    [
      {
        label: "Изменить",
        onClick: async (item) => {
          const serial_number = prompt("serial_number", item.serial_number);
          if (serial_number === null) return;
          const address = prompt("address", item.address);
          if (address === null) return;
          const display_name = prompt("display_name", item.display_name);
          if (display_name === null) return;

          await api(`/terminals/${item.id}`, {
            method: "PUT",
            body: { serial_number, address, display_name },
          });
          refreshTerminals();
        },
      },
      {
        label: "Удалить",
        className: "danger",
        onClick: async (item) => {
          if (!confirm(`Удалить терминал ${item.serial_number}?`)) return;
          await api(`/terminals/${item.id}`, { method: "DELETE" });
          refreshTerminals();
        },
      },
    ]
  );
}

async function refreshTransactions() {
  const items = await api("/transactions");
  renderTable(
    "transactionsTable",
    items,
    [
      { key: "id", label: "ID" },
      { key: "amount", label: "Amount" },
      { key: "card_id", label: "Card ID" },
      { key: "terminal_id", label: "Terminal ID" },
      { key: "created_at", label: "Created At" },
    ],
    [
      {
        label: "Изменить",
        onClick: async (item) => {
          const amount = prompt("amount", item.amount);
          if (amount === null) return;
          const card_id = prompt("card_id", item.card_id);
          if (card_id === null) return;
          const terminal_id = prompt("terminal_id", item.terminal_id);
          if (terminal_id === null) return;

          await api(`/transactions/${item.id}`, {
            method: "PUT",
            body: {
              amount: num(amount),
              card_id: num(card_id),
              terminal_id: num(terminal_id),
            },
          });
          refreshTransactions();
        },
      },
      {
        label: "Удалить",
        className: "danger",
        onClick: async (item) => {
          if (!confirm(`Удалить транзакцию ${item.id}?`)) return;
          await api(`/transactions/${item.id}`, { method: "DELETE" });
          refreshTransactions();
        },
      },
    ]
  );
}

document.addEventListener("DOMContentLoaded", async () => {
  try {
    await initLoginPage();
    await initAdminPage();
    await initTerminalPage();
  } catch (err) {
    console.error(err);
    alert(err.message);
  }
});