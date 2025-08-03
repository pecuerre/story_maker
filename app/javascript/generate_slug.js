// Shared slug generation logic for forms
export function generateSlug(name) {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, '') // Remove special characters
    .replace(/\s+/g, '-') // Replace spaces with hyphens
    .replace(/-+/g, '-') // Replace multiple hyphens with single
    .replace(/^[-]+|[-]+$/g, ''); // Remove leading/trailing hyphens
}

export function setupSlugAutoFill(nameInputId, slugInputId) {
  const nameField = document.getElementById(nameInputId);
  const slugField = document.getElementById(slugInputId);
  if (!nameField || !slugField) return;

  nameField.addEventListener('input', function() {
    slugField.value = generateSlug(nameField.value);
  });

  // On page load, if name is filled, generate slug
  if (nameField.value) {
    slugField.value = generateSlug(nameField.value);
  }
}
