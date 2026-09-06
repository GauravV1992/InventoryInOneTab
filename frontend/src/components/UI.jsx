import { useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import { createPortal } from 'react-dom';

/** Fixed-position panel under an anchor — escapes overflow/z-index stacking in tables/cards */
function DropdownPortal({ anchorRef, open, children, onClose, className = '' }) {
  const panelRef = useRef(null);
  const [style, setStyle] = useState(null);

  useLayoutEffect(() => {
    if (!open || !anchorRef?.current) {
      setStyle(null);
      return undefined;
    }

    const update = () => {
      const r = anchorRef.current.getBoundingClientRect();
      const spaceBelow = window.innerHeight - r.bottom;
      const openUp = spaceBelow < 180 && r.top > spaceBelow;
      const panelWidth = Math.min(Math.max(r.width, 200), window.innerWidth - 16);
      setStyle({
        position: 'fixed',
        left: Math.max(8, Math.min(r.left, window.innerWidth - panelWidth - 8)),
        width: panelWidth,
        maxHeight: Math.min(320, window.innerHeight - 24),
        zIndex: 9999,
        ...(openUp
          ? { bottom: window.innerHeight - r.top + 4, top: 'auto' }
          : { top: r.bottom + 4, bottom: 'auto' }),
      });
    };

    update();
    window.addEventListener('scroll', update, true);
    window.addEventListener('resize', update);
    return () => {
      window.removeEventListener('scroll', update, true);
      window.removeEventListener('resize', update);
    };
  }, [open, anchorRef]);

  useEffect(() => {
    if (!open) return undefined;
    const handleClick = (e) => {
      const inAnchor = anchorRef?.current?.contains(e.target);
      const inPanel = panelRef.current?.contains(e.target);
      if (!inAnchor && !inPanel) onClose?.();
    };
    document.addEventListener('mousedown', handleClick);
    return () => document.removeEventListener('mousedown', handleClick);
  }, [open, anchorRef, onClose]);

  if (!open || !style || typeof document === 'undefined') return null;

  return createPortal(
    <div
      ref={panelRef}
      style={style}
      className={`rounded-xl border border-slate-200 bg-white shadow-xl overflow-auto ${className}`}
    >
      {children}
    </div>,
    document.body
  );
}

export function Autocomplete({
  label,
  value,
  onChange,
  onSelect,
  options = [],
  getOptionLabel = (o) => o.label ?? String(o),
  getOptionValue = (o) => o.value ?? o,
  filterOption,
  minChars = 3,
  placeholder = 'Type at least 3 characters...',
  required,
  className = '',
  inputClassName = '',
  onSearch,
}) {
  const [open, setOpen] = useState(false);
  const wrapperRef = useRef(null);
  const inputRef = useRef(null);

  const filtered = useMemo(() => {
    if (!value || value.length < minChars) return [];
    const q = value.toLowerCase();
    return options.filter((o) => {
      if (filterOption) return filterOption(o, q);
      return getOptionLabel(o).toLowerCase().includes(q);
    }).slice(0, 15);
  }, [value, options, minChars, filterOption, getOptionLabel]);

  useEffect(() => {
    if (!onSearch || !value || value.length < minChars) return undefined;
    const timer = setTimeout(() => onSearch(value), 300);
    return () => clearTimeout(timer);
  }, [value, minChars, onSearch]);

  const showList = open && value.length >= minChars && filtered.length > 0;
  const showEmpty = open && value.length >= minChars && filtered.length === 0;
  const menuOpen = showList || showEmpty;

  return (
    <div className={`relative ${menuOpen ? 'z-[60]' : ''} ${className}`} ref={wrapperRef}>
      {label && (
        <label className="block text-sm font-medium text-slate-600 mb-1.5">
          {label}{required ? ' *' : ''}
        </label>
      )}
      <input
        ref={inputRef}
        type="text"
        value={value}
        onChange={(e) => {
          onChange(e.target.value);
          setOpen(true);
        }}
        onFocus={() => setOpen(true)}
        placeholder={placeholder}
        required={required}
        autoComplete="off"
        className={`w-full px-4 py-2.5 rounded-xl border border-slate-200 bg-white text-base md:text-sm focus:outline-none focus:ring-2 focus:ring-brand-500/30 focus:border-brand-500 transition ${inputClassName}`}
      />
      <DropdownPortal
        anchorRef={inputRef}
        open={menuOpen}
        onClose={() => setOpen(false)}
      >
        {showList ? (
          <ul className="max-h-48 overflow-auto py-1">
            {filtered.map((opt, idx) => (
              <li key={getOptionValue(opt) ?? idx}>
                <button
                  type="button"
                  className="w-full text-left px-3 py-2 text-sm hover:bg-brand-50 hover:text-brand-700"
                  onMouseDown={(e) => e.preventDefault()}
                  onClick={() => {
                    onSelect(opt);
                    setOpen(false);
                  }}
                >
                  {getOptionLabel(opt)}
                </button>
              </li>
            ))}
          </ul>
        ) : (
          <div className="px-3 py-2 text-sm text-slate-400">No matches found</div>
        )}
      </DropdownPortal>
    </div>
  );
}

export function PageHeader({ title, subtitle, action }) {
  return (
    <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 sm:gap-4 mb-6">
      <div className="min-w-0">
        <h2 className="text-xl sm:text-2xl font-bold text-slate-800 leading-tight">{title}</h2>
        {subtitle && <p className="text-slate-500 text-sm mt-1">{subtitle}</p>}
      </div>
      {action && (
        <div className="w-full sm:w-auto shrink-0 [&>button]:w-full sm:[&>button]:w-auto">
          {action}
        </div>
      )}
    </div>
  );
}

export function Card({ children, className = '' }) {
  return (
    <div className={`bg-white rounded-2xl border border-slate-200 shadow-sm min-w-0 ${className}`}>
      {children}
    </div>
  );
}

export function Loader({ size = 'md', className = '' }) {
  const sizes = {
    sm: 'w-4 h-4 border',
    md: 'w-8 h-8 border-2',
    lg: 'w-10 h-10 border-2',
  };
  return (
    <div
      className={`${sizes[size]} border-brand-500 border-t-transparent rounded-full animate-spin ${className}`}
      role="status"
      aria-label="Loading"
    />
  );
}

export function PageLoading({ message = 'Loading...' }) {
  return (
    <div className="flex flex-col items-center justify-center min-h-[40vh] gap-3">
      <Loader />
      {message ? <p className="text-sm text-slate-500">{message}</p> : null}
    </div>
  );
}

export function Button({ children, variant = 'primary', className = '', loading = false, disabled, ...props }) {
  const variants = {
    primary: 'bg-brand-500 hover:bg-brand-600 text-white shadow-lg shadow-brand-500/25',
    secondary: 'bg-slate-100 hover:bg-slate-200 text-slate-700',
    danger: 'bg-red-500 hover:bg-red-600 text-white',
    outline: 'border border-slate-300 hover:bg-slate-50 text-slate-700',
  };
  const spinnerClass = variant === 'primary' || variant === 'danger'
    ? 'border-white border-t-transparent'
    : 'border-brand-500 border-t-transparent';

  return (
    <button
      className={`inline-flex items-center justify-center gap-2 px-4 py-2.5 min-h-11 rounded-xl text-sm font-medium transition-all touch-manipulation disabled:opacity-50 ${variants[variant]} ${className}`}
      disabled={disabled || loading}
      {...props}
    >
      {loading ? <Loader size="sm" className={spinnerClass} /> : null}
      {children}
    </button>
  );
}

export function Input({ label, className = '', ...props }) {
  return (
    <div className="min-w-0">
      {label && <label className="block text-sm font-medium text-slate-600 mb-1.5">{label}</label>}
      <input
        className={`w-full max-w-full px-4 py-2.5 rounded-xl border border-slate-200 bg-white text-base md:text-sm focus:outline-none focus:ring-2 focus:ring-brand-500/30 focus:border-brand-500 transition ${className}`}
        {...props}
      />
    </div>
  );
}

export function Select({ label, children, className = '', ...props }) {
  return (
    <div className="min-w-0">
      {label && <label className="block text-sm font-medium text-slate-600 mb-1.5">{label}</label>}
      <select
        className={`w-full max-w-full px-4 py-2.5 rounded-xl border border-slate-200 bg-white text-base md:text-sm focus:outline-none focus:ring-2 focus:ring-brand-500/30 focus:border-brand-500 transition ${className}`}
        {...props}
      >
        {children}
      </select>
    </div>
  );
}

/** Local searchable dropdown — filters options in-memory, never calls API */
export function SearchableSelect({
  label,
  value = '',
  onChange,
  options = [],
  getOptionId = (o) => o.id,
  getOptionLabel = (o) => o.label ?? String(o),
  getOptionSearchText,
  getOptionMeta,
  allowEmpty = false,
  emptyLabel = 'All',
  placeholder = 'Select...',
  searchPlaceholder = 'Search...',
  emptyMessage = 'No matches found',
  required = false,
  className = '',
  buttonClassName = '',
  disabled = false,
}) {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState('');
  const wrapperRef = useRef(null);
  const buttonRef = useRef(null);
  const searchRef = useRef(null);

  const selected = useMemo(
    () => options.find((o) => String(getOptionId(o)) === String(value)) || null,
    [options, value, getOptionId]
  );

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return options;
    return options.filter((o) => {
      const hay = (getOptionSearchText ? getOptionSearchText(o) : getOptionLabel(o))
        .toString()
        .toLowerCase();
      return hay.includes(q);
    });
  }, [options, query, getOptionLabel, getOptionSearchText]);

  useEffect(() => {
    if (open) {
      setQuery('');
      setTimeout(() => searchRef.current?.focus(), 0);
    }
  }, [open]);

  const pick = (opt) => {
    const id = opt != null ? String(getOptionId(opt)) : '';
    onChange?.(id, opt || null);
    setOpen(false);
    setQuery('');
  };

  const close = () => {
    setOpen(false);
    setQuery('');
  };

  const display = selected
    ? getOptionLabel(selected)
    : (allowEmpty && !value ? emptyLabel : '');

  return (
    <div className={`relative ${open ? 'z-[60]' : ''} ${className}`} ref={wrapperRef}>
      {label && (
        <label className="block text-sm font-medium text-slate-600 mb-1.5">
          {label}{required ? ' *' : ''}
        </label>
      )}
      <button
        ref={buttonRef}
        type="button"
        disabled={disabled}
        onClick={() => !disabled && setOpen((o) => !o)}
        className={`w-full px-4 py-2.5 rounded-xl border border-slate-200 bg-white text-base md:text-sm text-left flex items-center justify-between gap-2 focus:outline-none focus:ring-2 focus:ring-brand-500/30 focus:border-brand-500 transition disabled:bg-slate-50 disabled:text-slate-400 ${buttonClassName}`}
      >
        <span className={display ? 'text-slate-800 truncate' : 'text-slate-400 truncate'}>
          {display || placeholder}
        </span>
        <svg className={`w-4 h-4 text-slate-400 shrink-0 transition ${open ? 'rotate-180' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
        </svg>
      </button>

      <DropdownPortal anchorRef={buttonRef} open={open} onClose={close}>
        <div className="p-2 border-b border-slate-100">
          <input
            ref={searchRef}
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={searchPlaceholder}
            className="w-full px-3 py-2 rounded-lg border border-slate-200 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500/30 focus:border-brand-500"
          />
        </div>
        <ul className="max-h-52 overflow-auto py-1">
          {allowEmpty && (
            <li>
              <button
                type="button"
                className={`w-full text-left px-3 py-2 text-sm hover:bg-brand-50 hover:text-brand-700 ${!value ? 'bg-brand-50 text-brand-700 font-medium' : 'text-slate-700'}`}
                onMouseDown={(e) => e.preventDefault()}
                onClick={() => pick(null)}
              >
                {emptyLabel}
              </button>
            </li>
          )}
          {filtered.length === 0 ? (
            <li className="px-3 py-3 text-sm text-slate-400 text-center">{emptyMessage}</li>
          ) : (
            filtered.map((opt) => {
              const id = getOptionId(opt);
              const meta = getOptionMeta?.(opt);
              const active = String(id) === String(value);
              return (
                <li key={id}>
                  <button
                    type="button"
                    className={`w-full text-left px-3 py-2 text-sm hover:bg-brand-50 hover:text-brand-700 ${active ? 'bg-brand-50 text-brand-700 font-medium' : 'text-slate-700'}`}
                    onMouseDown={(e) => e.preventDefault()}
                    onClick={() => pick(opt)}
                  >
                    <span className="block truncate">{getOptionLabel(opt)}</span>
                    {meta ? (
                      <span className="block text-xs text-slate-400 truncate mt-0.5">{meta}</span>
                    ) : null}
                  </button>
                </li>
              );
            })
          )}
        </ul>
      </DropdownPortal>
    </div>
  );
}

/** Searchable warehouse dropdown — filters locally, never calls API */
export function WarehouseSelect({
  label = 'Warehouse',
  value = '',
  onChange,
  locations = [],
  allowEmpty = false,
  emptyLabel = 'All Warehouses',
  placeholder = 'Select warehouse',
  required = false,
  className = '',
  buttonClassName = '',
  disabled = false,
  getOptionMeta,
}) {
  return (
    <SearchableSelect
      label={label}
      value={value}
      onChange={onChange}
      options={locations}
      getOptionId={(l) => l.LocationId}
      getOptionLabel={(l) => l.LocationName}
      getOptionSearchText={(l) => [l.LocationName, l.Address, l.City].filter(Boolean).join(' ')}
      getOptionMeta={(l) => {
        const custom = getOptionMeta?.(l);
        const base = [l.City, l.Address].filter(Boolean).join(' · ');
        return [base, custom].filter(Boolean).join(' · ') || null;
      }}
      allowEmpty={allowEmpty}
      emptyLabel={emptyLabel}
      placeholder={placeholder}
      searchPlaceholder="Search warehouse..."
      emptyMessage="No warehouse found"
      required={required}
      className={className}
      buttonClassName={buttonClassName}
      disabled={disabled}
    />
  );
}

/** Searchable material dropdown — filters locally, never calls API */
export function MaterialSelect({
  label = 'Material',
  value = '',
  onChange,
  materials = [],
  allowEmpty = false,
  emptyLabel = 'All Materials',
  placeholder = 'Select material',
  required = false,
  className = '',
  buttonClassName = '',
  disabled = false,
}) {
  return (
    <SearchableSelect
      label={label}
      value={value}
      onChange={onChange}
      options={materials}
      getOptionId={(m) => m.MaterialId}
      getOptionLabel={(m) => m.MaterialName}
      getOptionSearchText={(m) => [m.MaterialName, m.Color, m.HSNCode].filter(Boolean).join(' ')}
      getOptionMeta={(m) => [m.Color, m.HSNCode, m.Unit].filter(Boolean).join(' · ') || null}
      allowEmpty={allowEmpty}
      emptyLabel={emptyLabel}
      placeholder={placeholder}
      searchPlaceholder="Search material, color, HSN..."
      emptyMessage="No material found"
      required={required}
      className={className}
      buttonClassName={buttonClassName}
      disabled={disabled}
    />
  );
}

export function Textarea({ label, className = '', ...props }) {
  return (
    <div className="min-w-0">
      {label && <label className="block text-sm font-medium text-slate-600 mb-1.5">{label}</label>}
      <textarea
        className={`w-full max-w-full px-4 py-2.5 rounded-xl border border-slate-200 bg-white text-base md:text-sm focus:outline-none focus:ring-2 focus:ring-brand-500/30 focus:border-brand-500 transition resize-none ${className}`}
        rows={3}
        {...props}
      />
    </div>
  );
}

export function Badge({ status }) {
  const colors = {
    'In Stock': 'bg-emerald-100 text-emerald-700',
    'Low Stock': 'bg-amber-100 text-amber-700',
    'Out of Stock': 'bg-red-100 text-red-700',
  };
  return (
    <span className={`inline-flex px-2.5 py-1 rounded-full text-xs font-medium ${colors[status] || 'bg-slate-100 text-slate-600'}`}>
      {status}
    </span>
  );
}

export function Alert({ type = 'error', message }) {
  if (!message) return null;
  const styles = {
    error: 'bg-red-50 text-red-700 border-red-200',
    success: 'bg-emerald-50 text-emerald-700 border-emerald-200',
  };
  return (
    <div className={`px-4 py-3 rounded-xl border text-sm mb-4 ${styles[type]}`}>
      {message}
    </div>
  );
}

function isActionColumn(col) {
  return col.mobileRole === 'actions' || col.key === 'actions' || col.key === 'invoice';
}

function isFullWidthColumn(col) {
  return Boolean(col.mobileFull)
    || ['items', 'Remark', 'Address', 'Address1', 'Address2', 'Description'].includes(col.key);
}

function cellValue(col, row) {
  if (!col) return '—';
  const value = col.render ? col.render(row) : row[col.key];
  if (value == null || value === '') return '—';
  return value;
}

export function Table({ columns, data, keyField, titleKey }) {
  const actionCols = columns.filter(isActionColumn);
  const dataCols = columns.filter((col) => !isActionColumn(col));
  const titleCol = (titleKey && columns.find((col) => col.key === titleKey)) || dataCols[0];

  return (
    <>
      <div className="md:hidden">
        {data.length === 0 ? (
          <p className="px-4 py-12 text-center text-sm text-slate-400">No records found</p>
        ) : (
          <ul className="divide-y divide-slate-100">
            {data.map((row, i) => (
              <li key={row[keyField] ?? i} className="p-4 space-y-3">
                {titleCol && (
                  <div className="font-semibold text-[15px] text-slate-800 leading-snug break-words">
                    {cellValue(titleCol, row)}
                  </div>
                )}
                <dl className="grid grid-cols-2 gap-x-3 gap-y-2.5">
                  {dataCols.filter((col) => col !== titleCol).map((col) => (
                    <div key={col.key} className={isFullWidthColumn(col) ? 'col-span-2' : 'min-w-0'}>
                      <dt className="text-[11px] font-medium uppercase tracking-wide text-slate-400">{col.label}</dt>
                      <dd className="mt-0.5 text-sm text-slate-800 break-words whitespace-normal [overflow-wrap:anywhere]">
                        {cellValue(col, row)}
                      </dd>
                    </div>
                  ))}
                </dl>
                {actionCols.length > 0 && (
                  <div className="pt-2 border-t border-slate-100 flex flex-wrap gap-2">
                    {actionCols.map((col) => (
                      <div key={col.key} className="flex flex-wrap gap-1.5">
                        {col.render?.(row)}
                      </div>
                    ))}
                  </div>
                )}
              </li>
            ))}
          </ul>
        )}
      </div>

      <div className="hidden md:block overflow-x-auto">
        <table className="w-full text-sm min-w-[640px]">
          <thead>
            <tr className="border-b border-slate-200">
              {columns.map((col) => (
                <th key={col.key} className="text-left px-4 py-3 font-semibold text-slate-600 whitespace-nowrap">
                  {col.label}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {data.length === 0 ? (
              <tr>
                <td colSpan={columns.length} className="text-center py-12 text-slate-400">
                  No records found
                </td>
              </tr>
            ) : (
              data.map((row, i) => (
                <tr key={row[keyField] || i} className="border-b border-slate-100 hover:bg-slate-50 transition">
                  {columns.map((col) => (
                    <td key={col.key} className="px-4 py-3 whitespace-nowrap">
                      {col.render ? col.render(row) : row[col.key]}
                    </td>
                  ))}
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </>
  );
}

export function SearchBox({ value, onChange, placeholder = 'Search...', className = '' }) {
  return (
    <div className={`relative ${className}`}>
      <svg className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-4.35-4.35M17 11A6 6 0 1 1 5 11a6 6 0 0 1 12 0z" />
      </svg>
      <input
        type="text"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        className="w-full pl-10 pr-4 py-2.5 rounded-xl border border-slate-200 bg-white text-base md:text-sm focus:outline-none focus:ring-2 focus:ring-brand-500/30 focus:border-brand-500"
      />
    </div>
  );
}

export function Pagination({ page, totalPages, total, onPageChange, pageSize = 10 }) {
  if (total === 0) return null;
  const from = (page - 1) * pageSize + 1;
  const to = Math.min(page * pageSize, total);

  return (
    <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3 px-4 py-3 border-t border-slate-100 bg-slate-50/50 rounded-b-2xl">
      <p className="text-sm text-slate-500 text-center sm:text-left">
        Showing <span className="font-medium text-slate-700">{from}–{to}</span> of <span className="font-medium text-slate-700">{total}</span>
      </p>
      <div className="flex items-center justify-center gap-2">
        <button
          type="button"
          disabled={page <= 1}
          onClick={() => onPageChange(page - 1)}
          className="flex-1 sm:flex-none px-3 py-2 min-h-11 rounded-lg border border-slate-200 text-sm disabled:opacity-40 hover:bg-white transition touch-manipulation"
        >
          Previous
        </button>
        <span className="text-sm text-slate-600 px-2 whitespace-nowrap">
          Page {page} / {totalPages}
        </span>
        <button
          type="button"
          disabled={page >= totalPages}
          onClick={() => onPageChange(page + 1)}
          className="flex-1 sm:flex-none px-3 py-2 min-h-11 rounded-lg border border-slate-200 text-sm disabled:opacity-40 hover:bg-white transition touch-manipulation"
        >
          Next
        </button>
      </div>
    </div>
  );
}

export function ListToolbar({ search, onSearchChange, searchPlaceholder, children }) {
  return (
    <div className="p-4 border-b border-slate-100 flex flex-col lg:flex-row gap-3 lg:items-end">
      <div className="flex-1 min-w-0 w-full">
        <SearchBox value={search} onChange={onSearchChange} placeholder={searchPlaceholder} />
      </div>
      {children}
    </div>
  );
}
