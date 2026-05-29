import { useEffect, useState } from 'react';
import { api } from '../api/client';
import { CrudSection } from '../components/CrudSection';
import { EmptyState } from '../components/common/EmptyState';
import { Notice } from '../components/common/Notice';
import { PageFrame } from '../components/common/PageFrame';
import { StatCard } from '../components/common/StatCard';
import { TopButton } from '../components/common/TopButton';
import { FormGrid } from '../components/forms/FormGrid';
import {
  cardFields,
  keyFields,
  terminalFields,
  transactionFields,
  userCreateFields,
  userEditFields,
} from '../constants/forms';
import { formatDate, formatJson } from '../utils/format';

export function AdminDashboard({ claims, navigate, onLogout, notice, setNotice }) {
  const [users, setUsers] = useState([]);
  const [keys, setKeys] = useState([]);
  const [cards, setCards] = useState([]);
  const [terminals, setTerminals] = useState([]);
  const [transactions, setTransactions] = useState([]);
  const [me, setMe] = useState(null);
  const [terminalAuthForm, setTerminalAuthForm] = useState({ card_no: '', terminal_serial: '', amount: '' });
  const [keysPayload, setKeysPayload] = useState(null);
  const [authPayload, setAuthPayload] = useState(null);
  const [loading, setLoading] = useState(true);

  const withFeedback = async (action, successText) => {
    try {
      await action();
      if (successText) {
        setNotice({ type: 'success', text: successText });
      }
    } catch (err) {
      if (err.status === 401) {
        onLogout();
        return;
      }
      setNotice({ type: 'error', text: err.message });
      throw err;
    }
  };

  const loadUsers = () => api('/users').then(setUsers);
  const loadKeys = () => api('/keys').then(setKeys);
  const loadCards = () => api('/cards').then(setCards);
  const loadTerminals = () => api('/terminals').then(setTerminals);
  const loadTransactions = () => api('/transactions').then(setTransactions);
  const loadMe = () => api('/users/me').then(setMe);

  const refreshAll = async () => {
    setLoading(true);
    try {
      await Promise.all([loadUsers(), loadKeys(), loadCards(), loadTerminals(), loadTransactions(), loadMe()]);
    } catch (err) {
      setNotice({ type: 'error', text: err.message });
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    refreshAll();
  }, []);

  const createUser = (payload) =>
    withFeedback(async () => {
      await api('/users', { method: 'POST', body: payload });
      await loadUsers();
    }, 'Пользователь создан');

  const updateUser = (item, payload) =>
    withFeedback(async () => {
      await api(`/users/${item.id}`, { method: 'PUT', body: payload });
      await Promise.all([loadUsers(), loadMe()]);
    }, 'Пользователь обновлён');

  const deleteUser = (item) =>
    withFeedback(async () => {
      await api(`/users/${item.id}`, { method: 'DELETE' });
      await Promise.all([loadUsers(), loadMe()]);
    }, 'Пользователь удалён');

  const createKey = (payload) =>
    withFeedback(async () => {
      await api('/keys', { method: 'POST', body: payload });
      await loadKeys();
    }, 'Ключ создан');

  const updateKey = (item, payload) =>
    withFeedback(async () => {
      await api(`/keys/${item.id}`, { method: 'PUT', body: payload });
      await loadKeys();
    }, 'Ключ обновлён');

  const deleteKey = (item) =>
    withFeedback(async () => {
      await api(`/keys/${item.id}`, { method: 'DELETE' });
      await loadKeys();
    }, 'Ключ удалён');

  const createCard = (payload) =>
    withFeedback(async () => {
      await api('/cards', { method: 'POST', body: payload });
      await loadCards();
    }, 'Карта создана');

  const updateCard = (item, payload) =>
    withFeedback(async () => {
      await api(`/cards/${item.id}`, { method: 'PUT', body: payload });
      await loadCards();
    }, 'Карта обновлена');

  const deleteCard = (item) =>
    withFeedback(async () => {
      await api(`/cards/${item.id}`, { method: 'DELETE' });
      await loadCards();
    }, 'Карта удалена');

  const createTerminal = (payload) =>
    withFeedback(async () => {
      await api('/terminals', { method: 'POST', body: payload });
      await loadTerminals();
    }, 'Терминал создан');

  const updateTerminal = (item, payload) =>
    withFeedback(async () => {
      await api(`/terminals/${item.id}`, { method: 'PUT', body: payload });
      await loadTerminals();
    }, 'Терминал обновлён');

  const deleteTerminal = (item) =>
    withFeedback(async () => {
      await api(`/terminals/${item.id}`, { method: 'DELETE' });
      await loadTerminals();
    }, 'Терминал удалён');

  const createTransaction = (payload) =>
    withFeedback(async () => {
      await api('/transactions', { method: 'POST', body: payload });
      await loadTransactions();
    }, 'Транзакция создана');

  const updateTransaction = (item, payload) =>
    withFeedback(async () => {
      await api(`/transactions/${item.id}`, { method: 'PUT', body: payload });
      await loadTransactions();
    }, 'Транзакция обновлена');

  const deleteTransaction = (item) =>
    withFeedback(async () => {
      await api(`/transactions/${item.id}`, { method: 'DELETE' });
      await loadTransactions();
    }, 'Транзакция удалена');

  const loadTerminalKeys = async () => {
    await withFeedback(async () => {
      const data = await api('/terminal/keys');
      setKeysPayload(data);
    }, 'Ключи терминала загружены');
  };

  const authorizeTerminalPayment = async (event) => {
    event.preventDefault();
    await withFeedback(async () => {
      const data = await api('/terminal/authorize', {
        method: 'POST',
        body: {
          card_no: terminalAuthForm.card_no.trim(),
          terminal_serial: terminalAuthForm.terminal_serial.trim(),
          amount: terminalAuthForm.amount === '' ? 0 : Number(terminalAuthForm.amount),
        },
      });
      setAuthPayload(data);
    }, 'Запрос на авторизацию выполнен');
  };

  return (
    <PageFrame
      title="Админ-панель"
      subtitle={`В системе: ${me?.login || claims?.login || 'admin'}${me?.name ? ` — ${me.name}` : ''}. Полный CRUD и terminal API доступны из одного React UI.`}
      badge="Admin access"
      actions={
        <>
          <TopButton variant="ghost" onClick={() => window.open('/api/v1/swagger/index.html', '_blank')}>
            Swagger
          </TopButton>
          <TopButton variant="ghost" onClick={() => window.open('/api/v1/health', '_blank')}>
            Health
          </TopButton>
          <TopButton variant="secondary" onClick={() => navigate('/dashboard')}>
            Пользовательский вид
          </TopButton>
          <TopButton variant="secondary" onClick={refreshAll}>
            Обновить всё
          </TopButton>
          <TopButton variant="danger" onClick={onLogout}>
            Выйти
          </TopButton>
        </>
      }
    >
      <Notice notice={notice} onClose={() => setNotice(null)} />

      <div className="stats-grid">
        <StatCard label="Пользователей" value={users.length} hint="Полный CRUD" />
        <StatCard label="Ключей" value={keys.length} hint="MIFARE keys" />
        <StatCard label="Карт" value={cards.length} hint="Транспортные карты" />
        <StatCard label="Терминалов" value={terminals.length} hint="Точки установки" />
        <StatCard label="Транзакций" value={transactions.length} hint="Платёжные операции" />
      </div>

      {loading ? (
        <section className="panel-card">
          <EmptyState>Загрузка данных из API...</EmptyState>
        </section>
      ) : (
        <div className="dashboard-grid">
          <CrudSection
            title="Пользователи"
            description="Администратор может создавать, редактировать и удалять пользователей системы."
            createFields={userCreateFields}
            editFields={userEditFields}
            columns={[
              { key: 'id', label: 'ID' },
              { key: 'login', label: 'Логин' },
              { key: 'name', label: 'Имя' },
              { key: 'is_admin', label: 'Админ', render: (value) => (value ? 'Да' : 'Нет') },
            ]}
            items={users}
            onCreate={createUser}
            onUpdate={updateUser}
            onDelete={deleteUser}
            emptyText="Пользователи ещё не созданы"
          />

          <CrudSection
            title="Ключи"
            description="CRUD для таблицы ключей, связанных отношением один ко многим с картами."
            createFields={keyFields}
            columns={[
              { key: 'id', label: 'ID' },
              { key: 'key_name', label: 'Название' },
              { key: 'key_value', label: 'Значение' },
            ]}
            items={keys}
            onCreate={createKey}
            onUpdate={updateKey}
            onDelete={deleteKey}
            emptyText="Ключи отсутствуют"
          />

          <CrudSection
            title="Карты"
            description="Управление транспортными картами MIFARE: баланс, владелец, блокировка и ключ."
            createFields={cardFields}
            columns={[
              { key: 'id', label: 'ID' },
              { key: 'card_no', label: 'Номер карты' },
              { key: 'balance', label: 'Баланс' },
              { key: 'blocked', label: 'Блок', render: (value) => (value ? 'Да' : 'Нет') },
              { key: 'owner_name', label: 'Владелец' },
              { key: 'key_id', label: 'ID ключа' },
            ]}
            items={cards}
            onCreate={createCard}
            onUpdate={updateCard}
            onDelete={deleteCard}
            emptyText="Карты отсутствуют"
          />

          <CrudSection
            title="Терминалы"
            description="CRUD для терминалов с серийным номером, адресом и отображаемым названием."
            createFields={terminalFields}
            columns={[
              { key: 'id', label: 'ID' },
              { key: 'serial_number', label: 'Серийный номер' },
              { key: 'address', label: 'Адрес' },
              { key: 'display_name', label: 'Название' },
            ]}
            items={terminals}
            onCreate={createTerminal}
            onUpdate={updateTerminal}
            onDelete={deleteTerminal}
            emptyText="Терминалы отсутствуют"
          />

          <CrudSection
            title="Транзакции"
            description="Управление транзакциями, связанными с картами и терминалами."
            createFields={transactionFields}
            columns={[
              { key: 'id', label: 'ID' },
              { key: 'amount', label: 'Сумма' },
              { key: 'card_id', label: 'ID карты' },
              { key: 'terminal_id', label: 'ID терминала' },
              { key: 'created_at', label: 'Создана', render: (value) => formatDate(value) },
            ]}
            items={transactions}
            onCreate={createTransaction}
            onUpdate={updateTransaction}
            onDelete={deleteTransaction}
            emptyText="Транзакции отсутствуют"
          />

          <section className="panel-card panel-card-wide">
            <div className="panel-head">
              <div>
                <h2>Terminal API</h2>
                <p>Проверка авторизации транзакции и выгрузка ключей терминалу прямо из интерфейса.</p>
              </div>
            </div>

            <div className="terminal-tools-grid">
              <div className="terminal-tool-card">
                <h3>Загрузка ключей</h3>
                <p>GET /api/v1/terminal/keys</p>
                <TopButton onClick={loadTerminalKeys}>Получить ключи</TopButton>
                <pre>{formatJson(keysPayload)}</pre>
              </div>

              <div className="terminal-tool-card">
                <h3>Авторизация транзакции</h3>
                <p>POST /api/v1/terminal/authorize</p>
                <form className="stack-gap-lg" onSubmit={authorizeTerminalPayment}>
                  <FormGrid
                    fields={[
                      { key: 'card_no', label: 'Номер карты', type: 'text', required: true },
                      { key: 'terminal_serial', label: 'Серийный номер терминала', type: 'text', required: true },
                      { key: 'amount', label: 'Сумма', type: 'number', step: '0.01', required: true },
                    ]}
                    values={terminalAuthForm}
                    onChange={(key, value) => setTerminalAuthForm((current) => ({ ...current, [key]: value }))}
                  />
                  <TopButton type="submit">Авторизовать</TopButton>
                </form>
                <pre>{formatJson(authPayload)}</pre>
              </div>
            </div>
          </section>
        </div>
      )}
    </PageFrame>
  );
}
