" macOS-only mappings and helpers.
nmap <c-w> <CMD>tabclose<CR>

nnoremap mf <CMD>execute '!open ' . shellescape(expand('%:p:h'))<CR>
nnoremap <leader>mF <CMD>execute '!open ' . shellescape(getcwd())<CR>

" Preserve the Mac branch's repo shortcut after the common Git mappings load.
nmap <leader>gc <CMD>cd ~/compare-my-stocks<CR>

" On Mac, this picker changes the tab-local directory, then picks a file in it.
" The file picker must be deferred: fzf.vim's window is still tearing down when
" the sink runs, so a synchronous FzfLua files never opens.
function! TcdChooseFile(item) abort
    call TcdDirPlug(a:item)
    call timer_start(10, {-> execute('FzfLua files')})
endfunction

function! FzfDirChooseFile() abort
    call fzf#run({
        \ 'source': uniq(sort(map(copy(g:dirs), 'tolower(v:val)'))),
        \ 'sink': function('TcdChooseFile'),
        \ 'options': '-i --preview "ls {} | head -50"'
    \ })
endfunction

function! TermOV(use_file_dir) abort
    call CloseVspIfNeed()
    let l:cwd = a:use_file_dir ? expand('%:p:h') : expand('~')
    call luaeval('Snacks.terminal.open(nil, { cwd = _A, win = { position = "right", width = 0.4 } })', l:cwd)
endfunction

function! TermO() abort
    call luaeval('Snacks.terminal.open()')
endfunction

nnoremap <leader>ot <CMD>tabnew <bar> call TermO()<CR>:startinsert<CR>
nmap <leader>tt <CMD>call TermOV(0)<CR><CMD>call GoRight(0)<CR>:startinsert<CR>
nmap <leader>Tt <CMD>call TermOV(1)<CR><CMD>call GoRight(0)<CR>:startinsert<CR>

function! StashAll() abort
    let l:stash = input('Enter name: ')
    execute '!git stash push -m ' . shellescape(l:stash)
endfunction
nmap <leader>Gs <CMD>call StashAll()<CR>

function! s:MmdReport(name, code, err) abort
    if a:code == 0
        let l:msg = 'mmd compile OK: ' . a:name
        if has('nvim')
            call v:lua.vim.notify(l:msg, luaeval('vim.log.levels.INFO'))
        else
            echohl MoreMsg | echom l:msg | echohl None
        endif
    else
        let l:msg = 'mmd compile FAIL(' . a:code . '): ' . a:name . (empty(a:err) ? '' : ' — ' . a:err)
        if has('nvim')
            call v:lua.vim.notify(l:msg, luaeval('vim.log.levels.ERROR'))
        else
            echohl ErrorMsg | echom l:msg | echohl None
        endif
    endif
endfunction

function! CompileMmd() abort
    let l:src = expand('%:p')
    let l:name = expand('%:t')
    let l:dst = expand('%:p:r') . '.pdf'
    let l:script = expand('~/research/compile_mmd.sh')
    let l:node = expand('~/.nvm/versions/node/v24.15.0/bin')
    let l:cmd = ['sh', '-c', printf('PATH=%s:$PATH %s %s %s',
        \ shellescape(l:node), shellescape(l:script), shellescape(l:src), shellescape(l:dst))]
    echo 'mmd compiling: ' . l:name . '...'
    let l:stderr_lines = []
    if has('nvim')
        call jobstart(l:cmd, {
            \ 'on_stderr': {_, data, __ -> extend(l:stderr_lines, filter(copy(data), '!empty(v:val)'))},
            \ 'on_exit': {_, code, __ -> s:MmdReport(l:name, code, join(l:stderr_lines, ' | '))},
            \ })
    else
        call job_start(l:cmd, {
            \ 'err_cb': {_, msg -> add(l:stderr_lines, msg)},
            \ 'exit_cb': {_, code -> s:MmdReport(l:name, code, join(l:stderr_lines, ' | '))},
            \ })
    endif
endfunction

function! ToggleMmdAutoCompile() abort
    let b:mmd_autocompile = !get(b:, 'mmd_autocompile', 1)
    echo 'mmd autocompile (' . expand('%:t') . '): ' . (b:mmd_autocompile ? 'ON' : 'OFF')
endfunction

augroup MmdAutoCompile
    autocmd!
    autocmd BufWritePost *.mmd if get(b:, 'mmd_autocompile', 1) | call CompileMmd() | endif
augroup END

augroup MmdMappings
    autocmd!
    autocmd BufRead,BufNewFile *.mmd nnoremap <buffer> <leader>mc :call CompileMmd()<CR>
    autocmd BufRead,BufNewFile *.mmd nnoremap <buffer> <leader>ma :call ToggleMmdAutoCompile()<CR>
augroup END

" ---------------------------------------------------------------------------
" macOS: let Cmd (<D-...>) trigger every existing Meta (<M-...>) mapping.
" nvim-qt does not reliably deliver Option/Meta, but Cmd arrives fine. These
" are recursive aliases, so each forwards to whatever <M-...> resolves to at
" press time — plain, <expr>, <script> and buffer-local targets all work.
" ---------------------------------------------------------------------------
if has('mac') && exists('*maplist')
    let s:mode_cmd = {'n':'nmap', 'i':'imap', 'v':'vmap', 'x':'xmap',
        \ 's':'smap', 'o':'omap', 'c':'cmap', 't':'tmap', '!':'map!', ' ':'map'}
    for s:m in maplist()
        if s:m.lhs =~? '<M-' && has_key(s:mode_cmd, s:m.mode)
            execute s:mode_cmd[s:m.mode]
                \ substitute(s:m.lhs, '<[Mm]-', '<D-', 'g') s:m.lhs
        endif
    endfor
    unlet! s:m s:mode_cmd
    " FileType-defined maps are not in maplist() yet at startup; add explicitly.
    imap <D-]> <M-]>
    imap <D-[> <M-[>
endif
