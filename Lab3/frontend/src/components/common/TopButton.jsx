import { clsx } from '../../utils/clsx';

export function TopButton({ children, variant = 'primary', ...props }) {
  return (
    <button className={clsx('button', `button-${variant}`)} {...props}>
      {children}
    </button>
  );
}
