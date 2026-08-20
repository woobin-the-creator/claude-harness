import React, { type ComponentType } from 'react'
import { createRoot } from 'react-dom/client'

const modules = import.meta.glob<{ default: ComponentType }>('./variants/*.tsx', { eager: true })
const variants = Object.entries(modules)
  .map(([path, module]) => ({
    label: path.split('/').pop()!.replace(/\.tsx$/, ''),
    Component: module.default,
  }))
  .sort((left, right) => left.label.localeCompare(right.label))

const requested = new URLSearchParams(location.search).get('variant')?.toLowerCase()
const selected = variants.find(({ label }) => label.toLowerCase() === requested) ?? variants[0]

if (!selected) {
  throw new Error('No preview variants found in .preview/variants')
}

function Preview() {
  return (
    <>
      <nav aria-label="Design variants">
        {variants.map(({ label }) => (
          <a key={label} href={`?variant=${encodeURIComponent(label)}`}>
            {label}
          </a>
        ))}
      </nav>
      <selected.Component />
    </>
  )
}

createRoot(document.getElementById('root')!).render(<Preview />)
