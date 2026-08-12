export const SCHEMA_VERSION = 1
export const PROJECT_STATES = new Set(['greenfield', 'established', 'mixed', 'legacy'])
export const DIRECTION_STATUSES = new Set(['unset', 'candidate', 'adopted'])
export const DECISION_STATUSES = new Set([
  'observed',
  'candidate',
  'adopted',
  'component-enforced',
  'ci-enforced',
  'retired',
])
export const SOURCE_TYPES = new Set([
  'user-decision',
  'local-code',
  'local-incident',
  'external-precedent',
])
export const ENFORCEMENT_TYPES = new Set([
  'component', 'static', 'unit', 'a11y', 'browser', 'ci',
])

const ADOPTED_STATUSES = new Set(['adopted', 'component-enforced', 'ci-enforced'])
const KEBAB_CASE = /^[a-z0-9]+(?:-[a-z0-9]+)*$/
const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/

function isSafeRelativePath(value) {
  if (typeof value !== 'string' || value.trim() === '') return false
  if (value.startsWith('/') || /^[A-Za-z]:[\\/]/.test(value)) return false
  const normalized = value.replace(/\\/g, '/').split('/').filter(Boolean)
  return normalized[0] !== '..' && !normalized.includes('..')
}

export function validateDesignData(data) {
  const errors = []
  const add = (code, path, message) => errors.push({ code, path, message })

  if (!data || typeof data !== 'object' || Array.isArray(data)) {
    add('DESIGN_E_ROOT', '/', 'data must be an object')
    return errors
  }
  if (data.schemaVersion !== SCHEMA_VERSION) {
    add('DESIGN_E_SCHEMA', '/schemaVersion', `expected ${SCHEMA_VERSION}`)
  }
  if (!PROJECT_STATES.has(data.project?.state)) {
    add('DESIGN_E_PROJECT_STATE', '/project/state', 'unknown project state')
  }
  if (!DIRECTION_STATUSES.has(data.project?.directionStatus)) {
    add('DESIGN_E_DIRECTION_STATUS', '/project/directionStatus', 'unknown direction status')
  }
  if (!Array.isArray(data.authorities)) {
    add('DESIGN_E_AUTHORITIES', '/authorities', 'authorities must be an array')
  } else {
    data.authorities.forEach((authority, index) => {
      if (
        typeof authority?.kind !== 'string' ||
        authority.kind.trim() === '' ||
        !isSafeRelativePath(authority?.path)
      ) {
        add('DESIGN_E_AUTHORITY_ITEM', `/authorities/${index}`, 'authority requires kind and safe relative path')
      }
    })
  }
  if (!Array.isArray(data.decisions)) {
    add('DESIGN_E_DECISIONS', '/decisions', 'decisions must be an array')
    return errors
  }

  const seen = new Set()
  data.decisions.forEach((decision, index) => {
    const base = `/decisions/${index}`
    if (!KEBAB_CASE.test(decision?.id ?? '')) {
      add('DESIGN_E_ID', `${base}/id`, 'id must be unique kebab-case')
    } else if (seen.has(decision.id)) {
      add('DESIGN_E_ID_DUPLICATE', `${base}/id`, 'duplicate decision id')
    } else {
      seen.add(decision.id)
    }
    if (!DECISION_STATUSES.has(decision?.status)) {
      add('DESIGN_E_STATUS', `${base}/status`, 'unknown decision status')
    }
    if (!SOURCE_TYPES.has(decision?.source?.type)) {
      add('DESIGN_E_SOURCE', `${base}/source/type`, 'unknown source type')
    }
    if (typeof decision?.rule !== 'string' || decision.rule.trim() === '') {
      add('DESIGN_E_RULE', `${base}/rule`, 'rule must be a non-empty string')
    }
    const refs = decision?.source?.references
    const evidence = decision?.localEvidence
    const enforcement = decision?.enforcement
    const waivers = decision?.waivers
    if (!Array.isArray(refs)) add('DESIGN_E_REFERENCES', `${base}/source/references`, 'references must be an array')
    if (!Array.isArray(evidence)) add('DESIGN_E_LOCAL_EVIDENCE', `${base}/localEvidence`, 'localEvidence must be an array')
    if (!Array.isArray(enforcement)) add('DESIGN_E_ENFORCEMENT', `${base}/enforcement`, 'enforcement must be an array')
    if (!Array.isArray(waivers)) add('DESIGN_E_WAIVERS', `${base}/waivers`, 'waivers must be an array')

    if (decision?.source?.type === 'local-incident' && (!refs?.length || !evidence?.length)) {
      add('DESIGN_E_INCIDENT_EVIDENCE', base, 'local incidents require source references and local evidence')
    }
    if (decision?.source?.type === 'external-precedent' && ADOPTED_STATUSES.has(decision?.status) && !evidence?.length) {
      add('DESIGN_E_EXTERNAL_NEEDS_LOCAL_EVIDENCE', `${base}/localEvidence`, 'adopted external precedents require local evidence')
    }
    if ((decision?.status === 'component-enforced' || decision?.status === 'ci-enforced') && !enforcement?.length) {
      add('DESIGN_E_ENFORCEMENT_REQUIRED', `${base}/enforcement`, 'enforced status requires an enforcement record')
    }
    enforcement?.forEach((item, itemIndex) => {
      if (!ENFORCEMENT_TYPES.has(item?.type) || !isSafeRelativePath(item?.path)) {
        add('DESIGN_E_ENFORCEMENT_ITEM', `${base}/enforcement/${itemIndex}`, 'enforcement requires a known type and safe relative path')
      }
    })
    waivers?.forEach((item, itemIndex) => {
      if (!item?.reason || !item?.owner || !ISO_DATE.test(item?.expires ?? '')) {
        add('DESIGN_E_WAIVER', `${base}/waivers/${itemIndex}`, 'waiver requires reason, owner, and YYYY-MM-DD expires')
      }
    })
  })

  return errors.sort((left, right) => `${left.path}:${left.code}`.localeCompare(`${right.path}:${right.code}`))
}
