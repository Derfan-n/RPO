import { useEffect, useState } from 'react';
import { api } from '../api/client';
import { DataTable } from '../components/common/DataTable';
import { EmptyState } from '../components/common/EmptyState';
import { Notice } from '../components/common/Notice';
import { PageFrame } from '../components/common/PageFrame';
import { StatCard } from '../components/common/StatCard';
import { TopButton } from '../components/common/TopButton';
import { formatDate } from '../utils/format';

export function UserDashboard({ claims, navigate, onLogout, notice, setNotice }) {
  const [cards, setCards] = useState([]);
  const [terminals, setTerminals] = useState([]);
  const [transactions, setTransactions] = useState([]);
  const [loading, setLoading] = useState(true);

  const loadAll = async () => {
    setLoading(true);
    try {
      const [cardsData, terminalsData, transactionsData] = await Promise.all([
        api('/cards'),
        api('/terminals'),
        api('/transactions'),
      ]);
      setCards(cardsData);
      setTerminals(terminalsData);
      setTransactions(transactionsData);
    } catch (err) {
      if (err.status === 401) {
        onLogout();
        return;
      }
      setNotice({ type: 'error', text: err.message });
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadAll();
  }, []);

  return (
    <PageFrame
      title="Пользовательская панель"
      subtitle={`Вы вошли как ${claims?.login || 'user'}. Роль: ${claims?.is_admin ? 'администратор' : 'пользователь'}.`}
      badge="JWT access"
      actions={
        <>
          <TopButton variant="ghost" onClick={() => window.open('/api/v1/swagger/index.html', '_blank')}>
            Swagger
          </TopButton>
          <TopButton variant="ghost" onClick={() => window.open('/api/v1/health', '_blank')}>
            Health
          </TopButton>
          {claims?.is_admin && (
            <TopButton variant="secondary" onClick={() => navigate('/admin')}>
              В админ-панель
            </TopButton>
          )}
          <TopButton variant="secondary" onClick={loadAll}>
            Обновить
          </TopButton>
          <TopButton variant="danger" onClick={onLogout}>
            Выйти
          </TopButton>
        </>
      }
    >
      <Notice notice={notice} onClose={() => setNotice(null)} />

      <div className="stats-grid">
        <StatCard label="Карт" value={cards.length} hint="Доступно для чтения" />
        <StatCard label="Терминалов" value={terminals.length} hint="Все установленные терминалы" />
        <StatCard label="Транзакций" value={transactions.length} hint="История операций" />
      </div>

      <div className="dashboard-grid single-column">
        <section className="panel-card">
          <div className="panel-head">
            <div>
              <h2>Транспортные карты</h2>
              <p>Данные доступны в режиме чтения для авторизованного пользователя.</p>
            </div>
          </div>
          {loading ? (
            <EmptyState>Загрузка...</EmptyState>
          ) : (
            <DataTable
              columns={[
                { key: 'id', label: 'ID' },
                { key: 'card_no', label: 'Номер карты' },
                { key: 'balance', label: 'Баланс' },
                { key: 'blocked', label: 'Заблокирована', render: (value) => (value ? 'Да' : 'Нет') },
                { key: 'owner_name', label: 'Владелец' },
                { key: 'key_id', label: 'ID ключа' },
              ]}
              rows={cards}
            />
          )}
        </section>

        <section className="panel-card">
          <div className="panel-head">
            <div>
              <h2>Терминалы</h2>
              <p>Справочник терминалов, доступный после входа в систему.</p>
            </div>
          </div>
          {loading ? (
            <EmptyState>Загрузка...</EmptyState>
          ) : (
            <DataTable
              columns={[
                { key: 'id', label: 'ID' },
                { key: 'serial_number', label: 'Серийный номер' },
                { key: 'address', label: 'Адрес' },
                { key: 'display_name', label: 'Название' },
              ]}
              rows={terminals}
            />
          )}
        </section>

        <section className="panel-card">
          <div className="panel-head">
            <div>
              <h2>Транзакции</h2>
              <p>История операций с датой и временем создания записи.</p>
            </div>
          </div>
          {loading ? (
            <EmptyState>Загрузка...</EmptyState>
          ) : (
            <DataTable
              columns={[
                { key: 'id', label: 'ID' },
                { key: 'amount', label: 'Сумма' },
                { key: 'card_id', label: 'ID карты' },
                { key: 'terminal_id', label: 'ID терминала' },
                { key: 'created_at', label: 'Создана', render: (value) => formatDate(value) },
              ]}
              rows={transactions}
            />
          )}
        </section>
      </div>
    </PageFrame>
  );
}
