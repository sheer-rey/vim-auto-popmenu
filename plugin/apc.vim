" vim: set noet fenc=utf-8 ff=unix sts=4 sw=4 ts=4 :
"
" apc.vim - auto popup completion window
"
" Created by skywind on 2020/03/05
" Last Modified: 2022/12/05 21:22
"
" Features:
"
" - auto popup complete window without select the first one
" - tab/s-tab to cycle suggestions, <c-e> to cancel
" - use ApcEnable/ApcDisable to toggle for certiain file.
"
" Usage:
"
" set cpt=.,k,b
" set completeopt=menu,menuone,noselect
" let g:apc_enable_ft = {'text':1, 'markdown':1, 'php':1}

" global variables, only aquire here once while plugin has been loaded
let g:apc_enable          = get(g:, 'apc_enable', 1)             " enable apc globally
let g:apc_enable_ft       = get(g:, 'apc_enable_ft', {})         " enable filetypes
let g:apc_enable_tab      = get(g:, 'apc_enable_tab', 1)         " enable remap tab
let g:apc_enable_auto_pop = get(g:, 'apc_enable_auto_pop', 1)    " enable auto popup complete window
let g:apc_min_length      = get(g:, 'apc_min_length', 2)         " minimal length to open popup
let g:apc_key_ignore      = get(g:, 'apc_key_ignore', [])        " ignore keywords
let g:apc_trigger         = get(g:, 'apc_trigger', "\<C-n>")     " which key to trigger popmenu

" get text line before cursor
function! s:get_context()
    return strpart(getline('.'), 0, col('.') - 1)
endfunc

" checkout if a:context meets the condition to trigger popmenu for completion
function! s:meets_keyword(context)
    if g:apc_min_length <= 0 | return 0 | endif
    let matches = matchlist(a:context, '\(\k\{' . g:apc_min_length . ',}\)$')
    if empty(matches) | return 0 | endif
    for ignore in g:apc_key_ignore
        if stridx(ignore, matches[1]) == 0 | return 0 | endif
    endfor
    return 1
endfunc

" checkout if a:context meets the condition to trigger popmenu for file path completion
function! s:meets_path(context)
    if g:apc_min_length <= 0 | return 0 | endif
    let matches = matchlist(a:context, '\(\~\|\.\|\.\.\)\?\/\f\{' . g:apc_min_length . ',}$')
    if empty(matches) | return 0 | endif
    return 1
endfunc

" checkout if the character before cursor is whitespace
function! s:check_back_space() abort
      return col('.') < 2 || getline('.')[col('.') - 2]  =~# '\s'
endfunc

" set the behavior of press <BS>, by checking out wether popmenu is visible
function! s:on_backspace()
    if pumvisible() == 0 | return "\<BS>" | endif
    let text = matchstr(s:get_context(), '.*\ze.')
    return s:meets_path(text) || s:meets_keyword(text) ? "\<BS>" : "\<C-e>\<BS>"
endfunc

" autocmd for CursorMovedI
function! s:feed_popup()
    let enable = get(g:, 'apc_enable', 0) && get(b:, 'apc_enable', 0)
    let lastx  = get(b:, 'apc_lastx', -1)
    let lasty  = get(b:, 'apc_lasty', -1)
    let tick   = get(b:, 'apc_tick', -1)
    if &bt != '' || enable == 0 || &paste | return -1 | endif
    let x = col('.') - 1
    let y = line('.') - 1
    if pumvisible()
        let context = s:get_context()
        if s:meets_keyword(context) == 0 | call feedkeys("\<C-e>", 'n') | endif
        let b:apc_lastx = x
        let b:apc_lasty = y
        let b:apc_tick  = b:changedtick
        return 0
    elseif lastx == x && lasty == y
        return -2
    elseif b:changedtick == tick
        let lastx = x
        let lasty = y
        return -3
    endif
    let context = s:get_context()
    if s:meets_path(context)
        silent! call feedkeys("\<C-x>\<C-f>", 'n')
        let b:apc_lastx = x
        let b:apc_lasty = y
        let b:apc_tick  = b:changedtick
    elseif s:meets_keyword(context)
        silent! call feedkeys(get(b:, 'apc_trigger', g:apc_trigger), 'n')
        let b:apc_lastx = x
        let b:apc_lasty = y
        let b:apc_tick  = b:changedtick
    endif
    return 0
endfunc

" autocmd for CompleteDone
function! s:complete_done()
    let b:apc_lastx = col('.') - 1
    let b:apc_lasty = line('.') - 1
    let b:apc_tick  = b:changedtick
endfunc

" enable apc
function! s:apc_enable()
    call s:apc_disable()
    if g:apc_enable == 0 | return | endif
    if g:apc_enable_auto_pop
        augroup ApcEventGroup
            autocmd!
            autocmd CursorMovedI <buffer> nested call s:feed_popup()
            autocmd CompleteDone <buffer> call s:complete_done()
        augroup END
        let b:apc_init_autocmd = 1
    endif
    if g:apc_enable_tab
        inoremap <silent><buffer><expr> <Tab>
        \   pumvisible() ? "\<C-n>" :
        \       <SID>check_back_space() ? "\<Tab>" :
        \           get(b:, 'apc_trigger', g:apc_trigger)
        inoremap <silent><buffer><expr> <S-Tab>
        \   pumvisible() ? "\<C-p>" : "\<S-Tab>"
        let b:apc_init_tab = 1
    endif
    if get(g:, 'apc_cr_confirm', 0) == 0
        inoremap <silent><buffer><expr> <CR>
        \   pumvisible() ? "\<C-y>\<CR>" : "\<CR>"
    else
        inoremap <silent><buffer><expr> <CR>
        \   pumvisible()? "\<C-y>" : "\<CR>"
    endif
    inoremap <silent><buffer><expr> <BS> <SID>on_backspace()
    let b:apc_enable     = 1
    let b:apc_init_bs    = 1
    let b:apc_init_cr    = 1
    let b:apc_save_infer = &infercase
    setlocal infercase
endfunc

" disable apc
function! s:apc_disable()
    if get(b:, 'apc_init_autocmd', 0)
        augroup ApcEventGroup
            autocmd!
        augroup END
    endif
    if get(b:, 'apc_init_tab', 0)
        silent! iunmap <buffer><expr> <Tab>
        silent! iunmap <buffer><expr> <S-Tab>
    endif
    if get(b:, 'apc_init_bs', 0)
        silent! iunmap <buffer><expr> <BS>
    endif
    if get(b:, 'apc_init_cr', 0)
        silent! iunmap <buffer><expr> <CR>
    endif
    if get(b:, 'apc_save_infer', '') != ''
        let &l:infercase = b:apc_save_infer
    endif
    let b:apc_enable       = 0
    let b:apc_init_autocmd = 0
    let b:apc_init_tab     = 0
    let b:apc_init_bs      = 0
    let b:apc_init_cr      = 0
    let b:apc_save_infer   = ''
endfunc

" check if need to be enabled
function! s:apc_check_init()
    if &bt != '' || g:apc_enable == 0 || get(b:, 'apc_enable', 1) == 0
        return
    endif
    if get(g:apc_enable_ft, &ft, 0) != 0
        ApcEnable
    elseif get(g:apc_enable_ft, '*', 0) != 0
        ApcEnable
    elseif get(b:, 'apc_enable', 0)
        ApcEnable
    endif
endfunc

" commands & autocmd
command! -nargs=0 ApcEnable call s:apc_enable()
command! -nargs=0 ApcDisable call s:apc_disable()

augroup ApcInitGroup
    autocmd!
    autocmd FileType * call s:apc_check_init()
    autocmd BufEnter * call s:apc_check_init()
    autocmd TabEnter * call s:apc_check_init()
augroup END

