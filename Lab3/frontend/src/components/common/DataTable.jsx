import { clsx } from '../../utils/clsx';
import { EmptyState } from './EmptyState';

export function DataTable({ columns, rows, actions = [], emptyText = 'Нет данных' }) {
  if (!rows.length) {
    return <EmptyState>{emptyText}</EmptyState>;
  }

  return (
    <div className="table-wrap">
      <table>
        <thead>
          <tr>
            {columns.map((column) => (
              <th key={column.key}>{column.label}</th>
            ))}
            {actions.length > 0 && <th>Действия</th>}
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr key={row.id ?? JSON.stringify(row)}>
              {columns.map((column) => (
                <td key={column.key}>
                  {column.render ? column.render(row[column.key], row) : String(row[column.key] ?? '—')}
                </td>
              ))}
              {actions.length > 0 && (
                <td>
                  <div className="table-actions">
                    {actions.map((action) => (
                      <button
                        key={action.label}
                        type="button"
                        className={clsx('chip-button', action.variant === 'danger' ? 'chip-button-danger' : '')}
                        onClick={() => action.onClick(row)}
                      >
                        {action.label}
                      </button>
                    ))}
                  </div>
                </td>
              )}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
