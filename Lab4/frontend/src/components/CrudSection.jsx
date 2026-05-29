import { useState } from 'react';
import { makeFormState, normalizePayload } from '../utils/forms';
import { DataTable } from './common/DataTable';
import { Modal } from './common/Modal';
import { TopButton } from './common/TopButton';
import { FormGrid } from './forms/FormGrid';

export function CrudSection({
  title,
  description,
  createFields,
  editFields = createFields,
  columns,
  items,
  onCreate,
  onUpdate,
  onDelete,
  emptyText,
}) {
  const [createValues, setCreateValues] = useState(() => makeFormState(createFields));
  const [editingItem, setEditingItem] = useState(null);
  const [editValues, setEditValues] = useState(() => makeFormState(editFields));
  const [submitting, setSubmitting] = useState(false);

  const updateCreateValue = (key, value) => {
    setCreateValues((current) => ({ ...current, [key]: value }));
  };

  const updateEditValue = (key, value) => {
    setEditValues((current) => ({ ...current, [key]: value }));
  };

  const openEditor = (item) => {
    setEditingItem(item);
    setEditValues(makeFormState(editFields, item));
  };

  const handleCreate = async (event) => {
    event.preventDefault();
    setSubmitting(true);
    try {
      await onCreate(normalizePayload(createFields, createValues));
      setCreateValues(makeFormState(createFields));
    } catch {
      // Сообщение об ошибке показывает родительский компонент.
    } finally {
      setSubmitting(false);
    }
  };

  const handleEdit = async (event) => {
    event.preventDefault();
    if (!editingItem) return;

    setSubmitting(true);
    try {
      await onUpdate(editingItem, normalizePayload(editFields, editValues));
      setEditingItem(null);
    } catch {
      // Сохраняем форму открытой, чтобы пользователь мог исправить данные.
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <section className="panel-card">
      <div className="panel-head">
        <div>
          <h2>{title}</h2>
          {description && <p>{description}</p>}
        </div>
      </div>

      <form onSubmit={handleCreate} className="stack-gap-lg">
        <FormGrid fields={createFields} values={createValues} onChange={updateCreateValue} />
        <div className="section-actions">
          <TopButton type="submit" disabled={submitting}>
            Создать
          </TopButton>
        </div>
      </form>

      <DataTable
        columns={columns}
        rows={items}
        emptyText={emptyText}
        actions={[
          { label: 'Изменить', onClick: openEditor },
          {
            label: 'Удалить',
            variant: 'danger',
            onClick: async (item) => {
              if (!window.confirm(`Удалить запись #${item.id}?`)) return;
              try {
                await onDelete(item);
              } catch {
                // Сообщение об ошибке уже показано выше.
              }
            },
          },
        ]}
      />

      {editingItem && (
        <Modal
          title={`Редактирование: ${title}`}
          subtitle={`ID: ${editingItem.id}`}
          onClose={() => setEditingItem(null)}
        >
          <form onSubmit={handleEdit} className="stack-gap-lg">
            <FormGrid fields={editFields} values={editValues} onChange={updateEditValue} />
            <div className="modal-actions">
              <TopButton type="button" variant="ghost" onClick={() => setEditingItem(null)}>
                Отмена
              </TopButton>
              <TopButton type="submit" disabled={submitting}>
                Сохранить
              </TopButton>
            </div>
          </form>
        </Modal>
      )}
    </section>
  );
}
