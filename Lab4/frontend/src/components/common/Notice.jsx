import { clsx } from '../../utils/clsx';

export function Notice({ notice, onClose }) {
  if (!notice) return null;

  return (
    <div className={clsx('notice', notice.type === 'error' ? 'notice-error' : 'notice-success')}>
      <span>{notice.text}</span>
      <button className="notice-close" onClick={onClose} type="button" aria-label="Закрыть">
        ×
      </button>
    </div>
  );
}
