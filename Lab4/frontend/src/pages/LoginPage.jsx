import { useState } from 'react';
import { api } from '../api/client';
import { TopButton } from '../components/common/TopButton';
import { FormGrid } from '../components/forms/FormGrid';

export function LoginPage({ onLogin }) {
  const [values, setValues] = useState({ login: '', password: '' });
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleChange = (key, value) => {
    setValues((current) => ({ ...current, [key]: value }));
  };

  const handleSubmit = async (event) => {
    event.preventDefault();
    setLoading(true);
    setError('');

    try {
      const data = await api('/auth/login', {
        method: 'POST',
        auth: false,
        body: {
          login: values.login.trim(),
          password: values.password,
        },
      });
      onLogin(data.token);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="auth-layout">
      <div className="auth-card auth-card-wide">
        <div className="hero-badge">React frontend</div>
        <h1>Transport Auth</h1>
        <p className="auth-text">
          Новый фронтенд на React для лабораторной работы по авторизации платежей транспортными картами.
        </p>

        <div className="auth-grid">
          <form className="stack-gap-lg" onSubmit={handleSubmit}>
            <FormGrid
              fields={[
                { key: 'login', label: 'Логин', type: 'text', required: true },
                { key: 'password', label: 'Пароль', type: 'password', required: true },
              ]}
              values={values}
              onChange={handleChange}
            />
            <TopButton type="submit" disabled={loading}>
              {loading ? 'Входим…' : 'Войти'}
            </TopButton>
            {error && <div className="inline-error">{error}</div>}
          </form>

          <aside className="auth-side-card">
            <h2>Тестовые аккаунты</h2>
            <div className="credentials-list">
              <div>
                <span className="credentials-role">Администратор</span>
                <strong>admin / admin123</strong>
              </div>
              <div>
                <span className="credentials-role">Пользователь</span>
                <strong>user / user123</strong>
              </div>
            </div>
            <ul className="feature-list">
              <li>CRUD для пользователей, ключей, карт, терминалов и транзакций</li>
              <li>Просмотр данных по JWT-роли</li>
              <li>Swagger и health доступны прямо из интерфейса</li>
              <li>UI собирается в Docker вместе с Go API и Nginx</li>
            </ul>
          </aside>
        </div>
      </div>
    </div>
  );
}
