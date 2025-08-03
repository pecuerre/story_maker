// Taxonomy show page JS (migrated from inline script)

function testJavaScript() {
  console.log('JavaScript is working!');
  return true;
}

function loadTaxonTree(taxonomySlug, taxonomyId) {
  const container = document.getElementById('taxon-tree-container');
  container.innerHTML = '<div class="text-center"><div class="spinner-border" role="status"></div></div>';

  console.log('Loading taxons for taxonomy:', taxonomyId);

  fetch(`/t/${taxonomySlug}/taxons.json`, {
    signal: AbortSignal.timeout(5000)
  })
    .then(response => {
      console.log('Response status:', response.status);
      return response.json();
    })
    .then(taxons => {
      console.log('Received taxons:', taxons);
      container.innerHTML = renderTaxonTree(taxons, taxonomySlug);
      const fallback = document.getElementById('fallback-taxon-tree');
      if (fallback) fallback.style.display = 'none';
    })
    .catch(error => {
      console.error('Error loading taxons:', error);
      const fallback = document.getElementById('fallback-taxon-tree');
      if (fallback) {
        fallback.style.display = 'block';
        container.innerHTML = '';
      } else {
        container.innerHTML = '<div class="alert alert-danger">Error loading taxons: ' + error.message + '</div>';
      }
    });
}

function renderTaxonTree(taxons, taxonomySlug) {
  if (!taxons || taxons.length === 0) {
    return '<p class="text-muted">No taxons found. Create the first taxon to get started.</p>';
  }
  return '<div class="taxon-tree">' + taxons.map(taxon => renderTaxonNode(taxon, taxonomySlug)).join('') + '</div>';
}

function renderTaxonNode(taxon, taxonomySlug) {
  const hasChildren = taxon.children && taxon.children.length > 0;
  const isRoot = !taxon.parent_id;
  return `
    <div class="taxon-node" data-taxon-id="${taxon.id}">
      <div class="taxon-item d-flex align-items-center p-2 border-bottom">
        <div class="taxon-toggle me-2" onclick="toggleTaxon(${taxon.id})" style="cursor: pointer;">
          <i class="bi bi-chevron-${hasChildren ? 'down' : 'right'} text-muted"></i>
        </div>
        <div class="taxon-icon me-2">
          <i class="bi bi-${hasChildren ? 'folder' : 'tag'} text-primary"></i>
        </div>
        <div class="taxon-content flex-grow-1">
          <span class="taxon-name">${taxon.name}</span>
          ${isRoot ? '<span class="badge bg-info ms-2">Root</span>' : ''}
        </div>
        <div class="taxon-actions">
          <div class="btn-group btn-group-sm" role="group">
            <button type="button" class="btn btn-outline-primary btn-sm" onclick="addChildTaxon(${taxon.id}, '${taxonomySlug}')">
              <i class="bi bi-plus"></i>
            </button>
            <button type="button" class="btn btn-outline-secondary btn-sm" onclick="editTaxon(${taxon.id}, '${taxonomySlug}')">
              <i class="bi bi-pencil"></i>
            </button>
            ${!isRoot ? `<button type="button" class="btn btn-outline-danger btn-sm" onclick="deleteTaxon(${taxon.id}, '${taxonomySlug}')">
              <i class="bi bi-trash"></i>
            </button>` : ''}
          </div>
        </div>
      </div>
      ${hasChildren ? `<div class="taxon-children ms-4" id="children-${taxon.id}">
        ${taxon.children.map(child => renderTaxonNode(child, taxonomySlug)).join('')}
      </div>` : ''}
    </div>
  `;
}

window.toggleTaxon = function(taxonId) {
  const children = document.getElementById(`children-${taxonId}`);
  const toggle = document.querySelector(`[data-taxon-id="${taxonId}"] .taxon-toggle i`);
  if (children) {
    children.style.display = children.style.display === 'none' ? 'block' : 'none';
    toggle.className = children.style.display === 'none' ? 'bi bi-chevron-right text-muted' : 'bi bi-chevron-down text-muted';
  }
}

window.expandAll = function() {
  document.querySelectorAll('.taxon-children').forEach(children => {
    children.style.display = 'block';
  });
  document.querySelectorAll('.taxon-toggle i').forEach(toggle => {
    toggle.className = 'bi bi-chevron-down text-muted';
  });
}

window.collapseAll = function() {
  document.querySelectorAll('.taxon-children').forEach(children => {
    children.style.display = 'none';
  });
  document.querySelectorAll('.taxon-toggle i').forEach(toggle => {
    toggle.className = 'bi bi-chevron-right text-muted';
  });
}

window.addChildTaxon = function(parentId, taxonomySlug) {
  window.location.href = `/t/${taxonomySlug}/taxons/new?parent_id=${parentId}`;
}

window.editTaxon = function(taxonId, taxonomySlug) {
  window.location.href = `/t/${taxonomySlug}/taxons/${taxonId}/edit`;
}

window.deleteTaxon = function(taxonId, taxonomySlug) {
  if (confirm('Are you sure you want to delete this taxon? This will also delete all its children.')) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content ||
                     document.querySelector('input[name="authenticity_token"]')?.value;
    fetch(`/t/${taxonomySlug}/taxons/${taxonId}`, {
      method: 'DELETE',
      headers: {
        'X-CSRF-Token': csrfToken,
        'Content-Type': 'application/json'
      }
    })
    .then(response => {
      if (response.ok) {
        loadTaxonTree(taxonomySlug, taxonId);
      } else {
        response.json().then(data => {
          alert('Error deleting taxon: ' + (data.error || 'Unknown error'));
        }).catch(() => {
          alert('Error deleting taxon');
        });
      }
    })
    .catch(error => {
      console.error('Error:', error);
      alert('Error deleting taxon: ' + error.message);
    });
  }
}

export function initTaxonomyShowPage(taxonomySlug, taxonomyId) {
  document.addEventListener('DOMContentLoaded', function() {
    if (testJavaScript()) {
      loadTaxonTree(taxonomySlug, taxonomyId);
    }
  });
}
