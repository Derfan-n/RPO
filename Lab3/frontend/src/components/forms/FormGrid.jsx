import { FormField } from './FormField';

export function FormGrid({ fields, values, onChange }) {
  return (
    <div className="form-grid">
      {fields.map((field) => (
        <FormField key={field.key} field={field} value={values[field.key]} onChange={onChange} />
      ))}
    </div>
  );
}
