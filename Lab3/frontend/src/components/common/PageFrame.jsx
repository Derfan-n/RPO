export function PageFrame({ title, subtitle, badge, actions, children }) {
  return (
    <div className="page-shell">
      <div className="hero-card">
        <div>
          <div className="hero-badge">{badge}</div>
          <h1>{title}</h1>
          <p>{subtitle}</p>
        </div>
        <div className="hero-actions">{actions}</div>
      </div>
      {children}
    </div>
  );
}
