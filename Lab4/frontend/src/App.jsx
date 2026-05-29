import { useEffect, useMemo, useState } from 'react';
import { LoginPage } from './pages/LoginPage';
import { AdminDashboard } from './pages/AdminDashboard';
import { UserDashboard } from './pages/UserDashboard';
import { usePathname } from './hooks/usePathname';
import { clearToken, getToken, parseJwt, setToken } from './utils/auth';

export function App() {
  const [pathname, navigate] = usePathname();
  const [token, setTokenState] = useState(() => getToken());
  const [notice, setNotice] = useState(null);

  const claims = useMemo(() => parseJwt(token), [token]);
  const isAuthenticated = Boolean(token && claims);
  const isAdmin = Boolean(claims?.is_admin);

  useEffect(() => {
    if (!isAuthenticated && pathname !== '/login') {
      navigate('/login', true);
      return;
    }

    if (isAuthenticated && pathname === '/login') {
      navigate(isAdmin ? '/admin' : '/dashboard', true);
      return;
    }

    if (isAuthenticated && pathname === '/admin' && !isAdmin) {
      navigate('/dashboard', true);
    }
  }, [pathname, isAuthenticated, isAdmin, navigate]);

  const handleLogin = (nextToken) => {
    setToken(nextToken);
    setTokenState(nextToken);
    setNotice(null);
    const nextClaims = parseJwt(nextToken);
    navigate(nextClaims?.is_admin ? '/admin' : '/dashboard', true);
  };

  const handleLogout = () => {
    clearToken();
    setTokenState('');
    setNotice(null);
    navigate('/login', true);
  };

  if (!isAuthenticated || pathname === '/login') {
    return <LoginPage onLogin={handleLogin} />;
  }

  if (isAdmin && pathname === '/admin') {
    return (
      <AdminDashboard
        claims={claims}
        navigate={navigate}
        onLogout={handleLogout}
        notice={notice}
        setNotice={setNotice}
      />
    );
  }

  return (
    <UserDashboard
      claims={claims}
      navigate={navigate}
      onLogout={handleLogout}
      notice={notice}
      setNotice={setNotice}
    />
  );
}
