from pathlib import Path

path = Path(r'c:\Users\Admin\source\repos\Python\PawanPutra\frontend\src\pages\Login.jsx')
text = path.read_text(encoding='utf-8')

replacements = [
(
'''            <div className="lg:hidden mb-8 text-center">
              <div className="w-14 h-14 rounded-2xl bg-brand-500 text-white flex items-center justify-center text-lg font-bold mx-auto mb-3">I1</div>''',
'''            <div className="lg:hidden mb-8 text-center">
              <div className="w-14 h-14 rounded-2xl bg-brand-700 text-white flex items-center justify-center text-lg font-bold mx-auto mb-3" aria-hidden="true">I1</div>'''
),
(
'''                <label className="block text-sm font-medium text-slate-600 mb-1.5">Username</label>
                <input
                  type="text"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  autoComplete="username"
                  className="w-full px-4 py-3 rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-brand-500/30 focus:border-brand-500"
                  required
                />''',
'''                <label htmlFor="login-username" className="block text-sm font-medium text-slate-700 mb-1.5">Username</label>
                <input
                  id="login-username"
                  name="username"
                  type="text"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  autoComplete="username"
                  className="w-full px-4 py-3 rounded-xl border border-slate-300 focus:outline-none focus:ring-2 focus:ring-brand-600/30 focus:border-brand-600"
                  required
                />'''
),
(
'''                <label className="block text-sm font-medium text-slate-600 mb-1.5">Password</label>
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  autoComplete={remember ? 'current-password' : 'off'}
                  className="w-full px-4 py-3 rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-brand-500/30 focus:border-brand-500"
                  required
                />''',
'''                <label htmlFor="login-password" className="block text-sm font-medium text-slate-700 mb-1.5">Password</label>
                <input
                  id="login-password"
                  name="password"
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  autoComplete={remember ? 'current-password' : 'off'}
                  className="w-full px-4 py-3 rounded-xl border border-slate-300 focus:outline-none focus:ring-2 focus:ring-brand-600/30 focus:border-brand-600"
                  required
                />'''
),
(
'''              <label className="flex items-center gap-2 text-sm text-slate-600 cursor-pointer select-none">
                <input
                  type="checkbox"
                  checked={remember}
                  onChange={(e) => setRemember(e.target.checked)}
                  className="rounded border-slate-300 text-brand-500 focus:ring-brand-500"
                />''',
'''              <label htmlFor="login-remember" className="flex items-center gap-2 text-sm text-slate-700 cursor-pointer select-none">
                <input
                  id="login-remember"
                  name="remember"
                  type="checkbox"
                  checked={remember}
                  onChange={(e) => setRemember(e.target.checked)}
                  className="rounded border-slate-400 text-brand-700 focus:ring-brand-600"
                />'''
),
(
'''                className="w-full flex items-center justify-center gap-2 py-3 rounded-xl bg-brand-500 hover:bg-brand-600 text-white font-medium shadow-lg shadow-brand-500/25 transition disabled:opacity-50"''',
'''                className="w-full flex items-center justify-center gap-2 py-3 rounded-xl bg-brand-700 hover:bg-brand-800 text-white font-medium shadow-lg shadow-brand-700/25 transition disabled:opacity-50"'''
),
]

for old, new in replacements:
    if old not in text:
        raise SystemExit(f'Patch block not found:\n{old[:120]}...')
    text = text.replace(old, new)

text = text.replace(
    'bg-brand-500 flex items-center justify-center text-lg font-bold text-white mb-5',
    'bg-brand-700 flex items-center justify-center text-lg font-bold text-white mb-5',
)
text = text.replace(
    'bg-brand-500 flex items-center justify-center shrink-0 mt-0.5',
    'bg-brand-700 flex items-center justify-center shrink-0 mt-0.5',
)
text = text.replace(
    'className="text-brand-600 hover:text-brand-700 font-medium"',
    'className="text-brand-800 hover:text-brand-900 font-medium underline underline-offset-2"',
)

if 'htmlFor="login-username"' not in text:
    raise SystemExit('username label missing after patch')

path.write_text(text, encoding='utf-8')
print('Login.jsx patched OK')
