export function formatJson(value) {
  if (value === null || value === undefined) return 'Нет данных';
  return JSON.stringify(value, null, 2);
}

export function formatDate(value) {
  if (!value) return '—';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return date.toLocaleString('ru-RU');
}
