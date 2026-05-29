export function getDefaultValue(field, source) {
  if (source && source[field.key] !== undefined && source[field.key] !== null) {
    return source[field.key];
  }

  if (field.type === 'checkbox') return false;
  return '';
}

export function makeFormState(fields, source = null) {
  return fields.reduce((acc, field) => {
    acc[field.key] = getDefaultValue(field, source);
    return acc;
  }, {});
}

export function normalizePayload(fields, values) {
  return fields.reduce((acc, field) => {
    const raw = values[field.key];

    if (field.type === 'checkbox') {
      acc[field.key] = Boolean(raw);
      return acc;
    }

    if (field.type === 'number') {
      acc[field.key] = raw === '' ? 0 : Number(raw);
      return acc;
    }

    if (field.type === 'password') {
      if (raw) {
        acc[field.key] = String(raw);
      }
      return acc;
    }

    acc[field.key] = typeof raw === 'string' ? raw.trim() : raw;
    return acc;
  }, {});
}
