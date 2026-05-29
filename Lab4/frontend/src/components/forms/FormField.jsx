export function FormField({ field, value, onChange }) {
  if (field.type === 'checkbox') {
    return (
      <label className="checkbox-field">
        <input
          type="checkbox"
          checked={Boolean(value)}
          onChange={(event) => onChange(field.key, event.target.checked)}
        />
        <span>{field.label}</span>
      </label>
    );
  }

  return (
    <label className="form-field">
      <span>{field.label}</span>
      <input
        type={field.type || 'text'}
        value={value}
        min={field.min}
        step={field.step}
        required={field.required}
        placeholder={field.placeholder || field.label}
        onChange={(event) => onChange(field.key, event.target.value)}
      />
    </label>
  );
}
