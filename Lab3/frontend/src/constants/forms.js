export const userCreateFields = [
  { key: 'login', label: 'Логин', type: 'text', required: true },
  { key: 'name', label: 'Имя', type: 'text', required: true },
  { key: 'password', label: 'Пароль', type: 'password', required: true },
  { key: 'is_admin', label: 'Администратор', type: 'checkbox' },
];

export const userEditFields = [
  { key: 'name', label: 'Имя', type: 'text' },
  { key: 'password', label: 'Новый пароль', type: 'password' },
  { key: 'is_admin', label: 'Администратор', type: 'checkbox' },
];

export const keyFields = [
  { key: 'key_name', label: 'Название ключа', type: 'text', required: true },
  { key: 'key_value', label: 'Значение ключа', type: 'text', required: true },
];

export const cardFields = [
  { key: 'card_no', label: 'Номер карты', type: 'text', required: true },
  { key: 'balance', label: 'Баланс', type: 'number', step: '0.01', required: true },
  { key: 'owner_name', label: 'Владелец', type: 'text', required: true },
  { key: 'key_id', label: 'ID ключа', type: 'number', required: true },
  { key: 'blocked', label: 'Заблокирована', type: 'checkbox' },
];

export const terminalFields = [
  { key: 'serial_number', label: 'Серийный номер', type: 'text', required: true },
  { key: 'address', label: 'Адрес', type: 'text', required: true },
  { key: 'display_name', label: 'Название', type: 'text', required: true },
];

export const transactionFields = [
  { key: 'amount', label: 'Сумма', type: 'number', step: '0.01', required: true },
  { key: 'card_id', label: 'ID карты', type: 'number', required: true },
  { key: 'terminal_id', label: 'ID терминала', type: 'number', required: true },
];
